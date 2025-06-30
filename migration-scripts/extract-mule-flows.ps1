param (
    [string]$muleXmlPath,
    [string]$outputPath
)

# Ensure output directory exists
if (-not (Test-Path $outputPath)) {
    New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
}

# Load the XML file
[xml]$muleDoc = Get-Content $muleXmlPath

# Create model directory if it doesn't exist
$modelPath = Join-Path $outputPath "..\..\model"
if (-not (Test-Path $modelPath)) {
    New-Item -ItemType Directory -Force -Path $modelPath | Out-Null
}

# Create Employee model
$employeeModel = @"
package com.example.employeeapi.model;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.LocalDate;

public class Employee {
    @JsonProperty("id")
    private Long id;

    @JsonProperty("firstName")
    private String firstName;

    @JsonProperty("lastName")
    private String lastName;

    @JsonProperty("email")
    private String email;

    @JsonProperty("departmentId")
    private Long departmentId;

    @JsonProperty("hireDate")
    private LocalDate hireDate;

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
}
"@

# Create ResourceNotFoundException
$exceptionPath = Join-Path $outputPath "..\..\exception"
if (-not (Test-Path $exceptionPath)) {
    New-Item -ItemType Directory -Force -Path $exceptionPath | Out-Null
}

$resourceNotFound = @"
package com.example.employeeapi.exception;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.NOT_FOUND)
public class ResourceNotFoundException extends RuntimeException {
    public ResourceNotFoundException(String message) {
        super(message);
    }
}
"@

$errorResponse = @"
package com.example.employeeapi.exception;

public class ErrorResponse {
    private String code;
    private String message;

    public ErrorResponse(String code, String message) {
        this.code = code;
        this.message = message;
    }

    public String getCode() {
        return code;
    }

    public void setCode(String code) {
        this.code = code;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }
}
"@

$globalExceptionHandler = @"
package com.example.employeeapi.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {
    
    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleResourceNotFoundException(ResourceNotFoundException ex) {
        ErrorResponse error = new ErrorResponse("NOT_FOUND", ex.getMessage());
        return new ResponseEntity<>(error, HttpStatus.NOT_FOUND);
    }
    
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGlobalException(Exception ex) {
        ErrorResponse error = new ErrorResponse("ERROR", "Internal server error");
        return new ResponseEntity<>(error, HttpStatus.INTERNAL_SERVER_ERROR);
    }
}
"@

# Extract flow info and create service class
$employeeService = @"
package com.example.employeeapi.service;

import com.example.employeeapi.exception.ResourceNotFoundException;
import com.example.employeeapi.model.Employee;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Service;

import java.sql.PreparedStatement;
import java.sql.Statement;
import java.util.List;

@Service
public class EmployeeService {
    
    @Autowired
    private JdbcTemplate jdbcTemplate;
    
    public List<Employee> getAllEmployees() {
        // Migrated from get-all-employees-flow
        return jdbcTemplate.query(
            "SELECT * FROM employees",
            (rs, rowNum) -> {
                Employee employee = new Employee();
                employee.setId(rs.getLong("id"));
                employee.setFirstName(rs.getString("first_name"));
                employee.setLastName(rs.getString("last_name"));
                employee.setEmail(rs.getString("email"));
                employee.setDepartmentId(rs.getLong("department_id"));
                employee.setHireDate(rs.getDate("hire_date").toLocalDate());
                return employee;
            }
        );
    }
    
    public Employee getEmployeeById(Long id) {
        // Migrated from get-employee-by-id-flow
        try {
            return jdbcTemplate.queryForObject(
                "SELECT * FROM employees WHERE id = ?",
                new Object[]{id},
                (rs, rowNum) -> {
                    Employee employee = new Employee();
                    employee.setId(rs.getLong("id"));
                    employee.setFirstName(rs.getString("first_name"));
                    employee.setLastName(rs.getString("last_name"));
                    employee.setEmail(rs.getString("email"));
                    employee.setDepartmentId(rs.getLong("department_id"));
                    employee.setHireDate(rs.getDate("hire_date").toLocalDate());
                    return employee;
                }
            );
        } catch (EmptyResultDataAccessException e) {
            throw new ResourceNotFoundException("Employee not found with id: " + id);
        }
    }
    
    public Employee createEmployee(Employee employee) {
        // Migrated from create-employee-flow
        KeyHolder keyHolder = new GeneratedKeyHolder();
        
        jdbcTemplate.update(connection -> {
            PreparedStatement ps = connection.prepareStatement(
                "INSERT INTO employees (first_name, last_name, email, department_id, hire_date) " +
                "VALUES (?, ?, ?, ?, ?)",
                Statement.RETURN_GENERATED_KEYS
            );
            ps.setString(1, employee.getFirstName());
            ps.setString(2, employee.getLastName());
            ps.setString(3, employee.getEmail());
            ps.setLong(4, employee.getDepartmentId());
            ps.setDate(5, java.sql.Date.valueOf(employee.getHireDate()));
            return ps;
        }, keyHolder);
        
        employee.setId(keyHolder.getKey().longValue());
        return employee;
    }
    
    public Employee updateEmployee(Long id, Employee employee) {
        // Migrated from update-employee-flow
        int updated = jdbcTemplate.update(
            "UPDATE employees " +
            "SET first_name = ?, last_name = ?, email = ?, department_id = ? " +
            "WHERE id = ?",
            employee.getFirstName(),
            employee.getLastName(),
            employee.getEmail(),
            employee.getDepartmentId(),
            id
        );
        
        if (updated == 0) {
            throw new ResourceNotFoundException("Employee not found with id: " + id);
        }
        
        employee.setId(id);
        return employee;
    }
    
    public void deleteEmployee(Long id) {
        // Migrated from delete-employee-flow
        int deleted = jdbcTemplate.update("DELETE FROM employees WHERE id = ?", id);
        
        if (deleted == 0) {
            throw new ResourceNotFoundException("Employee not found with id: " + id);
        }
    }
}
"@

# Write files
$employeeModel | Out-File -FilePath "$modelPath\Employee.java" -Encoding utf8
$resourceNotFound | Out-File -FilePath "$exceptionPath\ResourceNotFoundException.java" -Encoding utf8
$errorResponse | Out-File -FilePath "$exceptionPath\ErrorResponse.java" -Encoding utf8
$globalExceptionHandler | Out-File -FilePath "$exceptionPath\GlobalExceptionHandler.java" -Encoding utf8
$employeeService | Out-File -FilePath "$outputPath\EmployeeService.java" -Encoding utf8

Write-Host "Extraction completed. Files generated in the output directories."
