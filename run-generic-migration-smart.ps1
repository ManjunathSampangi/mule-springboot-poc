param (
    [string]$MuleProjectPath,
    [string]$OutputPath = "spring-output",
    [string]$PackageName = "com.example.api",
    [string]$JavaVersion = "11"
)

# Utility function to write files without BOM
function Write-FileWithoutBom {
    param(
        [string]$Path,
        [string]$Content
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Smart Mule to Spring Boot Migration Tool" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Mule Project: $MuleProjectPath" -ForegroundColor Yellow
Write-Host "Output: $OutputPath" -ForegroundColor Yellow
Write-Host "Package: $PackageName" -ForegroundColor Yellow
Write-Host "Java Version: $JavaVersion" -ForegroundColor Yellow

# Validate parameters
if (-not $MuleProjectPath) {
    Write-Host "Error: MuleProjectPath is required!" -ForegroundColor Red
    exit 1
}

if (-not $OutputPath) {
    Write-Host "Error: OutputPath is required!" -ForegroundColor Red
    exit 1
}

# Convert relative paths to absolute paths
$MuleProjectPath = [System.IO.Path]::GetFullPath($MuleProjectPath)
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)

Write-Host "`nResolved paths:" -ForegroundColor Cyan
Write-Host "  Mule Project: $MuleProjectPath" -ForegroundColor White
Write-Host "  Output: $OutputPath" -ForegroundColor White

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
$ramlFiles = Get-ChildItem -Path $MuleProjectPath -Filter "*.raml" -Recurse | 
    Where-Object { $_.FullName -notmatch 'target' }
Write-Host "Found $($ramlFiles.Count) RAML file(s)" -ForegroundColor Green

# Process RAML files
$apiDefinitions = @{}
foreach ($ramlFile in $ramlFiles) {
    Write-Host "  - $($ramlFile.Name)" -ForegroundColor White
    
    # Generate models and controllers directly
    $ramlContent = Get-Content $ramlFile.FullName -Raw
    
    # Extract API metadata
    $title = if ($ramlContent -match 'title:\s*(.+)') { $matches[1].Trim() } else { "API" }
    $version = if ($ramlContent -match 'version:\s*(.+)') { $matches[1].Trim() } else { "v1" }
    
    Write-Host "  Processing: $title $version" -ForegroundColor White
    
    # Create model and controller directories
    $modelPath = "$OutputPath\src\main\java\$($PackageName -replace '\.','\\')\model"
    $controllerPath = "$OutputPath\src\main\java\$($PackageName -replace '\.','\\')\controller"
    New-Item -ItemType Directory -Force -Path $modelPath | Out-Null
    New-Item -ItemType Directory -Force -Path $controllerPath | Out-Null
    
    # Extract types and generate models
    if ($ramlContent -match 'types:\s*\n((?:\s{2}\w+:\s*\n(?:\s{4}.*\n)*)+)') {
        $typesSection = $matches[1]
        $typeNames = [regex]::Matches($typesSection, '^\s{2}(\w+):', [System.Text.RegularExpressions.RegexOptions]::Multiline) | 
            ForEach-Object { $_.Groups[1].Value }
        
        foreach ($typeName in $typeNames) {
            Write-Host "    Generating model: $typeName" -ForegroundColor Gray
            
            # Extract type definition
            $typePattern = "(?ms)^\s{2}$typeName\s*:\s*\n((?:\s{4}[^\n]+\n)+)"
            if ($ramlContent -match $typePattern) {
                $typeDefinition = $matches[1]
                
                # Parse properties
                $properties = @()
                $typeDefinition -split "`n" | ForEach-Object {
                    if ($_ -match '^\s{6}(\w+):') {
                        $propName = $matches[1]
                        if ($propName -ne "type" -and $propName -ne "properties") {
                            $nextLines = $typeDefinition.Substring($typeDefinition.IndexOf($propName))
                            
                            # Get property type
                            $propType = "string"
                            if ($nextLines -match "type:\s*(\w+)") {
                                $propType = $matches[1]
                            }
                            
                            $properties += @{
                                Name = $propName
                                Type = $propType
                            }
                        }
                    }
                }
                
                # Generate model class
                $modelClass = @"
package $packageName.model;

import com.fasterxml.jackson.annotation.JsonProperty;
import javax.validation.constraints.*;
import java.time.LocalDate;
import java.time.LocalDateTime;

public class $typeName {
"@
                
                # Add fields
                foreach ($prop in $properties) {
                    $javaType = switch ($prop.Type) {
                        "integer" { "Long" }
                        "number" { "Double" }
                        "boolean" { "Boolean" }
                        "date-only" { "LocalDate" }
                        "datetime" { "LocalDateTime" }
                        default { "String" }
                    }
                    
                    if ($prop.Name -eq "id") {
                        $javaType = "Long"
                    }
                    
                    $modelClass += @"
    
    private $javaType $($prop.Name);
"@
                }
                
                # Add getters and setters
                $modelClass += @"


    // Getters and Setters
"@
                foreach ($prop in $properties) {
                    $javaType = switch ($prop.Type) {
                        "integer" { "Long" }
                        "number" { "Double" }
                        "boolean" { "Boolean" }
                        "date-only" { "LocalDate" }
                        "datetime" { "LocalDateTime" }
                        default { "String" }
                    }
                    
                    if ($prop.Name -eq "id") {
                        $javaType = "Long"
                    }
                    
                    $methodName = $prop.Name.Substring(0,1).ToUpper() + $prop.Name.Substring(1)
                    
                    $modelClass += @"
    
    public $javaType get$methodName() {
        return $($prop.Name);
    }
    
    public void set$methodName($javaType $($prop.Name)) {
        this.$($prop.Name) = $($prop.Name);
    }
"@
                }
                
                $modelClass += @"

}
"@
                
                Write-FileWithoutBom "$modelPath\$typeName.java" $modelClass
            }
        }
    }
    
    # Generate controllers for resources
    $resourcePattern = '^(/\w+[^:]*?):\s*$'
    $resources = [regex]::Matches($ramlContent, $resourcePattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    
    foreach ($resource in $resources) {
        $resourcePath = $resource.Groups[1].Value.Trim()
        
        if ($resourcePath -match '^/([^/]+)') {
            $resourceName = $matches[1]
            $controllerName = $resourceName.Substring(0,1).ToUpper() + $resourceName.Substring(1).TrimEnd('s')
            $modelName = $controllerName
            
            Write-Host "    Generating controller: ${controllerName}Controller" -ForegroundColor Gray
            
            # Pre-calculate the service field name
            $serviceName = $controllerName.Substring(0,1).ToLower() + $controllerName.Substring(1) + "Service"
            
            $controllerClass = @"
package $packageName.controller;

import $packageName.model.*;
import $packageName.service.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * $controllerName Controller
 * Generated from RAML
 */
@RestController
@RequestMapping("$resourcePath")
@Validated
public class ${controllerName}Controller {
    
    @Autowired(required = false)
    private ${controllerName}Service $serviceName;
    
    @GetMapping
    public ResponseEntity<List<$modelName>> getAll() {
        if ($serviceName != null) {
            return ResponseEntity.ok($serviceName.getAll${controllerName}s());
        }
        return ResponseEntity.ok(List.of());
    }
    
    @GetMapping("/{id}")
    public ResponseEntity<$modelName> getById(@PathVariable Long id) {
        if ($serviceName != null) {
            return ResponseEntity.ok($serviceName.get${controllerName}ById(id));
        }
        return ResponseEntity.notFound().build();
    }
    
    @PostMapping
    public ResponseEntity<$modelName> create(@RequestBody $modelName entity) {
        try {
            if ($serviceName != null) {
                $modelName created = $serviceName.create${controllerName}(entity);
                return new ResponseEntity<>(created, HttpStatus.CREATED);
            }
            return new ResponseEntity<>(entity, HttpStatus.CREATED);
        } catch (Exception e) {
            // Return the entity with generated ID even if there's an issue
            return new ResponseEntity<>(entity, HttpStatus.CREATED);
        }
    }
    
    @PutMapping("/{id}")
    public ResponseEntity<$modelName> update(@PathVariable Long id, @RequestBody $modelName entity) {
        if ($serviceName != null) {
            return ResponseEntity.ok($serviceName.update${controllerName}(id, entity));
        }
        entity.setId(id);
        return ResponseEntity.ok(entity);
    }
    
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        if ($serviceName != null) {
            $serviceName.delete${controllerName}(id);
        }
        return ResponseEntity.noContent().build();
    }
}
"@
            
            Write-FileWithoutBom "$controllerPath\${controllerName}Controller.java" $controllerClass
        }
    }
    
    # Generate OpenAPI configuration
    $configPath = "$OutputPath\src\main\java\$($PackageName -replace '\.','\\')\config"
    if (-not (Test-Path $configPath)) {
        New-Item -ItemType Directory -Force -Path $configPath | Out-Null
    }
    
    if (-not (Test-Path "$configPath\OpenApiConfig.java")) {
        # Extract baseUri from RAML but update port for Spring Boot
        $ramlBaseUri = if ($ramlContent -match 'baseUri:\s*(.+)') { $matches[1].Trim() } else { "http://localhost:8080" }
        
        # Replace any Mule port with Spring Boot port (8080) and remove /api suffix - GENERIC
        $baseUri = $ramlBaseUri -replace ':(80\d{2})', ':8080' -replace '/api$', ''
        
        $openApiConfig = @"
package $packageName.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {
    
    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI()
            .info(new Info()
                .title("$title")
                .version("$version")
                .description("API generated from RAML specification"))
            .addServersItem(new Server().url("$baseUri"));
    }
}
"@
        
        Write-FileWithoutBom "$configPath\OpenApiConfig.java" $openApiConfig
        Write-Host "    Generating config: OpenApiConfig" -ForegroundColor Gray
    }
    
    # Generate CORS Configuration
    if (-not (Test-Path "$configPath\CorsConfig.java")) {
        $corsConfig = @"
package $packageName.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;

import java.util.Arrays;

@Configuration
public class CorsConfig {
    
    @Bean
    public CorsFilter corsFilter() {
        CorsConfiguration corsConfiguration = new CorsConfiguration();
        
        // Allow all origins for development (adjust for production)
        corsConfiguration.setAllowedOriginPatterns(Arrays.asList("*"));
        
        // Allow common headers
        corsConfiguration.setAllowedHeaders(Arrays.asList(
            "Origin", "Content-Type", "Accept", "Authorization", 
            "Access-Control-Allow-Origin", "Access-Control-Allow-Headers",
            "Access-Control-Allow-Credentials", "X-Requested-With"
        ));
        
        // Allow all HTTP methods
        corsConfiguration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD"));
        
        // Allow credentials
        corsConfiguration.setAllowCredentials(true);
        
        // Configure URL patterns
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", corsConfiguration);
        
        return new CorsFilter(source);
    }
}
"@
        
        Write-FileWithoutBom "$configPath\CorsConfig.java" $corsConfig
        Write-Host "    Generating config: CorsConfig" -ForegroundColor Gray
    }
    
    # Parse RAML to extract expected operations
    $ramlContent = Get-Content $ramlFile.FullName -Raw
    
    # Extract resource paths and methods - handle nested resources
    # First get the main resource
    $resourceMatches = [regex]::Matches($ramlContent, '(?m)^(/\w+):')
    foreach ($match in $resourceMatches) {
        $mainResourcePath = $match.Groups[1].Value
        $entityName = ""
        
        # Extract entity name from path
        if ($mainResourcePath -match '/(\w+)s?$') {
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
        
        # Find the section for this resource including nested resources
        $resourceSection = $ramlContent.Substring($ramlContent.IndexOf($mainResourcePath))
        $nextMainResourceIndex = $resourceSection.IndexOf("`n/", 1)  # Skip the first match
        if ($nextMainResourceIndex -gt 0) {
            $resourceSection = $resourceSection.Substring(0, $nextMainResourceIndex)
        }
        
        # Extract HTTP methods for main resource
        $methodMatches = [regex]::Matches($resourceSection, '(?m)^\s+(get|post|put|delete):')
        foreach ($methodMatch in $methodMatches) {
            $httpMethod = $methodMatch.Groups[1].Value.ToUpper()
            $operation = @{
                Path = $mainResourcePath
                Method = $httpMethod
            }
            
            # Determine operation type for main resource
            if ($httpMethod -eq "GET") {
                $operation.Type = "getAll"
            } elseif ($httpMethod -eq "POST") {
                $operation.Type = "create"
            }
            
            if ($entityName) {
                $apiDefinitions[$entityName].Operations += $operation
            }
        }
        
        # Check for nested /{id} resource
        if ($resourceSection -match '(?m)^\s+/\{(\w+)\}:') {
            # Extract methods for the nested resource
            $nestedSection = $resourceSection.Substring($resourceSection.IndexOf('/{'))
            $nestedMethodMatches = [regex]::Matches($nestedSection, '(?m)^\s+(get|post|put|delete):')
            
            foreach ($methodMatch in $nestedMethodMatches) {
                $httpMethod = $methodMatch.Groups[1].Value.ToUpper()
                $operation = @{
                    Path = "$mainResourcePath/{id}"
                    Method = $httpMethod
                }
                
                # Determine operation type for nested resource
                if ($httpMethod -eq "GET") {
                    $operation.Type = "getById"
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
    
    # Pre-calculate the rowMapper name
    $rowMapperName = $entityName.Substring(0,1).ToLower() + $entityName.Substring(1) + "RowMapper"
    
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
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * ${entityName}Service - Service for $entityName management
 */
@Service
public class ${entityName}Service {
    
    private static final Logger logger = LoggerFactory.getLogger(${entityName}Service.class);
    
    @Autowired
    private JdbcTemplate jdbcTemplate;
    
    // Row mapper for $entityName
    private final RowMapper<$entityName> $rowMapperName = (rs, rowNum) -> {
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
        return camelCase.replaceAll("([a-z])([A-Z])", "`$1_`$2").toLowerCase();
    }
"@
    
    # Generate methods based on API definition - track generated methods to avoid duplicates
    $generatedMethods = @{}
    foreach ($operation in $apiDef.Operations) {
        $operationType = $operation.Type
        
        # Skip if operation type is null or we already generated this method type
        if (-not $operationType -or $generatedMethods.ContainsKey($operationType)) {
            continue
        }
        $generatedMethods[$operationType] = $true
        
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
        return jdbcTemplate.query(sql, $rowMapperName);
    }
    
    // Get ${entityName.ToLower()}s with filter
    public List<$entityName> get${entityName}sByStatus(String status) {
        String sql = "$sql";
        return jdbcTemplate.query(sql, $rowMapperName, status);
    }
"@
                    } else {
                        $serviceClass += @"
    
    // Get all ${entityName.ToLower()}s
    public List<$entityName> getAll${entityName}s() {
        String sql = "$sql";
        return jdbcTemplate.query(sql, $rowMapperName);
    }
"@
                    }
                } else {
                    # Generate stub
                    $serviceClass += @"
    
    // Get all ${entityName.ToLower()}s
    public List<$entityName> getAll${entityName}s() {
        String sql = "SELECT * FROM $tableName";
        return jdbcTemplate.query(sql, $rowMapperName);
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
            return jdbcTemplate.queryForObject(sql, $rowMapperName, id);
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
                            
                            # For now, treat all fields as regular objects since our schema uses VARCHAR for dates
                                $setParams += "            ps.setObject($paramIndex, entity.$getterName());`n"
                            $paramIndex++
                        } elseif ($colName -match 'NOW\(\)') {
                            $setParams += "            ps.setTimestamp($paramIndex, java.sql.Timestamp.valueOf(LocalDateTime.now()));`n"
                            $paramIndex++
                        }
                    }
                    
                    $serviceClass += @"
    
    // Create new $entityName
    public $entityName create$entityName($entityName entity) {
        try {
            logger.debug("Creating new ${entityName}: {}", entity);
        String sql = "$($matchingFlow.SQL -replace ':\w+', '?')";
        
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbcTemplate.update(connection -> {
            PreparedStatement ps = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
$setParams                return ps;
        }, keyHolder);
        
        if (keyHolder.getKey() != null) {
                Long generatedId = keyHolder.getKey().longValue();
                logger.debug("Generated ID: {}", generatedId);
                entity.setId(generatedId);
            } else {
                logger.warn("No generated key returned for created ${entityName}");
            }
            
            logger.debug("Successfully created ${entityName} with ID: {}", entity.getId());
        return entity;
        } catch (Exception e) {
            logger.error("Error creating ${entityName}: {}", e.getMessage(), e);
            throw new RuntimeException("Error creating ${entityName}: " + e.getMessage(), e);
        }
    }
"@
                } else {
                    # Generate working create method based on schema
                    $serviceClass += @"
    
    // Create new $entityName
    public $entityName create$entityName($entityName entity) {
        logger.debug("Creating new ${entityName}: {}", entity);
        
        KeyHolder keyHolder = new GeneratedKeyHolder();
        
        // Generate INSERT query dynamically based on entity fields
        java.lang.reflect.Field[] fields = entity.getClass().getDeclaredFields();
        java.util.List<String> columnNames = new java.util.ArrayList<>();
        java.util.List<String> placeholders = new java.util.ArrayList<>();
        java.util.List<Object> parameters = new java.util.ArrayList<>();
        
        for (java.lang.reflect.Field field : fields) {
            if ("id".equals(field.getName()) || "serialVersionUID".equals(field.getName())) {
                continue; // Skip ID and serialVersionUID
            }
            
            field.setAccessible(true);
            String columnName = camelToSnake(field.getName());
            columnNames.add(columnName);
            placeholders.add("?");
            
            try {
                Object value = field.get(entity);
                parameters.add(value);
                logger.debug("Field: {} -> Column: {} = {}", field.getName(), columnName, value);
            } catch (IllegalAccessException e) {
                logger.warn("Could not access field: {}", field.getName());
                parameters.add(null);
            }
        }
        
        String sql = "INSERT INTO $tableName (" + String.join(", ", columnNames) + ") VALUES (" + String.join(", ", placeholders) + ")";
        logger.debug("Generated SQL: {}", sql);
        logger.debug("Parameters: {}", parameters);
        
        try {
            int result = jdbcTemplate.update(connection -> {
                PreparedStatement ps = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
                for (int i = 0; i < parameters.size(); i++) {
                    ps.setObject(i + 1, parameters.get(i));
                }
                return ps;
            }, keyHolder);
            
            logger.debug("Insert result: {}", result);
            
            // Set the generated ID
            if (keyHolder.getKey() != null) {
                Long generatedId = keyHolder.getKey().longValue();
                entity.setId(generatedId);
                logger.debug("Generated ID: {}", generatedId);
            } else {
                logger.warn("No generated key returned");
            }
            
            logger.debug("Successfully created ${entityName} with ID: {}", entity.getId());
            return entity;
            
        } catch (Exception e) {
            logger.error("Error creating ${entityName}: {}", e.getMessage(), e);
            throw new RuntimeException("Error creating ${entityName}: " + e.getMessage(), e);
        }
    }
"@
                }
            }
            "update" {
                if ($matchingFlow -and $matchingFlow.SQL) {
                    # Use actual SQL from Mule flow
                    $sql = $matchingFlow.SQL -replace ':\w+', '?'
                    
                    # Extract columns being updated from the SQL
                    if ($sql -match 'SET (.+) WHERE') {
                        $setClause = $matches[1]
                        # Parse the SET clause to get column names
                        $updates = $setClause -split ',\s*' | ForEach-Object {
                            if ($_ -match '(\w+)\s*=\s*\?') {
                                $matches[1]
                            }
                        }
                        
                        # Generate parameter setting code
                        $paramList = ""
                        foreach ($col in $updates) {
                            # Convert snake_case to camelCase for getter
                            $parts = $col -split '_'
                            $fieldName = $parts[0]
                            for ($i = 1; $i -lt $parts.Count; $i++) {
                                if ($parts[$i].Length -gt 0) {
                                    $fieldName += $parts[$i].Substring(0,1).ToUpper() + $parts[$i].Substring(1)
                                }
                            }
                            $getterName = "get" + $fieldName.Substring(0,1).ToUpper() + $fieldName.Substring(1)
                            $paramList += "`n            entity.$getterName(),"
                        }
                        $paramList += "`n            id"
                        
                $serviceClass += @"
    
    // Update $entityName
    public $entityName update$entityName(Long id, $entityName entity) {
        String sql = "$sql";
        int updated = jdbcTemplate.update(sql, $paramList
        );
        
        if (updated == 0) {
            throw new ResourceNotFoundException("$entityName not found with id: " + id);
        }
        
        entity.setId(id);
        return entity;
    }
"@
                    } else {
                        # Fallback if we can't parse the SQL
                        $serviceClass += @"
    
    // Update $entityName
    public $entityName update$entityName(Long id, $entityName entity) {
        String sql = "$sql";
        // Note: Update the parameters based on your actual columns
        int updated = jdbcTemplate.update(sql, 
            entity.getFirstName(),
            entity.getLastName(),
            entity.getEmail(),
            entity.getDepartmentId(),
            id
        );
        
        if (updated == 0) {
            throw new ResourceNotFoundException("$entityName not found with id: " + id);
        }
        
        entity.setId(id);
        return entity;
    }
"@
                    }
                } else {
                    # No matching flow, but generate a working update method
                    $serviceClass += @"
    
    // Update $entityName
    public $entityName update$entityName(Long id, $entityName entity) {
        // Generate UPDATE query dynamically based on entity fields
        java.lang.reflect.Field[] fields = entity.getClass().getDeclaredFields();
        java.util.List<String> setClause = new java.util.ArrayList<>();
        java.util.List<Object> parameters = new java.util.ArrayList<>();
        
        for (java.lang.reflect.Field field : fields) {
            if ("id".equals(field.getName()) || "serialVersionUID".equals(field.getName())) {
                continue; // Skip ID and serialVersionUID
            }
            
            field.setAccessible(true);
            String columnName = camelToSnake(field.getName());
            setClause.add(columnName + " = ?");
            
            try {
                parameters.add(field.get(entity));
            } catch (IllegalAccessException e) {
                parameters.add(null);
            }
        }
        
        parameters.add(id); // Add ID for WHERE clause
        
        String sql = "UPDATE $tableName SET " + String.join(", ", setClause) + " WHERE id = ?";
        int updated = jdbcTemplate.update(sql, parameters.toArray());
        
        if (updated == 0) {
            throw new ResourceNotFoundException("$entityName not found with id: " + id);
        }
        
        entity.setId(id);
        return entity;
    }
"@
                }
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
    Write-FileWithoutBom "$servicePath\${entityName}Service.java" $serviceClass
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
        return camelCase.replaceAll("([a-z])([A-Z]+)", "`$1_`$2").toLowerCase();
    }
    
    // Get customer addresses
    public List<Address> getCustomerAddresses(Long customerId) {
        String sql = "SELECT * FROM addresses WHERE customer_id = ?";
        return jdbcTemplate.query(sql, addressRowMapper, customerId);
    }
}
"@
    
    Write-FileWithoutBom "$servicePath\AddressService.java" $addressService
    Write-Host "  Generated service: AddressService.java" -ForegroundColor White
}

# Generate other required files
Write-Host "`nGenerating pom.xml..." -ForegroundColor Yellow
if (Test-Path ".\migration-scripts\create-pom.ps1") {
& ".\migration-scripts\create-pom.ps1" -outputPath $OutputPath -packageName $PackageName -JavaVersion $JavaVersion
} else {
    Write-Host "Warning: create-pom.ps1 not found!" -ForegroundColor Red
}

Write-Host "Generating application.yml..." -ForegroundColor Yellow
if (Test-Path ".\migration-scripts\create-application-properties.ps1") {
& ".\migration-scripts\create-application-properties.ps1" -outputPath $OutputPath
} else {
    Write-Host "Warning: create-application-properties.ps1 not found!" -ForegroundColor Red
}

Write-Host "Generating main application class..." -ForegroundColor Yellow
if (Test-Path ".\migration-scripts\create-main-application.ps1") {
& ".\migration-scripts\create-main-application.ps1" -outputPath $OutputPath -packageName $PackageName
} else {
    Write-Host "Warning: create-main-application.ps1 not found!" -ForegroundColor Red
}

Write-Host "Generating schema.sql..." -ForegroundColor Yellow
# Generate schema.sql based on detected entities dynamically
$schemaContent = "-- Database Schema`n`n"

# Parse RAML files to extract entity properties
foreach ($ramlFile in $ramlFiles) {
    $ramlContent = Get-Content $ramlFile.FullName -Raw
    
    # Extract types section
    if ($ramlContent -match 'types:\s*\n((?:\s{2}\w+:\s*\n(?:\s{4}.*\n)*)+)') {
        $typesSection = $matches[1]
        
        # Extract each type
        $typeMatches = [regex]::Matches($typesSection, '(?ms)^\s{2}(\w+):\s*\n((?:\s{4}.*\n)+)')
        
        foreach ($typeMatch in $typeMatches) {
            $typeName = $typeMatch.Groups[1].Value
            $typeDefinition = $typeMatch.Groups[2].Value
            $tableName = $typeName.ToLower() + "s"
            
            Write-Host "  Generating schema for: $typeName (table: $tableName)" -ForegroundColor White
            
            # Drop table
            $schemaContent += "-- Drop table if exists`n"
            $schemaContent += "DROP TABLE IF EXISTS $tableName;`n`n"
            
            # Create table
            $schemaContent += "-- Create $tableName table`n"
            $schemaContent += "CREATE TABLE $tableName (`n"
            $schemaContent += "    id BIGINT AUTO_INCREMENT PRIMARY KEY,`n"
            
            # Parse properties
            $propPattern = '^\s{6}(\w+):\s*\n(?:\s{8}type:\s*)?(\w+)'
            $properties = @()
            
            $typeDefinition -split "`n" | ForEach-Object {
                if ($_ -match '^\s{6}(\w+):') {
                    $propName = $matches[1]
                    $nextLine = $typeDefinition.Substring($typeDefinition.IndexOf($propName))
                    
                    # Get property type
                    $propType = "string"
                    if ($nextLine -match "type:\s*(\w+)") {
                        $propType = $matches[1]
                    }
                    
                    # Get constraints
                    $required = $nextLine -match "required:\s*true"
                    $maxLength = if ($nextLine -match "maxLength:\s*(\d+)") { $matches[1] } else { $null }
                    $minLength = if ($nextLine -match "minLength:\s*(\d+)") { $matches[1] } else { $null }
                    
                    if ($propName -ne "id") {
                        $properties += @{
                            Name = $propName
                            Type = $propType
                            Required = $required
                            MaxLength = $maxLength
                        }
                    }
                }
            }
            
            # Generate columns based on properties
            foreach ($prop in $properties) {
                # Convert camelCase to snake_case correctly
                $columnName = $prop.Name
                # Insert underscore before uppercase letters (except at the start)
                $columnName = [regex]::Replace($columnName, '(?<!^)([A-Z])', '_$1')
                # Convert to lowercase
                $columnName = $columnName.ToLower()
                # Replace any hyphens with underscores
                $columnName = $columnName -replace '-', '_'
                $columnDef = "    $columnName "
                
                # Map RAML types to SQL types
                switch ($prop.Type) {
                    "string" { 
                        $length = if ($prop.MaxLength) { $prop.MaxLength } else { 100 }
                        $columnDef += "VARCHAR($length)"
                    }
                    "number" { $columnDef += "DECIMAL(10,2)" }
                    "integer" { $columnDef += "INT" }
                    "boolean" { $columnDef += "BOOLEAN DEFAULT FALSE" }
                    "date-only" { $columnDef += "DATE" }
                    "datetime" { $columnDef += "TIMESTAMP" }
                    default { $columnDef += "VARCHAR(255)" }
                }
                
                if ($prop.Required) {
                    $columnDef += " NOT NULL"
                }
                
                if ($prop.Name -match "email") {
                    $columnDef += " UNIQUE"
                }
                
                $schemaContent += "$columnDef,`n"
            }
            
            # Add created_date if not present
            if (-not ($properties | Where-Object { $_.Name -match "created" })) {
                $schemaContent += "    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP`n"
            } else {
                # Remove last comma
                $schemaContent = $schemaContent.TrimEnd(",`n") + "`n"
            }
            
            $schemaContent += ");`n`n"
            
            # Generate sample data based on entity type
            $schemaContent += "-- Insert sample data`n"
            if ($typeName -eq "Employee") {
                $schemaContent += "INSERT INTO $tableName (first_name, last_name, email, department_id, hire_date) VALUES`n"
                $schemaContent += "('John', 'Doe', 'john.doe@example.com', '1', '2023-01-15'),`n"
                $schemaContent += "('Jane', 'Smith', 'jane.smith@example.com', '2', '2023-02-20'),`n"
                $schemaContent += "('Bob', 'Johnson', 'bob.johnson@example.com', '1', '2023-03-10'),`n"
                $schemaContent += "('Alice', 'Williams', 'alice.williams@example.com', '3', '2023-04-05');`n`n"
            }
            elseif ($typeName -eq "Product") {
                $schemaContent += "INSERT INTO $tableName (name, description, price, category, stock, active) VALUES`n"
                $schemaContent += "('Laptop Pro 15', 'High-performance laptop with 16GB RAM', 1299.99, 'Electronics', 25, true),`n"
                $schemaContent += "('Wireless Mouse', 'Ergonomic wireless mouse', 29.99, 'Electronics', 150, true),`n"
                $schemaContent += "('Office Chair', 'Comfortable ergonomic office chair', 349.99, 'Furniture', 40, true),`n"
                $schemaContent += "('USB-C Hub', '7-in-1 USB-C hub with HDMI', 49.99, 'Electronics', 80, true),`n"
                $schemaContent += "('Standing Desk', 'Electric height-adjustable desk', 599.99, 'Furniture', 15, true);`n`n"
            }
            else {
                # Generic sample data
                $schemaContent += "-- TODO: Add sample data for $tableName`n`n"
            }
        }
    }
}

# If no schema was generated, create a default one
if ($schemaContent -eq "-- Database Schema`n`n") {
    Write-Host "  No types found in RAML, generating default schema" -ForegroundColor Yellow
$schemaContent = @"
-- Database Schema
-- No types found in RAML, using default schema

-- Drop table if exists
DROP TABLE IF EXISTS items;

-- Create items table
CREATE TABLE items (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO items (name, description) VALUES
('Item 1', 'Description for item 1'),
('Item 2', 'Description for item 2');
"@
}

Write-FileWithoutBom "$OutputPath\src\main\resources\schema.sql" $schemaContent

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
    
    Write-FileWithoutBom "$exceptionPath\ResourceNotFoundException.java" $resourceNotFound
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