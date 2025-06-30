param (
    [string]$resourcesPath
)

# Ensure resources directory exists
if (-not (Test-Path $resourcesPath)) {
    New-Item -ItemType Directory -Force -Path $resourcesPath | Out-Null
}

# Create application.yml
$applicationYml = @"
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/employee_db
    username: root
    password: password
    driver-class-name: com.mysql.cj.jdbc.Driver
  jpa:
    hibernate:
      ddl-auto: none
    show-sql: true

server:
  port: 8080
"@

# Create schema.sql for database initialization
$schemaSql = @"
CREATE TABLE IF NOT EXISTS employees (
  id INT AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(50) NOT NULL,
  last_name VARCHAR(50) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  department_id INT,
  hire_date DATE
);
"@

# Write files
$applicationYml | Out-File -FilePath "$resourcesPath\application.yml" -Encoding utf8
$schemaSql | Out-File -FilePath "$resourcesPath\schema.sql" -Encoding utf8

Write-Host "Application properties created at: $resourcesPath"
