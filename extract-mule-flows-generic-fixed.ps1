param (
    [string]$muleXmlPath,
    [string]$outputPath,
    [string]$packageName = "com.example.api"
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Generic Mule Flow to Spring Boot Converter" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Load the XML file
[xml]$muleDoc = Get-Content $muleXmlPath
Write-Host "Processing Mule XML: $muleXmlPath" -ForegroundColor Yellow

# Create namespace manager
$namespaceManager = New-Object System.Xml.XmlNamespaceManager($muleDoc.NameTable)
$namespaceManager.AddNamespace("mule", "http://www.mulesoft.org/schema/mule/core")
$namespaceManager.AddNamespace("http", "http://www.mulesoft.org/schema/mule/http")
$namespaceManager.AddNamespace("db", "http://www.mulesoft.org/schema/mule/db")
$namespaceManager.AddNamespace("ee", "http://www.mulesoft.org/schema/mule/ee/core")

# Extract all flows
$flows = $muleDoc.SelectNodes("//mule:flow", $namespaceManager)
Write-Host "Found $($flows.Count) flows" -ForegroundColor Green

# Create service directory
$servicePath = Join-Path $outputPath "service"
if (-not (Test-Path $servicePath)) {
    New-Item -ItemType Directory -Force -Path $servicePath | Out-Null
}

# Group flows by resource/entity
$services = @{}

foreach ($flow in $flows) {
    $flowName = $flow.GetAttribute("name")
    Write-Host "  Processing flow: $flowName" -ForegroundColor Yellow
    
    # Extract entity name from flow name
    $entityName = ""
    if ($flowName -match '([a-zA-Z]+)-flow$' -or $flowName -match '-([a-zA-Z]+)-') {
        $parts = $flowName -split '-'
        foreach ($part in $parts) {
            if ($part -ne 'get' -and $part -ne 'create' -and $part -ne 'update' -and 
                $part -ne 'delete' -and $part -ne 'all' -and $part -ne 'by' -and 
                $part -ne 'flow' -and $part.Length -gt 2) {
                $entityName = $part.Substring(0,1).ToUpper() + $part.Substring(1).ToLower()
                if ($entityName.EndsWith('s')) {
                    $entityName = $entityName.TrimEnd('s')
                }
                break
            }
        }
    }
    
    if ($entityName -eq "") {
        $entityName = "Generic"
    }
    
    if (-not $services.ContainsKey($entityName)) {
        $services[$entityName] = @{
            Operations = @()
            TableName = ""
        }
    }
    
    # Extract HTTP listener info
    $httpListener = $flow.SelectSingleNode(".//http:listener", $namespaceManager)
    if ($httpListener) {
        $path = $httpListener.GetAttribute("path")
        $method = $httpListener.GetAttribute("allowedMethods")
        if (-not $method) { $method = "GET" }
    }
    
    # Extract database operations
    $dbOperations = $flow.SelectNodes(".//db:*", $namespaceManager)
    foreach ($dbOp in $dbOperations) {
        $operationType = $dbOp.LocalName
        $sqlNode = $dbOp.SelectSingleNode(".//db:sql", $namespaceManager)
        
        if ($sqlNode) {
            $sqlText = $sqlNode.InnerText.Trim() -replace '\s+', ' '
            
            # Extract table name from SQL
            if ($sqlText -match 'FROM\s+(\w+)' -or $sqlText -match 'INTO\s+(\w+)' -or 
                $sqlText -match 'UPDATE\s+(\w+)' -or $sqlText -match 'DELETE\s+FROM\s+(\w+)') {
                $tableName = $matches[1]
                if ($services[$entityName].TableName -eq "") {
                    $services[$entityName].TableName = $tableName
                }
            }
            
            # Create operation info
            $operation = @{
                FlowName = $flowName
                Type = $operationType
                SQL = $sqlText
                Method = $method
                Path = $path
            }
            
            $services[$entityName].Operations += $operation
        }
    }
}

# Generate service classes
foreach ($entityName in $services.Keys) {
    $service = $services[$entityName]
    $tableName = if ($service.TableName) { $service.TableName } else { $entityName.ToLower() + "s" }
    
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
import java.util.List;

/**
 * ${entityName}Service - Generated from Mule flows
 * Table: $tableName
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
                } else if (fieldType == java.time.LocalDate.class) {
                    java.sql.Date date = rs.getDate(columnName);
                    if (date != null) {
                        field.set(entity, date.toLocalDate());
                    }
                } else if (fieldType == java.time.LocalDateTime.class) {
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

    # Generate methods based on operations
    foreach ($op in $service.Operations) {
        $operationType = $op.Type
        
        switch ($operationType) {
            "select" {
                if ($op.SQL -match 'WHERE') {
                    # Check if it's a get by ID query
                    if ($op.SQL -match 'WHERE\s+id\s*=|WHERE\s+\w+\.id\s*=') {
                        # Generate both getById and getByCriteria methods
                        $serviceClass += @"
    
    public $entityName get${entityName}ById(Long id) {
        String sql = "$($op.SQL -replace ':\w+', '?')";
        try {
            return jdbcTemplate.queryForObject(sql, ${entityName.ToLower()}RowMapper, id);
        } catch (EmptyResultDataAccessException e) {
            throw new ResourceNotFoundException("$entityName not found with id: " + id);
        }
    }
    
    public List<$entityName> get${entityName}sByCriteria(Object... params) {
        String sql = "$($op.SQL -replace ':\w+', '?')";
        return jdbcTemplate.query(sql, params, ${entityName.ToLower()}RowMapper);
    }
"@
                    } else {
                        # Get by other criteria
                        $serviceClass += @"
    
    public List<$entityName> get${entityName}sByCriteria(Object... params) {
        String sql = "$($op.SQL -replace ':\w+', '?')";
        return jdbcTemplate.query(sql, params, ${entityName.ToLower()}RowMapper);
    }
"@
                    }
                } else {
                    # Get all
                    $serviceClass += @"
    
    public List<$entityName> getAll${entityName}s() {
        String sql = "$($op.SQL)";
        return jdbcTemplate.query(sql, ${entityName.ToLower()}RowMapper);
    }
"@
                }
            }
            "insert" {
                                    # Extract column names from INSERT statement
                    if ($op.SQL -match 'INSERT INTO \w+ \(([^)]+)\)') {
                        $columns = $matches[1] -split ',\s*'
                        $setParams = ""
                        $paramIndex = 1
                        foreach ($col in $columns) {
                            $colName = $col.Trim()
                            # Convert snake_case to camelCase
                            $parts = $colName -split '_'
                            $fieldName = $parts[0]
                            for ($i = 1; $i -lt $parts.Count; $i++) {
                                if ($parts[$i].Length -gt 0) {
                                    $fieldName += $parts[$i].Substring(0,1).ToUpper() + $parts[$i].Substring(1)
                                }
                            }
                            $methodName = $fieldName.Substring(0,1).ToUpper() + $fieldName.Substring(1)
                            $setParams += "            ps.setObject($paramIndex, entity.get$methodName());`n"
                            $paramIndex++
                        }
                        
                        $serviceClass += @"
    
    public $entityName create$entityName($entityName entity) {
        String sql = "$($op.SQL -replace ':\w+', '?')";
        
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
                        # Fallback if we can't parse the INSERT
                        $serviceClass += @"
    
    public $entityName create$entityName($entityName entity) {
        String sql = "$($op.SQL -replace ':\w+', '?')";
        
        // TODO: Implement based on your entity properties
        throw new UnsupportedOperationException("Create method needs implementation");
    }
"@
                    }
            }
                            "update" {
                    # Extract SET columns from UPDATE statement
                    if ($op.SQL -match 'SET\s+(.+?)\s+WHERE') {
                        $setPart = $matches[1]
                        $params = @()
                        
                        # Parse SET clause
                        $setPart -split ',\s*' | ForEach-Object {
                            if ($_ -match '(\w+)\s*=') {
                                $colName = $matches[1].Trim()
                                # Convert snake_case to camelCase
                                $parts = $colName -split '_'
                                $fieldName = $parts[0]
                                for ($i = 1; $i -lt $parts.Count; $i++) {
                                    if ($parts[$i].Length -gt 0) {
                                        $fieldName += $parts[$i].Substring(0,1).ToUpper() + $parts[$i].Substring(1)
                                    }
                                }
                                $methodName = $fieldName.Substring(0,1).ToUpper() + $fieldName.Substring(1)
                                $params += "entity.get$methodName()"
                            }
                        }
                        
                        # Add ID parameter at the end (for WHERE clause)
                        $params += "id"
                        $paramList = $params -join ', '
                        
                        $serviceClass += @"
    
    public $entityName update$entityName(Long id, $entityName entity) {
        String sql = "$($op.SQL -replace ':\w+', '?')";
        int updated = jdbcTemplate.update(sql, $paramList);
        
        if (updated == 0) {
            throw new ResourceNotFoundException("$entityName not found with id: " + id);
        }
        
        entity.setId(id);
        return entity;
    }
"@
                    } else {
                        # Fallback
                        $serviceClass += @"
    
    public $entityName update$entityName(Long id, $entityName entity) {
        String sql = "$($op.SQL -replace ':\w+', '?')";
        // TODO: Implement based on your entity properties
        throw new UnsupportedOperationException("Update method needs implementation");
    }
"@
                    }
            }
            "delete" {
                $serviceClass += @"
    
    public void delete$entityName(Long id) {
        String sql = "$($op.SQL -replace ':\w+', '?')";
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
    
    # Write service file
    # Write without BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$servicePath\${entityName}Service.java", $serviceClass, $utf8NoBom)
    Write-Host "  Generated service: ${entityName}Service.java" -ForegroundColor White
}

# Generate exception classes if not already present
$exceptionPath = Join-Path $outputPath "exception"
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
    
    $resourceNotFound | Out-File -FilePath "$exceptionPath\ResourceNotFoundException.java" -Encoding ASCII
}

Write-Host "`n================================================" -ForegroundColor Green
Write-Host "Mule flow extraction completed!" -ForegroundColor Green
Write-Host "Generated:" -ForegroundColor Yellow
Write-Host "  - Service classes: $($services.Count)" -ForegroundColor White
Write-Host "================================================" -ForegroundColor Green 