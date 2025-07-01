param (
    [string]$outputPath,
    [string]$resourcesPath
)

# Use outputPath to construct resourcesPath if not provided
if (-not $resourcesPath -and $outputPath) {
    $resourcesPath = "$outputPath\src\main\resources"
}

# Ensure resources directory exists
if (-not (Test-Path $resourcesPath)) {
    New-Item -ItemType Directory -Force -Path $resourcesPath | Out-Null
}

# Create application.yml
$applicationYml = @"
spring:
  datasource:
    url: jdbc:h2:mem:testdb
    driver-class-name: org.h2.Driver
    username: sa
    password: 
  h2:
    console:
      enabled: true
      path: /h2-console
  jpa:
    database-platform: org.hibernate.dialect.H2Dialect
    hibernate:
      ddl-auto: none
    show-sql: true
  sql:
    init:
      mode: always

server:
  port: 8080

springdoc:
  api-docs:
    path: /api-docs
  swagger-ui:
    path: /swagger-ui.html
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

# Write files without BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$resourcesPath\application.yml", $applicationYml, $utf8NoBom)
[System.IO.File]::WriteAllText("$resourcesPath\schema.sql", $schemaSql, $utf8NoBom)

Write-Host "Application properties created at: $resourcesPath"
