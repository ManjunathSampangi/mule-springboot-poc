param (
    [string]$ramlPath,
    [string]$outputPath,
    [string]$packageName = "com.example.api"
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Generic RAML to Spring Boot Converter" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Read RAML file
$ramlContent = Get-Content $ramlPath -Raw
Write-Host "Processing RAML file: $ramlPath" -ForegroundColor Yellow

# Extract API metadata
$title = if ($ramlContent -match 'title:\s*(.+)') { $matches[1].Trim() } else { "API" }
$version = if ($ramlContent -match 'version:\s*(.+)') { $matches[1].Trim() } else { "v1" }
$baseUri = if ($ramlContent -match 'baseUri:\s*(.+)') { $matches[1].Trim() } else { "http://localhost:8080" }
$mediaType = if ($ramlContent -match 'mediaType:\s*(.+)') { $matches[1].Trim() } else { "application/json" }

Write-Host "`nAPI Details:" -ForegroundColor Green
Write-Host "  Title: $title" -ForegroundColor White
Write-Host "  Version: $version" -ForegroundColor White
Write-Host "  Base URI: $baseUri" -ForegroundColor White
Write-Host "  Media Type: $mediaType" -ForegroundColor White

# Function to convert RAML type to Java type
function Convert-RamlToJavaType {
    param([string]$ramlType)
    
    switch -regex ($ramlType) {
        'string' { return 'String' }
        'number' { return 'Long' }
        'integer' { return 'Integer' }
        'boolean' { return 'Boolean' }
        'date-only' { return 'LocalDate' }
        'datetime' { return 'LocalDateTime' }
        'array' { return 'List' }
        default { return 'Object' }
    }
}

# Function to generate validation annotations
function Get-ValidationAnnotations {
    param([string]$propertyName, [string]$ramlType, [hashtable]$constraints)
    
    $annotations = @()
    
    if ($propertyName -match 'email') {
        $annotations += "    @Email(message = `"Invalid email format`")"
    }
    
    if ($constraints.required -eq $true) {
        $annotations += "    @NotNull(message = `"$propertyName is required`")"
    }
    
    if ($constraints.minLength -or $constraints.maxLength) {
        $min = if ($constraints.minLength) { $constraints.minLength } else { 0 }
        $max = if ($constraints.maxLength) { $constraints.maxLength } else { 255 }
        $annotations += "    @Size(min = $min, max = $max, message = `"$propertyName must be between $min and $max characters`")"
    }
    
    return $annotations -join "`n"
}

# Extract all types defined in RAML
$types = @{}
if ($ramlContent -match 'types:\s*\n((?:\s{2,}.*\n)+)') {
    $typesSection = $matches[1]
    
    # Parse each type
    $typePattern = '^\s{2}(\w+):\s*\n((?:\s{4,}.*\n)*)'
    $typeMatches = [regex]::Matches($typesSection, $typePattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    
    foreach ($match in $typeMatches) {
        $typeName = $match.Groups[1].Value
        $typeDefinition = $match.Groups[2].Value
        
        Write-Host "`nFound type: $typeName" -ForegroundColor Green
        
        # Parse properties
        $properties = @{}
        $propertyPattern = '^\s{4}(\w+):\s*(.+?)(?:\n|$)'
        $propMatches = [regex]::Matches($typeDefinition, $propertyPattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
        
        foreach ($propMatch in $propMatches) {
            $propName = $propMatch.Groups[1].Value
            $propType = $propMatch.Groups[2].Value.Trim()
            $properties[$propName] = $propType
        }
        
        $types[$typeName] = $properties
    }
}

# Generate model classes for each type
$modelPath = Join-Path $outputPath "model"
if (-not (Test-Path $modelPath)) {
    New-Item -ItemType Directory -Force -Path $modelPath | Out-Null
}

foreach ($typeName in $types.Keys) {
    $properties = $types[$typeName]
    $className = $typeName
    
    $modelClass = @"
package $packageName.model;

import javax.validation.constraints.*;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

/**
 * $className model generated from RAML specification
 * API: $title $version
 */
public class $className {
"@

    # Add properties
    foreach ($propName in $properties.Keys) {
        $propType = $properties[$propName]
        $javaType = Convert-RamlToJavaType $propType
        $fieldName = $propName.Substring(0,1).ToLower() + $propName.Substring(1)
        
        # Add validation annotations
        if ($propType -match 'required|email|minLength|maxLength') {
            $modelClass += "`n    // Validation annotations based on RAML constraints"
        }
        
        $modelClass += @"

    @JsonProperty("$propName")
    private $javaType $fieldName;
"@
    }

    # Add constructors
    $modelClass += @"

    
    // Constructors
    public $className() {}

"@

    # Add getters and setters
    foreach ($propName in $properties.Keys) {
        $propType = $properties[$propName]
        $javaType = Convert-RamlToJavaType $propType
        $fieldName = $propName.Substring(0,1).ToLower() + $propName.Substring(1)
        $methodName = $propName.Substring(0,1).ToUpper() + $propName.Substring(1)
        
        $modelClass += @"
    public $javaType get$methodName() {
        return $fieldName;
    }

    public void set$methodName($javaType $fieldName) {
        this.$fieldName = $fieldName;
    }

"@
    }

    $modelClass += "}"
    
    # Write model file
    $modelClass | Out-File -FilePath "$modelPath\$className.java" -Encoding utf8
    Write-Host "  Generated model: $className.java" -ForegroundColor White
}

# Extract and generate controllers for each resource
$resources = @{}
$resourcePattern = '^(/[^:]+):\s*\n((?:\s{2,}.*\n)*)'
$resourceMatches = [regex]::Matches($ramlContent, $resourcePattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)

foreach ($match in $resourceMatches) {
    $resourcePath = $match.Groups[1].Value
    $resourceDefinition = $match.Groups[2].Value
    
    # Extract methods for this resource
    $methods = @()
    $methodPattern = '^\s{2}(get|post|put|delete|patch):\s*\n((?:\s{4,}.*\n)*)'
    $methodMatches = [regex]::Matches($resourceDefinition, $methodPattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    
    foreach ($methodMatch in $methodMatches) {
        $httpMethod = $methodMatch.Groups[1].Value.ToUpper()
        $methodDef = $methodMatch.Groups[2].Value
        
        # Extract description
        $description = ""
        if ($methodDef -match 'description:\s*(.+)') {
            $description = $matches[1].Trim()
        }
        
        $methods += @{
            Method = $httpMethod
            Description = $description
        }
    }
    
    if ($methods.Count -gt 0) {
        $resources[$resourcePath] = $methods
    }
}

# Generate controller based on resources
$controllerPath = Join-Path $outputPath "controller"
if (-not (Test-Path $controllerPath)) {
    New-Item -ItemType Directory -Force -Path $controllerPath | Out-Null
}

# Group resources by base path to create controllers
$controllers = @{}
foreach ($resourcePath in $resources.Keys) {
    # Extract base resource name (e.g., /employees -> Employee)
    if ($resourcePath -match '^/([^/]+)') {
        $resourceName = $matches[1]
        $controllerName = $resourceName.Substring(0,1).ToUpper() + $resourceName.Substring(1).TrimEnd('s')
        
        if (-not $controllers.ContainsKey($controllerName)) {
            $controllers[$controllerName] = @()
        }
        
        $controllers[$controllerName] += @{
            Path = $resourcePath
            Methods = $resources[$resourcePath]
        }
    }
}

# Generate controller classes
foreach ($controllerName in $controllers.Keys) {
    $controllerClass = @"
package $packageName.controller;

import $packageName.model.*;
import $packageName.service.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;
import java.util.List;

/**
 * $controllerName Controller
 * Generated from RAML: $title $version
 * Auto-generated controller for resource operations
 */
@RestController
@RequestMapping("$($resourcePath -replace '\{[^}]+\}', '')")
@Validated
public class ${controllerName}Controller {
    
    @Autowired(required = false)
    private ${controllerName}Service ${controllerName.ToLower()}Service;
    
"@

    # Add methods for each endpoint
    foreach ($resource in $controllers[$controllerName]) {
        foreach ($method in $resource.Methods) {
            $httpMethod = $method.Method
            $description = $method.Description
            $path = $resource.Path
            
            # Generate method based on HTTP verb
            switch ($httpMethod) {
                'GET' {
                    if ($path -match '\{[^}]+\}') {
                        # Get by ID
                        $controllerClass += @"
    /**
     * $description
     * RAML: GET $path
     */
    @GetMapping("/{id}")
    public ResponseEntity<?> getById(@PathVariable Long id) {
        // TODO: Implement service call
        return ResponseEntity.ok("GET $path - Not implemented");
    }
    
"@
                    } else {
                        # Get all
                        $controllerClass += @"
    /**
     * $description
     * RAML: GET $path
     */
    @GetMapping
    public ResponseEntity<List<?>> getAll() {
        // TODO: Implement service call
        return ResponseEntity.ok(List.of());
    }
    
"@
                    }
                }
                'POST' {
                    $controllerClass += @"
    /**
     * $description
     * RAML: POST $path
     */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ResponseEntity<?> create(@Valid @RequestBody Object request) {
        // TODO: Implement service call
        return ResponseEntity.status(HttpStatus.CREATED).body("POST $path - Not implemented");
    }
    
"@
                }
                'PUT' {
                    $controllerClass += @"
    /**
     * $description
     * RAML: PUT $path
     */
    @PutMapping("/{id}")
    public ResponseEntity<?> update(@PathVariable Long id, @Valid @RequestBody Object request) {
        // TODO: Implement service call
        return ResponseEntity.ok("PUT $path - Not implemented");
    }
    
"@
                }
                'DELETE' {
                    $controllerClass += @"
    /**
     * $description
     * RAML: DELETE $path
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        // TODO: Implement service call
        return ResponseEntity.noContent().build();
    }
    
"@
                }
            }
        }
    }
    
    $controllerClass += "}"
    
    # Write controller file
    $controllerClass | Out-File -FilePath "$controllerPath\${controllerName}Controller.java" -Encoding utf8
    Write-Host "  Generated controller: ${controllerName}Controller.java" -ForegroundColor White
}

# Generate OpenAPI configuration
$configPath = Join-Path $outputPath "config"
if (-not (Test-Path $configPath)) {
    New-Item -ItemType Directory -Force -Path $configPath | Out-Null
}

$openApiConfig = @"
package $packageName.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * OpenAPI configuration generated from RAML
 */
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

$openApiConfig | Out-File -FilePath "$configPath\OpenApiConfig.java" -Encoding utf8

Write-Host "`n================================================" -ForegroundColor Green
Write-Host "RAML extraction completed!" -ForegroundColor Green
Write-Host "Generated files:" -ForegroundColor Yellow
Write-Host "  - Model classes: $($types.Count) files" -ForegroundColor White
Write-Host "  - Controller classes: $($controllers.Count) files" -ForegroundColor White
Write-Host "  - OpenAPI configuration" -ForegroundColor White
Write-Host "================================================" -ForegroundColor Green 