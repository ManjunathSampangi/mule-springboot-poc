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

# Define namespaces
$namespaces = @{
    mule = "http://www.mulesoft.org/schema/mule/core"
    http = "http://www.mulesoft.org/schema/mule/http"
    db = "http://www.mulesoft.org/schema/mule/db"
    ee = "http://www.mulesoft.org/schema/mule/ee/core"
}

# Extract all flows
$flows = $muleDoc.SelectNodes("//mule:flow", $namespaces)
Write-Host "`nFound $($flows.Count) flows" -ForegroundColor Green

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
    
    # Extract entity name from flow name (e.g., get-all-employees-flow -> Employee)
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
    $httpListener = $flow.SelectSingleNode(".//http:listener", $namespaces)
    if ($httpListener) {
        $path = $httpListener.GetAttribute("path")
        $method = $httpListener.GetAttribute("allowedMethods")
        if (-not $method) { $method = "GET" }
    }
    
    # Extract database operations
    $dbOperations = $flow.SelectNodes(".//db:*", $namespaces)
    foreach ($dbOp in $dbOperations) {
        $operationType = $dbOp.LocalName
        $sql = $dbOp.SelectSingleNode(".//db:sql", $namespaces)
        
        if ($sql) {
            $sqlText = $sql.InnerText.Trim()
            
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
import java.util.Map;

/**
 * ${entityName}Service - Generated from Mule flows
 * Table: $tableName
 */
@Service
public class ${entityName}Service {
    
    @Autowired
    private JdbcTemplate jdbcTemplate;
    
    // Row mapper for $entityName
    private final RowMapper<$entityName> ${entityName.ToLower()}RowMapper = new RowMapper<$entityName>() {
        @Override
        public $entityName mapRow(ResultSet rs, int rowNum) throws SQLException {
            $entityName entity = new $entityName();
            // TODO: Map columns based on actual table structure
            // Auto-detected columns from SQL queries:
"@

    # Analyze SQL to detect columns
    $detectedColumns = @{}
    foreach ($op in $service.Operations) {
        if ($op.SQL -match 'SELECT\s+\*|SELECT\s+([^FROM]+)\s+FROM') {
            # For now, add generic mapping
            $detectedColumns["id"] = "Long"
        }
        
        # Detect columns from INSERT statements
        if ($op.SQL -match 'INSERT\s+INTO\s+\w+\s*\(([^)]+)\)') {
            $columns = $matches[1] -split ','
            foreach ($col in $columns) {
                $colName = $col.Trim()
                $detectedColumns[$colName] = "String"
            }
        }
    }
    
    # Add column mappings
    foreach ($col in $detectedColumns.Keys) {
        $fieldName = $col -replace '_(\w)', { $_.Groups[1].Value.ToUpper() }
        $methodName = $fieldName.Substring(0,1).ToUpper() + $fieldName.Substring(1)
        $serviceClass += @"
            if (hasColumn(rs, "$col")) {
                entity.set$methodName(rs.getString("$col"));
            }
"@
    }
    
    $serviceClass += @"
            return entity;
        }
        
        private boolean hasColumn(ResultSet rs, String columnName) {
            try {
                rs.findColumn(columnName);
                return true;
            } catch (SQLException e) {
                return false;
            }
        }
    };
    
"@

    # Generate methods based on operations
    foreach ($op in $service.Operations) {
        $operationType = $op.Type
        
        switch ($operationType) {
            "select" {
                if ($op.SQL -match 'WHERE\s+\w+\s*=\s*:?\w+') {
                    # Get by ID
                    $serviceClass += @"
    /**
     * Get $entityName by ID
     * Generated from flow: $($op.FlowName)
     */
    public $entityName get${entityName}ById(Long id) {
        try {
            String sql = "$($op.SQL -replace ':\w+', '?')";
            return jdbcTemplate.queryForObject(sql, new Object[]{id}, ${entityName.ToLower()}RowMapper);
        } catch (EmptyResultDataAccessException e) {
            throw new ResourceNotFoundException("$entityName not found with id: " + id);
        }
    }
    
"@
                } else {
                    # Get all
                    $serviceClass += @"
    /**
     * Get all ${entityName}s
     * Generated from flow: $($op.FlowName)
     */
    public List<$entityName> getAll${entityName}s() {
        String sql = "$($op.SQL)";
        return jdbcTemplate.query(sql, ${entityName.ToLower()}RowMapper);
    }
    
"@
                }
            }
            "insert" {
                $serviceClass += @"
    /**
     * Create new $entityName
     * Generated from flow: $($op.FlowName)
     */
    public $entityName create$entityName($entityName entity) {
        KeyHolder keyHolder = new GeneratedKeyHolder();
        
        String sql = "$($op.SQL -replace ':\w+', '?')";
        
        jdbcTemplate.update(connection -> {
            PreparedStatement ps = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
            // TODO: Set parameters based on entity properties
            int paramIndex = 1;
            // Auto-generated parameter setting - adjust based on actual entity
            return ps;
        }, keyHolder);
        
        if (keyHolder.getKey() != null) {
            entity.setId(keyHolder.getKey().longValue());
        }
        return entity;
    }
    
"@
            }
            "update" {
                $serviceClass += @"
    /**
     * Update existing $entityName
     * Generated from flow: $($op.FlowName)
     */
    public $entityName update$entityName(Long id, $entityName entity) {
        String sql = "$($op.SQL -replace ':\w+', '?')";
        
        int updated = jdbcTemplate.update(sql /* TODO: Add parameters */);
        
        if (updated == 0) {
            throw new ResourceNotFoundException("$entityName not found with id: " + id);
        }
        
        entity.setId(id);
        return entity;
    }
    
"@
            }
            "delete" {
                $serviceClass += @"
    /**
     * Delete $entityName
     * Generated from flow: $($op.FlowName)
     */
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
    
    $serviceClass += "}"
    
    # Write service file
    $serviceClass | Out-File -FilePath "$servicePath\${entityName}Service.java" -Encoding utf8
    Write-Host "  Generated service: ${entityName}Service.java" -ForegroundColor White
}

# Generate generic exception classes
$exceptionPath = Join-Path $outputPath "exception"
if (-not (Test-Path $exceptionPath)) {
    New-Item -ItemType Directory -Force -Path $exceptionPath | Out-Null
}

# ResourceNotFoundException
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

# ErrorResponse
$errorResponse = @"
package $packageName.exception;

import java.time.LocalDateTime;

public class ErrorResponse {
    private String code;
    private String message;
    private LocalDateTime timestamp;
    private String path;

    public ErrorResponse(String code, String message) {
        this.code = code;
        this.message = message;
        this.timestamp = LocalDateTime.now();
    }

    // Getters and setters
    public String getCode() { return code; }
    public void setCode(String code) { this.code = code; }
    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }
    public LocalDateTime getTimestamp() { return timestamp; }
    public void setTimestamp(LocalDateTime timestamp) { this.timestamp = timestamp; }
    public String getPath() { return path; }
    public void setPath(String path) { this.path = path; }
}
"@

# GlobalExceptionHandler
$globalExceptionHandler = @"
package $packageName.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;

@RestControllerAdvice
public class GlobalExceptionHandler {
    
    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleResourceNotFoundException(
            ResourceNotFoundException ex, WebRequest request) {
        ErrorResponse error = new ErrorResponse("NOT_FOUND", ex.getMessage());
        error.setPath(request.getDescription(false));
        return new ResponseEntity<>(error, HttpStatus.NOT_FOUND);
    }
    
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGlobalException(
            Exception ex, WebRequest request) {
        ErrorResponse error = new ErrorResponse("INTERNAL_ERROR", "An unexpected error occurred");
        error.setPath(request.getDescription(false));
        return new ResponseEntity<>(error, HttpStatus.INTERNAL_SERVER_ERROR);
    }
}
"@

# Write exception files
$resourceNotFound | Out-File -FilePath "$exceptionPath\ResourceNotFoundException.java" -Encoding utf8
$errorResponse | Out-File -FilePath "$exceptionPath\ErrorResponse.java" -Encoding utf8
$globalExceptionHandler | Out-File -FilePath "$exceptionPath\GlobalExceptionHandler.java" -Encoding utf8

Write-Host "`n================================================" -ForegroundColor Green
Write-Host "Mule flow extraction completed!" -ForegroundColor Green
Write-Host "Generated:" -ForegroundColor Yellow
Write-Host "  - Service classes: $($services.Count)" -ForegroundColor White
Write-Host "  - Exception handling framework" -ForegroundColor White
Write-Host "================================================" -ForegroundColor Green 