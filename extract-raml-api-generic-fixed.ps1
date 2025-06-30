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

Write-Host "`nAPI Details:" -ForegroundColor Green
Write-Host "  Title: $title" -ForegroundColor White
Write-Host "  Version: $version" -ForegroundColor White
Write-Host "  Base URI: $baseUri" -ForegroundColor White

# Extract types and generate models
$modelPath = Join-Path $outputPath "model"
if (-not (Test-Path $modelPath)) {
    New-Item -ItemType Directory -Force -Path $modelPath | Out-Null
}

# Simple type extraction
$typePattern = 'types:\s*\n((?:\s{2}\w+:\s*\n(?:\s{4}.*\n)*)+)'
if ($ramlContent -match $typePattern) {
    $typesSection = $matches[1]
    
    # Extract each type name
    $typeNames = [regex]::Matches($typesSection, '^\s{2}(\w+):', [System.Text.RegularExpressions.RegexOptions]::Multiline) | 
        ForEach-Object { $_.Groups[1].Value }
    
    foreach ($typeName in $typeNames) {
        Write-Host "  Generating model: $typeName" -ForegroundColor White
        
        # Extract the type definition - stop at next type or endpoint
        $typePattern = "(?ms)^\s{2}$typeName\s*:\s*\n((?:\s{4}[^\n]+\n)+?)(?=^\s{0,2}[\w/]|\z)"
        if ($ramlContent -match $typePattern) {
            $typeDefinition = $matches[1]
            
            # Parse properties
            $properties = @()
            $propPattern = '^\s{6}(\w+):\s*(.+)$'
            $foundProps = @{}
            $typeDefinition -split "`n" | ForEach-Object {
                if ($_ -match $propPattern) {
                    $propName = $matches[1]
                    # Only add if not already found (avoid duplicates)
                    if (-not $foundProps.ContainsKey($propName)) {
                        $foundProps[$propName] = $true
                        $properties += @{
                            Name = $propName
                            Type = $matches[2].Trim()
                        }
                    }
                }
            }
            
            # Generate model class with properties
            $modelClass = @"
package $packageName.model;

import com.fasterxml.jackson.annotation.JsonProperty;
import javax.validation.constraints.*;
import java.time.LocalDate;
import java.time.LocalDateTime;

public class $typeName {
"@
            
            # Add properties
            foreach ($prop in $properties) {
                $propName = $prop.Name
                $propType = $prop.Type
                $fieldName = $propName.Substring(0,1).ToLower() + $propName.Substring(1)
                
                # Map RAML types to Java types
                $javaType = switch ($propType) {
                    "string" { "String" }
                    "number" { if ($propName -match "id|Id") { "Long" } else { "Double" } }
                    "integer" { "Integer" }
                    "boolean" { "Boolean" }
                    "date-only" { "LocalDate" }
                    "datetime" { "LocalDateTime" }
                    default { "String" }
                }
                
                # Add annotations for validation
                $annotations = ""
                if ($propType -eq "string" -and $propName -ne "id") {
                    if ($propName -match "email") {
                        $annotations = "`n    @Email(message = `"Email should be valid`")"
                    }
                    if ($propName -match "name|Name") {
                        $annotations = "`n    @NotBlank(message = `"$propName is required`")"
                    }
                }
                
                # Add JsonProperty if field name is different from property name
                if ($fieldName -ne $propName) {
                    $annotations += "`n    @JsonProperty(`"$($propName.ToLower())`")"
                }
                
                $modelClass += @"

    $annotations
    private $javaType $fieldName;
"@
            }
            
            # Add getters and setters
            $modelClass += @"


    // Getters and Setters
"@
            foreach ($prop in $properties) {
                $propName = $prop.Name
                $propType = $prop.Type
                $fieldName = $propName.Substring(0,1).ToLower() + $propName.Substring(1)
                $methodName = $propName.Substring(0,1).ToUpper() + $propName.Substring(1)
                
                $javaType = switch ($propType) {
                    "string" { "String" }
                    "number" { if ($propName -match "id|Id") { "Long" } else { "Double" } }
                    "integer" { "Integer" }
                    "boolean" { "Boolean" }
                    "date-only" { "LocalDate" }
                    "datetime" { "LocalDateTime" }
                    default { "String" }
                }
                
                $modelClass += @"

    
    public $javaType get$methodName() {
        return $fieldName;
    }
    
    public void set$methodName($javaType $fieldName) {
        this.$fieldName = $fieldName;
    }
"@
            }
            
            $modelClass += @"

}
"@
        } else {
            # Fallback to basic model if parsing fails
            $modelClass = @"
package $packageName.model;

import com.fasterxml.jackson.annotation.JsonProperty;
import javax.validation.constraints.*;
import java.time.LocalDate;
import java.time.LocalDateTime;

public class $typeName {
    private Long id;
    
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
}
"@
        }
        
        # Write without BOM
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText("$modelPath\$typeName.java", $modelClass, $utf8NoBom)
    }
}

# Extract and generate controllers for resources
$controllerPath = Join-Path $outputPath "controller"
if (-not (Test-Path $controllerPath)) {
    New-Item -ItemType Directory -Force -Path $controllerPath | Out-Null
}

# Find all resource paths
$resourcePattern = '^(/\w+[^:]*?):\s*$'
$resources = [regex]::Matches($ramlContent, $resourcePattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)

foreach ($resource in $resources) {
    $resourcePath = $resource.Groups[1].Value.Trim()
    
    # Extract resource name for controller
    if ($resourcePath -match '^/([^/]+)') {
        $resourceName = $matches[1]
        $controllerName = $resourceName.Substring(0,1).ToUpper() + $resourceName.Substring(1).TrimEnd('s')
        
        Write-Host "  Generating controller: ${controllerName}Controller" -ForegroundColor White
        
        # Find the corresponding model
        $modelName = $controllerName
        if ($typeNames -notcontains $modelName -and $typeNames -contains ($modelName + "s")) {
            $modelName = $modelName + "s"
        }
        
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
 */
@RestController
@RequestMapping("$resourcePath")
@Validated
public class ${controllerName}Controller {
    
    @Autowired(required = false)
    private ${controllerName}Service ${controllerName.ToLower()}Service;
    
    @GetMapping
    public ResponseEntity<List<$modelName>> getAll() {
        if (${controllerName.ToLower()}Service != null) {
            return ResponseEntity.ok(${controllerName.ToLower()}Service.getAll${controllerName}s());
        }
        return ResponseEntity.ok(List.of());
    }
    
    @GetMapping("/{id}")
    public ResponseEntity<$modelName> getById(@PathVariable Long id) {
        if (${controllerName.ToLower()}Service != null) {
            return ResponseEntity.ok(${controllerName.ToLower()}Service.get${controllerName}ById(id));
        }
        return ResponseEntity.notFound().build();
    }
    
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ResponseEntity<$modelName> create(@Valid @RequestBody $modelName entity) {
        if (${controllerName.ToLower()}Service != null) {
            return ResponseEntity.status(HttpStatus.CREATED)
                .body(${controllerName.ToLower()}Service.create${controllerName}(entity));
        }
        return ResponseEntity.status(HttpStatus.CREATED).body(entity);
    }
    
    @PutMapping("/{id}")
    public ResponseEntity<$modelName> update(@PathVariable Long id, @Valid @RequestBody $modelName entity) {
        if (${controllerName.ToLower()}Service != null) {
            return ResponseEntity.ok(${controllerName.ToLower()}Service.update${controllerName}(id, entity));
        }
        entity.setId(id);
        return ResponseEntity.ok(entity);
    }
    
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        if (${controllerName.ToLower()}Service != null) {
            ${controllerName.ToLower()}Service.delete${controllerName}(id);
        }
        return ResponseEntity.noContent().build();
    }
}
"@
        
        # Write without BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$controllerPath\${controllerName}Controller.java", $controllerClass, $utf8NoBom)
    }
}

# Generate OpenAPI configuration
$configPath = Join-Path $outputPath "config"
if (-not (Test-Path $configPath)) {
    New-Item -ItemType Directory -Force -Path $configPath | Out-Null
}

if (-not (Test-Path "$configPath\OpenApiConfig.java")) {
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
    
    $openApiConfig | Out-File -FilePath "$configPath\OpenApiConfig.java" -Encoding ASCII
}

Write-Host "`n================================================" -ForegroundColor Green
Write-Host "RAML extraction completed!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green 