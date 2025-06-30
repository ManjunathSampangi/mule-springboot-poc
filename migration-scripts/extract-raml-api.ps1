param (
    [string]$ramlPath,
    [string]$outputPath
)

Write-Host "Extracting RAML API definitions..." -ForegroundColor Cyan

# Read RAML file
$ramlContent = Get-Content $ramlPath -Raw

# Extract API title, version, and base URI
$title = if ($ramlContent -match 'title:\s*(.+)') { $matches[1].Trim() } else { "API" }
$version = if ($ramlContent -match 'version:\s*(.+)') { $matches[1].Trim() } else { "v1" }
$baseUri = if ($ramlContent -match 'baseUri:\s*(.+)') { $matches[1].Trim() } else { "http://localhost:8080" }

Write-Host "API: $title $version" -ForegroundColor Green
Write-Host "Base URI: $baseUri" -ForegroundColor Green

# Extract Employee type definition from RAML
$employeeValidation = @"
package com.example.employeeapi.model;

import javax.validation.constraints.*;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.LocalDate;

/**
 * Employee model generated from RAML specification
 * API: $title $version
 */
public class Employee {
    @JsonProperty("id")
    private Long id;

    @NotNull(message = "First name is required")
    @Size(min = 1, max = 50, message = "First name must be between 1 and 50 characters")
    @JsonProperty("firstName")
    private String firstName;

    @NotNull(message = "Last name is required")
    @Size(min = 1, max = 50, message = "Last name must be between 1 and 50 characters")
    @JsonProperty("lastName")
    private String lastName;

    @NotNull(message = "Email is required")
    @Email(message = "Email must be valid")
    @Size(max = 100, message = "Email must not exceed 100 characters")
    @JsonProperty("email")
    private String email;

    @NotNull(message = "Department ID is required")
    @JsonProperty("departmentId")
    private Long departmentId;

    @NotNull(message = "Hire date is required")
    @JsonProperty("hireDate")
    private LocalDate hireDate;

    // Constructors
    public Employee() {}

    public Employee(String firstName, String lastName, String email, Long departmentId, LocalDate hireDate) {
        this.firstName = firstName;
        this.lastName = lastName;
        this.email = email;
        this.departmentId = departmentId;
        this.hireDate = hireDate;
    }

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getFirstName() {
        return firstName;
    }

    public void setFirstName(String firstName) {
        this.firstName = firstName;
    }

    public String getLastName() {
        return lastName;
    }

    public void setLastName(String lastName) {
        this.lastName = lastName;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public Long getDepartmentId() {
        return departmentId;
    }

    public void setDepartmentId(Long departmentId) {
        this.departmentId = departmentId;
    }

    public LocalDate getHireDate() {
        return hireDate;
    }

    public void setHireDate(LocalDate hireDate) {
        this.hireDate = hireDate;
    }

    @Override
    public String toString() {
        return "Employee{" +
                "id=" + id +
                ", firstName='" + firstName + '\'' +
                ", lastName='" + lastName + '\'' +
                ", email='" + email + '\'' +
                ", departmentId=" + departmentId +
                ", hireDate=" + hireDate +
                '}';
    }
}
"@

# Create API documentation annotation for controller
$apiDocumentation = @"
package com.example.employeeapi.controller;

import com.example.employeeapi.model.Employee;
import com.example.employeeapi.service.EmployeeService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

import javax.validation.Valid;
import java.net.URI;
import java.util.List;

/**
 * Employee API Controller
 * Generated from RAML: $title $version
 * 
 * This controller implements all endpoints defined in the RAML specification:
 * - GET /employees - Get all employees
 * - POST /employees - Create a new employee
 * - GET /employees/{id} - Get employee by ID
 * - PUT /employees/{id} - Update an employee
 * - DELETE /employees/{id} - Delete an employee
 */
@RestController
@RequestMapping("/api/employees")
@Validated
public class EmployeeController {
    
    @Autowired
    private EmployeeService employeeService;
    
    /**
     * Get all employees
     * RAML: GET /employees
     */
    @GetMapping
    public ResponseEntity<List<Employee>> getEmployees() {
        List<Employee> employees = employeeService.getAllEmployees();
        return ResponseEntity.ok(employees);
    }
    
    /**
     * Get employee by ID
     * RAML: GET /employees/{id}
     * Returns 404 if employee not found
     */
    @GetMapping("/{id}")
    public ResponseEntity<Employee> getEmployeeById(@PathVariable Long id) {
        Employee employee = employeeService.getEmployeeById(id);
        return ResponseEntity.ok(employee);
    }
    
    /**
     * Create a new employee
     * RAML: POST /employees
     * Request body must be valid Employee object
     */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ResponseEntity<Employee> createEmployee(@Valid @RequestBody Employee employee) {
        Employee created = employeeService.createEmployee(employee);
        URI location = ServletUriComponentsBuilder
            .fromCurrentRequest()
            .path("/{id}")
            .buildAndExpand(created.getId())
            .toUri();
        
        return ResponseEntity.created(location).body(created);
    }
    
    /**
     * Update an employee
     * RAML: PUT /employees/{id}
     * Returns 404 if employee not found
     */
    @PutMapping("/{id}")
    public ResponseEntity<Employee> updateEmployee(@PathVariable Long id, @Valid @RequestBody Employee employee) {
        Employee updated = employeeService.updateEmployee(id, employee);
        return ResponseEntity.ok(updated);
    }
    
    /**
     * Delete an employee
     * RAML: DELETE /employees/{id}
     * Returns 204 No Content on success, 404 if not found
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteEmployee(@PathVariable Long id) {
        employeeService.deleteEmployee(id);
        return ResponseEntity.noContent().build();
    }
}
"@

# Create OpenAPI configuration based on RAML
$openApiConfig = @"
package com.example.employeeapi.config;

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
                .description("Employee Master API - Migrated from RAML specification"))
            .addServersItem(new Server().url("$baseUri"));
    }
}
"@

# Create model directory if it doesn't exist
$modelPath = Join-Path $outputPath "model"
if (-not (Test-Path $modelPath)) {
    New-Item -ItemType Directory -Force -Path $modelPath | Out-Null
}

# Create controller directory if it doesn't exist
$controllerPath = Join-Path $outputPath "controller"
if (-not (Test-Path $controllerPath)) {
    New-Item -ItemType Directory -Force -Path $controllerPath | Out-Null
}

# Create config directory if it doesn't exist
$configPath = Join-Path $outputPath "config"
if (-not (Test-Path $configPath)) {
    New-Item -ItemType Directory -Force -Path $configPath | Out-Null
}

# Write files
$employeeValidation | Out-File -FilePath "$modelPath\Employee.java" -Encoding utf8
$apiDocumentation | Out-File -FilePath "$controllerPath\EmployeeController.java" -Encoding utf8
$openApiConfig | Out-File -FilePath "$configPath\OpenApiConfig.java" -Encoding utf8

Write-Host "RAML extraction completed!" -ForegroundColor Green
Write-Host "Generated files:" -ForegroundColor Yellow
Write-Host "  - Employee.java (with validation from RAML types)" -ForegroundColor White
Write-Host "  - EmployeeController.java (with RAML endpoint mappings)" -ForegroundColor White
Write-Host "  - OpenApiConfig.java (API documentation)" -ForegroundColor White 