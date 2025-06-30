param (
    [string]$MuleProjectPath,
    [string]$OutputPath = "spring-output",
    [string]$PackageName = "com.example.api",
    [string]$JavaVersion = "11"
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Smart Mule to Spring Boot Migration Tool" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Mule Project: $MuleProjectPath" -ForegroundColor Yellow
Write-Host "Output: $OutputPath" -ForegroundColor Yellow
Write-Host "Package: $PackageName" -ForegroundColor Yellow

# Create output directory
if (Test-Path $OutputPath) {
    Remove-Item -Path $OutputPath -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

# Create Spring Boot structure
$paths = @(
    "$OutputPath\src\main\java\$($PackageName -replace '\.','\\')",
    "$OutputPath\src\main\resources",
    "$OutputPath\src\test\java\$($PackageName -replace '\.','\\')"
)

foreach ($path in $paths) {
    New-Item -ItemType Directory -Force -Path $path | Out-Null
}

Write-Host "`nCreating Spring Boot project structure..." -ForegroundColor Green

# First, parse RAML to understand the API contract
Write-Host "`nSearching for RAML files..." -ForegroundColor Yellow
$ramlFiles = Get-ChildItem -Path $MuleProjectPath -Filter "*.raml" -Recurse
Write-Host "Found $($ramlFiles.Count) RAML file(s)" -ForegroundColor Green

# Process RAML files
$apiDefinitions = @{}
foreach ($ramlFile in $ramlFiles) {
    Write-Host "  - $($ramlFile.Name)" -ForegroundColor White
    & ".\extract-raml-api-generic-fixed.ps1" `
        -ramlPath $ramlFile.FullName `
        -outputPath "$OutputPath\src\main\java\$($PackageName -replace '\.','\\')" `
        -packageName $PackageName
    
    # Parse RAML to extract expected operations
    $ramlContent = Get-Content $ramlFile.FullName -Raw
    
    # Extract resource paths and methods
    $resourceMatches = [regex]::Matches($ramlContent, '(?m)^(/\w+(?:/\{\w+\})?(?:/\w+)*):')
    foreach ($match in $resourceMatches) {
        $resourcePath = $match.Groups[1].Value
        $entityName = ""
        
        # Extract entity name from path
        if ($resourcePath -match '/(\w+)s?(?:/|$)') {
            $entityName = $matches[1].Substring(0,1).ToUpper() + $matches[1].Substring(1)
            if ($entityName.EndsWith('s')) {
                $entityName = $entityName.TrimEnd('s')
            }
        }
        
        if ($entityName -and -not $apiDefinitions.ContainsKey($entityName)) {
            $apiDefinitions[$entityName] = @{
                Operations = @()
            }
        }
        
        # Find methods for this resource
        $resourceSection = $ramlContent.Substring($ramlContent.IndexOf($resourcePath))
        $nextResourceIndex = $resourceSection.IndexOf("`n/")
        if ($nextResourceIndex -gt 0) {
            $resourceSection = $resourceSection.Substring(0, $nextResourceIndex)
        }
        
        # Extract HTTP methods
        $methodMatches = [regex]::Matches($resourceSection, '(?m)^\s+(get|post|put|delete):')
        foreach ($methodMatch in $methodMatches) {
            $httpMethod = $methodMatch.Groups[1].Value.ToUpper()
            $operation = @{
                Path = $resourcePath
                Method = $httpMethod
            }
            
            # Determine operation type
            if ($httpMethod -eq "GET" -and $resourcePath -notmatch '\{') {
                $operation.Type = "getAll"
            } elseif ($httpMethod -eq "GET" -and $resourcePath -match '\{(\w+)\}') {
                $operation.Type = "getById"
            } elseif ($httpMethod -eq "POST") {
                $operation.Type = "create"
            } elseif ($httpMethod -eq "PUT") {
                $operation.Type = "update"
            } elseif ($httpMethod -eq "DELETE") {
                $operation.Type = "delete"
            }
            
            if ($entityName) {
                $apiDefinitions[$entityName].Operations += $operation
            }
        }
    }
}

# Now process Mule XML files
Write-Host "`nSearching for Mule XML files..." -ForegroundColor Yellow
$muleXmlFiles = Get-ChildItem -Path $MuleProjectPath -Filter "*.xml" -Recurse | 
    Where-Object { $_.FullName -notmatch 'target' -and $_.FullName -notmatch 'pom.xml' }

Write-Host "Found $($muleXmlFiles.Count) Mule XML file(s)" -ForegroundColor Green

# Process Mule flows and map to API operations
$muleImplementations = @{}
foreach ($xmlFile in $muleXmlFiles) {
    Write-Host "  - $($xmlFile.Name)" -ForegroundColor White
    
    [xml]$muleDoc = Get-Content $xmlFile.FullName
    $namespaceManager = New-Object System.Xml.XmlNamespaceManager($muleDoc.NameTable)
    $namespaceManager.AddNamespace("mule", "http://www.mulesoft.org/schema/mule/core")
    $namespaceManager.AddNamespace("db", "http://www.mulesoft.org/schema/mule/db")
    
    $flows = $muleDoc.SelectNodes("//mule:flow", $namespaceManager)
    
    foreach ($flow in $flows) {
        $flowName = $flow.GetAttribute("name")
        
        # Extract entity name
        $entityName = ""
        if ($flowName -match '([a-zA-Z]+)s?-flow$' -or $flowName -match '-([a-zA-Z]+)s?-') {
            $parts = $flowName -split '-'
            foreach ($part in $parts) {
                if ($part -ne 'get' -and $part -ne 'create' -and $part -ne 'update' -and 
                    $part -ne 'delete' -and $part -ne 'all' -and $part -ne 'by' -and 
                    $part -ne 'flow' -and $part.Length -gt 2) {
                    $entityName = $part.Substring(0,1).ToUpper() + $part.Substring(1).ToLower()
                    if ($entityName.EndsWith('s')) {
                        $entityName = $entityName.TrimEnd('s')
                    } elseif ($entityName -eq "Addresse") {
                        $entityName = "Address"
                    }
                    break
                }
            }
        }
        
        if ($entityName) {
            if (-not $muleImplementations.ContainsKey($entityName)) {
                $muleImplementations[$entityName] = @{
                    Flows = @()
                    TableName = ""
                }
            }
            
            # Extract database operation
            $dbOp = $flow.SelectSingleNode(".//db:*", $namespaceManager)
            if ($dbOp) {
                $sqlNode = $dbOp.SelectSingleNode(".//db:sql", $namespaceManager)
                if ($sqlNode) {
                    $sqlText = $sqlNode.InnerText.Trim() -replace '\s+', ' '
                    
                    # Extract table name
                    if ($sqlText -match 'FROM\s+(\w+)' -or $sqlText -match 'INTO\s+(\w+)') {
                        $tableName = $matches[1]
                        if ($muleImplementations[$entityName].TableName -eq "") {
                            $muleImplementations[$entityName].TableName = $tableName
                        }
                    }
                    
                    $flowInfo = @{
                        FlowName = $flowName
                        OperationType = $dbOp.LocalName
                        SQL = $sqlText
                    }
                    
                    $muleImplementations[$entityName].Flows += $flowInfo
                }
            }
        }
    }
}

# Generate services with smart mapping
$servicePath = "$OutputPath\src\main\java\$($PackageName -replace '\.','\\')\service"
New-Item -ItemType Directory -Force -Path $servicePath | Out-Null

foreach ($entityName in $apiDefinitions.Keys) {
    $apiDef = $apiDefinitions[$entityName]
    $muleImpl = if ($muleImplementations.ContainsKey($entityName)) { $muleImplementations[$entityName] } else { $null }
    $tableName = if ($muleImpl -and $muleImpl.TableName) { $muleImpl.TableName } else { $entityName.ToLower() + "s" }
    
    Write-Host "`nGenerating ${entityName}Service..." -ForegroundColor Green
    
    $serviceClass = @"
package $packageName.service;

import $packageName.model.$entityName;
import $packageName.exception.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Service;

import java.sql.PreparedStatement;
import java.sql.Statement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

/**
 * ${entityName}Service - Service for $entityName management
 */
@Service
public class ${entityName}Service {
    
    @Autowired
    private JdbcTemplate jdbcTemplate;
    
    // Row mapper for $entityName
    private final RowMapper<$entityName> ${entityName.ToLower()}RowMapper = (rs, rowNum) -> {
        $entityName entity = new $entityName();
        
        // Use reflection to map fields dynamically
        java.lang.reflect.Field[] fields = entity.getClass().getDeclaredFields();
        for (java.lang.reflect.Field field : fields) {
            field.setAccessible(true);
            String fieldName = field.getName();
            String columnName = camelToSnake(fieldName);
            
            try {
                // Check if column exists
                rs.findColumn(columnName);
                
                // Map based on field type
                Class<?> fieldType = field.getType();
                if (fieldType == Long.class || fieldType == long.class) {
                    field.set(entity, rs.getLong(columnName));
                } else if (fieldType == Integer.class || fieldType == int.class) {
                    field.set(entity, rs.getInt(columnName));
                } else if (fieldType == String.class) {
                    field.set(entity, rs.getString(columnName));
                } else if (fieldType == Boolean.class || fieldType == boolean.class) {
                    field.set(entity, rs.getBoolean(columnName));
                } else if (fieldType == LocalDate.class) {
                    java.sql.Date date = rs.getDate(columnName);
                    if (date != null) {
                        field.set(entity, date.toLocalDate());
                    }
                } else if (fieldType == LocalDateTime.class) {
                    java.sql.Timestamp timestamp = rs.getTimestamp(columnName);
                    if (timestamp != null) {
                        field.set(entity, timestamp.toLocalDateTime());
                    }
                } else if (fieldType == Double.class || fieldType == double.class) {
                    field.set(entity, rs.getDouble(columnName));
                } else if (fieldType == Float.class || fieldType == float.class) {
                    field.set(entity, rs.getFloat(columnName));
                }
            } catch (Exception e) {
                // Column doesn't exist or mapping failed, skip this field
            }
        }
        
        return entity;
    };
    
    // Convert camelCase to snake_case
    private String camelToSnake(String camelCase) {
        return camelCase.replaceAll("([a-z])([A-Z]+)", "$1_$2").toLowerCase();
    }
"@
    
    # Generate methods based on API definition
    foreach ($operation in $apiDef.Operations) {
        $operationType = $operation.Type
        
        # Find matching Mule flow
        $matchingFlow = $null
        if ($muleImpl) {
            foreach ($flow in $muleImpl.Flows) {
                if (($operationType -eq "getAll" -and $flow.OperationType -eq "select" -and $flow.SQL -notmatch 'WHERE.*id') -or
                    ($operationType -eq "getById" -and $flow.OperationType -eq "select" -and $flow.SQL -match 'WHERE.*id') -or
                    ($operationType -eq "create" -and $flow.OperationType -eq "insert") -or
                    ($operationType -eq "update" -and $flow.OperationType -eq "update") -or
                    ($operationType -eq "delete" -and $flow.OperationType -eq "delete")) {
                    $matchingFlow = $flow
                    break
                }
            }
        }
        
        switch ($operationType) {
            "getAll" {
                if ($matchingFlow) {
                    # Use actual SQL from Mule flow
                    $sql = $matchingFlow.SQL -replace ':\w+', '?'
                    if ($sql -match 'WHERE') {
                        # Has parameters
                        $serviceClass += @"
    
    // Get all ${entityName.ToLower()}s
    public List<$entityName> getAll${entityName}s() {
        // Note: This query has parameters in Mule flow, defaulting to no filter
        String sql = "SELECT * FROM $tableName";
        return jdbcTemplate.query(sql, ${entityName.ToLower()}RowMapper);
    }
    
    // Get ${entityName.ToLower()}s with filter
    public List<$entityName> get${entityName}sByStatus(String status) {
        String sql = "$sql";
        return jdbcTemplate.query(sql, ${entityName.ToLower()}RowMapper, status);
    }
"@
                    } else {
                        $serviceClass += @"
    
    // Get all ${entityName.ToLower()}s
    public List<$entityName> getAll${entityName}s() {
        String sql = "$sql";
        return jdbcTemplate.query(sql, ${entityName.ToLower()}RowMapper);
    }
"@
                    }
                } else {
                    # Generate stub
                    $serviceClass += @"
    
    // Get all ${entityName.ToLower()}s
    public List<$entityName> getAll${entityName}s() {
        String sql = "SELECT * FROM $tableName";
        return jdbcTemplate.query(sql, ${entityName.ToLower()}RowMapper);
    }
"@
                }
            }
            "getById" {
                $serviceClass += @"
    
    // Get $entityName by ID
    public $entityName get${entityName}ById(Long id) {
        String sql = "SELECT * FROM $tableName WHERE id = ?";
        try {
            return jdbcTemplate.queryForObject(sql, ${entityName.ToLower()}RowMapper, id);
        } catch (EmptyResultDataAccessException e) {
            throw new ResourceNotFoundException("$entityName not found with id: " + id);
        }
    }
"@
            }
            "create" {
                if ($matchingFlow -and $matchingFlow.SQL -match 'INSERT INTO \w+ \(([^)]+)\)') {
                    # Parse actual columns from Mule SQL
                    $columns = $matches[1] -split ',\s*'
                    $setParams = ""
                    $paramIndex = 1
                    
                    foreach ($col in $columns) {
                        $colName = $col.Trim()
                        # Skip generated columns
                        if ($colName -notmatch 'NOW\(\)' -and $colName -ne 'id') {
                            # Convert to camelCase
                            $parts = $colName -split '_'
                            $fieldName = $parts[0]
                            for ($i = 1; $i -lt $parts.Count; $i++) {
                                if ($parts[$i].Length -gt 0) {
                                    $fieldName += $parts[$i].Substring(0,1).ToUpper() + $parts[$i].Substring(1)
                                }
                            }
                            $getterName = "get" + $fieldName.Substring(0,1).ToUpper() + $fieldName.Substring(1)
                            
                            # Special handling for date fields
                            if ($colName -match 'date|time') {
                                $setParams += "            if (entity.$getterName() != null) {`n"
                                if ($colName -match 'date_of_birth|hire_date') {
                                    $setParams += "                ps.setDate($paramIndex, java.sql.Date.valueOf(entity.$getterName()));`n"
                                } else {
                                    $setParams += "                ps.setTimestamp($paramIndex, java.sql.Timestamp.valueOf(entity.$getterName()));`n"
                                }
                                $setParams += "            } else {`n"
                                $setParams += "                ps.setNull($paramIndex, java.sql.Types.DATE);`n"
                                $setParams += "            }`n"
                            } else {
                                $setParams += "            ps.setObject($paramIndex, entity.$getterName());`n"
                            }
                            $paramIndex++
                        } elseif ($colName -match 'NOW\(\)') {
                            $setParams += "            ps.setTimestamp($paramIndex, java.sql.Timestamp.valueOf(LocalDateTime.now()));`n"
                            $paramIndex++
                        }
                    }
                    
                    $serviceClass += @"
    
    // Create new $entityName
    public $entityName create$entityName($entityName entity) {
        String sql = "$($matchingFlow.SQL -replace ':\w+', '?')";
        
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbcTemplate.update(connection -> {
            PreparedStatement ps = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
$setParams            return ps;
        }, keyHolder);
        
        if (keyHolder.getKey() != null) {
            entity.setId(keyHolder.getKey().longValue());
        }
        
        return entity;
    }
"@
                } else {
                    # Generate generic create
                    $serviceClass += @"
    
    // Create new $entityName
    public $entityName create$entityName($entityName entity) {
        // TODO: Implement based on your schema
        throw new UnsupportedOperationException("Create operation not implemented in Mule flows");
    }
"@
                }
            }
            "update" {
                $serviceClass += @"
    
    // Update $entityName
    public $entityName update$entityName(Long id, $entityName entity) {
        // TODO: Implement based on your schema
        String sql = "UPDATE $tableName SET /* fields */ WHERE id = ?";
        throw new UnsupportedOperationException("Update operation not implemented in Mule flows");
    }
"@
            }
            "delete" {
                $serviceClass += @"
    
    // Delete $entityName
    public void delete$entityName(Long id) {
        String sql = "DELETE FROM $tableName WHERE id = ?";
        int deleted = jdbcTemplate.update(sql, id);
        
        if (deleted == 0) {
            throw new ResourceNotFoundException("$entityName not found with id: " + id);
        }
    }
"@
            }
        }
    }
    
    $serviceClass += @"
}
"@
    
    # Write service file without BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText("$servicePath\${entityName}Service.java", $serviceClass, $utf8NoBom)
    Write-Host "  Generated service: ${entityName}Service.java" -ForegroundColor White
}

# Handle additional services (like AddressService for Customer)
if ($muleImplementations.ContainsKey("Address") -and -not $apiDefinitions.ContainsKey("Address")) {
    # Address is referenced in Mule but not as a main resource
    $addressImpl = $muleImplementations["Address"]
    
    Write-Host "`nGenerating AddressService..." -ForegroundColor Green
    
    $addressService = @"
package $packageName.service;

import $packageName.model.Address;
import $packageName.exception.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * AddressService - Service for Address management
 */
@Service
public class AddressService {
    
    @Autowired
    private JdbcTemplate jdbcTemplate;
    
    // Row mapper for Address
    private final RowMapper<Address> addressRowMapper = (rs, rowNum) -> {
        Address entity = new Address();
        
        // Use reflection to map fields dynamically
        java.lang.reflect.Field[] fields = entity.getClass().getDeclaredFields();
        for (java.lang.reflect.Field field : fields) {
            field.setAccessible(true);
            String fieldName = field.getName();
            String columnName = camelToSnake(fieldName);
            
            try {
                rs.findColumn(columnName);
                Class<?> fieldType = field.getType();
                if (fieldType == Long.class || fieldType == long.class) {
                    field.set(entity, rs.getLong(columnName));
                } else if (fieldType == String.class) {
                    field.set(entity, rs.getString(columnName));
                } else if (fieldType == Boolean.class || fieldType == boolean.class) {
                    field.set(entity, rs.getBoolean(columnName));
                }
            } catch (Exception e) {
                // Column doesn't exist or mapping failed, skip this field
            }
        }
        
        return entity;
    };
    
    // Convert camelCase to snake_case
    private String camelToSnake(String camelCase) {
        return camelCase.replaceAll("([a-z])([A-Z]+)", "$1_$2").toLowerCase();
    }
    
    // Get customer addresses
    public List<Address> getCustomerAddresses(Long customerId) {
        String sql = "SELECT * FROM addresses WHERE customer_id = ?";
        return jdbcTemplate.query(sql, addressRowMapper, customerId);
    }
}
"@
    
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText("$servicePath\AddressService.java", $addressService, $utf8NoBom)
    Write-Host "  Generated service: AddressService.java" -ForegroundColor White
}

# Generate other required files
Write-Host "`nGenerating pom.xml..." -ForegroundColor Yellow
& ".\migration-scripts\create-pom.ps1" -outputPath $OutputPath -packageName $PackageName -JavaVersion $JavaVersion

Write-Host "Generating application.yml..." -ForegroundColor Yellow
& ".\migration-scripts\create-application-properties.ps1" -outputPath $OutputPath

Write-Host "Generating main application class..." -ForegroundColor Yellow
& ".\migration-scripts\create-main-application.ps1" -outputPath $OutputPath -packageName $PackageName

Write-Host "Generating schema.sql..." -ForegroundColor Yellow
# Generate a proper schema.sql based on entities
$schemaContent = @"
-- Database Schema

-- Drop tables if they exist (in reverse order due to foreign keys)
DROP TABLE IF EXISTS addresses;
DROP TABLE IF EXISTS customers;

-- Create customers table
CREATE TABLE customers (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20),
    date_of_birth DATE,
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
    registration_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create addresses table
CREATE TABLE addresses (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    street VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(50) NOT NULL,
    zip_code VARCHAR(20) NOT NULL,
    country VARCHAR(100) NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);

-- Create indexes
CREATE INDEX idx_customer_status ON customers(status);
CREATE INDEX idx_customer_email ON customers(email);
CREATE INDEX idx_address_customer ON addresses(customer_id);

-- Insert sample data
INSERT INTO customers (first_name, last_name, email, phone, date_of_birth, status) VALUES
('John', 'Doe', 'john.doe@example.com', '+1-555-0101', '1985-03-15', 'ACTIVE'),
('Jane', 'Smith', 'jane.smith@example.com', '+1-555-0102', '1990-07-22', 'ACTIVE'),
('Robert', 'Johnson', 'robert.j@example.com', '+1-555-0103', '1978-11-30', 'ACTIVE'),
('Maria', 'Garcia', 'maria.garcia@example.com', '+1-555-0104', '1995-01-18', 'INACTIVE');

-- Insert sample addresses
INSERT INTO addresses (customer_id, street, city, state, zip_code, country, is_primary) VALUES
(1, '123 Main St', 'New York', 'NY', '10001', 'USA', true),
(1, '456 Oak Ave', 'Brooklyn', 'NY', '11201', 'USA', false),
(2, '789 Pine Rd', 'Los Angeles', 'CA', '90001', 'USA', true),
(3, '321 Elm St', 'Chicago', 'IL', '60601', 'USA', true);
"@

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$OutputPath\src\main\resources\schema.sql", $schemaContent, $utf8NoBom)

# Generate exception classes
$exceptionPath = "$OutputPath\src\main\java\$($PackageName -replace '\.','\\')\exception"
if (-not (Test-Path "$exceptionPath\ResourceNotFoundException.java")) {
    if (-not (Test-Path $exceptionPath)) {
        New-Item -ItemType Directory -Force -Path $exceptionPath | Out-Null
    }
    
    $resourceNotFound = @"
package $packageName.exception;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.NOT_FOUND)
public class ResourceNotFoundException extends RuntimeException {
    public ResourceNotFoundException(String message) {
        super(message);
    }
}
"@
    
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText("$exceptionPath\ResourceNotFoundException.java", $resourceNotFound, $utf8NoBom)
}

Write-Host "`n================================================" -ForegroundColor Green
Write-Host "Smart Migration Completed Successfully!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green

Write-Host "`nOutput location: $OutputPath" -ForegroundColor Cyan
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. cd $OutputPath" -ForegroundColor White
Write-Host "2. mvn clean package" -ForegroundColor White
Write-Host "3. mvn spring-boot:run" -ForegroundColor White

# Count generated files
$javaFiles = Get-ChildItem -Path "$OutputPath\src\main\java" -Filter "*.java" -Recurse
$configFiles = Get-ChildItem -Path "$OutputPath\src\main\resources" -Filter "*.*" -Recurse

Write-Host "`nGenerated files summary:" -ForegroundColor Yellow
Write-Host "  - Java files: $($javaFiles.Count)" -ForegroundColor White
Write-Host "  - Configuration files: $($configFiles.Count)" -ForegroundColor White
Write-Host "================================================" -ForegroundColor Green 