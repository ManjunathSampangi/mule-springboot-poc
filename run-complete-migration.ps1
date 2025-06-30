# Mule to Spring Boot Migration Script
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Starting Mule to Spring Boot Migration Process" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Set base directory
$baseDir = Get-Location
Write-Host "`n[1/9] Base directory: $baseDir" -ForegroundColor Green

# Clean previous migration
Write-Host "`n[2/9] Cleaning previous migration..." -ForegroundColor Yellow
if (Test-Path "spring-target") {
    Remove-Item -Path "spring-target" -Recurse -Force
    Write-Host "Removed existing spring-target directory" -ForegroundColor Green
}

# Create directory structure
Write-Host "`n[3/9] Creating directory structure..." -ForegroundColor Yellow
$directories = @(
    "spring-target\src\main\java\com\example\employeeapi\controller",
    "spring-target\src\main\java\com\example\employeeapi\service", 
    "spring-target\src\main\java\com\example\employeeapi\model",
    "spring-target\src\main\java\com\example\employeeapi\exception",
    "spring-target\src\main\resources"
)

foreach ($dir in $directories) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}
Write-Host "Directory structure created" -ForegroundColor Green

# Run migration scripts
Write-Host "`n[4/9] Extracting RAML API definitions..." -ForegroundColor Yellow
& "$baseDir\migration-scripts\extract-raml-api.ps1" `
    -ramlPath "$baseDir\mule-source\src\main\resources\api\employee-api.raml" `
    -outputPath "$baseDir\spring-target\src\main\java\com\example\employeeapi"

Write-Host "`n[5/9] Extracting Mule flows and generating services..." -ForegroundColor Yellow
& "$baseDir\migration-scripts\extract-mule-flows.ps1" `
    -muleXmlPath "$baseDir\mule-source\src\main\app\employee-flows.xml" `
    -outputPath "$baseDir\spring-target\src\main\java\com\example\employeeapi\service"

Write-Host "`n[6/9] Merging RAML and Flow definitions..." -ForegroundColor Yellow
Write-Host "Controller already generated from RAML with proper annotations" -ForegroundColor Green

Write-Host "`n[7/9] Creating Maven POM file..." -ForegroundColor Yellow
& "$baseDir\migration-scripts\create-pom.ps1" `
    -projectPath "$baseDir\spring-target"

Write-Host "`n[8/9] Creating application configuration..." -ForegroundColor Yellow
& "$baseDir\migration-scripts\create-application-properties.ps1" `
    -resourcesPath "$baseDir\spring-target\src\main\resources"

Write-Host "`n[9/9] Creating main Spring Boot application class..." -ForegroundColor Yellow
& "$baseDir\migration-scripts\create-main-application.ps1" `
    -mainPackagePath "$baseDir\spring-target\src\main\java\com\example\employeeapi"

# Create schema.sql file
Write-Host "`nCreating database schema..." -ForegroundColor Yellow
$schemaContent = @"
CREATE TABLE IF NOT EXISTS employees (
  id INT AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(50) NOT NULL,
  last_name VARCHAR(50) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  department_id INT,
  hire_date DATE
);

INSERT INTO employees (first_name, last_name, email, department_id, hire_date) VALUES
('John', 'Doe', 'john.doe@example.com', 1, '2023-01-15'),
('Jane', 'Smith', 'jane.smith@example.com', 2, '2023-02-20'),
('Bob', 'Johnson', 'bob.johnson@example.com', 1, '2023-03-10');
"@
$schemaContent | Out-File -FilePath "$baseDir\spring-target\src\main\resources\schema.sql" -Encoding utf8

Write-Host "`n================================================" -ForegroundColor Green
Write-Host "Migration Complete!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host "`nGenerated Spring Boot application structure:" -ForegroundColor Cyan
Write-Host "  spring-target/" -ForegroundColor White
Write-Host "  ├── pom.xml" -ForegroundColor White
Write-Host "  └── src/main/java/com/example/employeeapi/" -ForegroundColor White
Write-Host "      ├── EmployeeApiApplication.java" -ForegroundColor White
Write-Host "      ├── controller/" -ForegroundColor White
Write-Host "      │   └── EmployeeController.java" -ForegroundColor White
Write-Host "      ├── service/" -ForegroundColor White
Write-Host "      │   └── EmployeeService.java" -ForegroundColor White
Write-Host "      ├── model/" -ForegroundColor White
Write-Host "      │   └── Employee.java" -ForegroundColor White
Write-Host "      └── exception/" -ForegroundColor White
Write-Host "          ├── ResourceNotFoundException.java" -ForegroundColor White
Write-Host "          ├── ErrorResponse.java" -ForegroundColor White
Write-Host "          └── GlobalExceptionHandler.java" -ForegroundColor White

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. cd spring-target" -ForegroundColor White
Write-Host "2. mvn clean package" -ForegroundColor White
Write-Host "3. mvn spring-boot:run" -ForegroundColor White
Write-Host "`nThe application will be available at:" -ForegroundColor Cyan
Write-Host "  - API: http://localhost:8080/api/employees" -ForegroundColor White
Write-Host "  - H2 Console: http://localhost:8080/h2-console" -ForegroundColor White 