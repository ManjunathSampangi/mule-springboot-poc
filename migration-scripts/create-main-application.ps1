param (
    [string]$mainPackagePath
)

# Ensure directory exists
if (-not (Test-Path $mainPackagePath)) {
    New-Item -ItemType Directory -Force -Path $mainPackagePath | Out-Null
}

# Create main application class
$applicationClass = @"
package com.example.employeeapi;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class EmployeeApiApplication {
    public static void main(String[] args) {
        SpringApplication.run(EmployeeApiApplication.class, args);
    }
}
"@

# Write application file
$applicationClass | Out-File -FilePath "$mainPackagePath\EmployeeApiApplication.java" -Encoding utf8

Write-Host "Main application class created at: $mainPackagePath\EmployeeApiApplication.java"
