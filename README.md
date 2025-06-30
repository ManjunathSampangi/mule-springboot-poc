# Mule to Spring Boot Migration Tools

This repository contains automated migration tools to convert Mule ESB projects to Spring Boot applications.

## Directory Structure

```
employee-migration-demo/
├── migration-scripts/          # Core migration scripts
│   ├── create-pom.ps1
│   ├── create-application-properties.ps1
│   ├── create-main-application.ps1
│   ├── extract-mule-flows.ps1
│   ├── extract-mule-flows-generic.ps1
│   ├── extract-raml-api.ps1
│   ├── extract-raml-api-generic.ps1
│   └── implement-controller.ps1
├── mule-source/               # Example Mule project (Employee API)
├── extract-mule-flows-generic-fixed.ps1
├── extract-raml-api-generic-fixed.ps1
├── run-complete-migration.ps1
├── run-generic-migration-smart.ps1
├── Migration-Report.md        # Detailed migration documentation
└── MIGRATION-SUMMARY.md       # Summary of migration results

## Key Scripts

### Main Migration Script
- **run-generic-migration-smart.ps1** - The latest and most advanced generic migration tool that can convert any Mule project to Spring Boot

### Usage
```powershell
.\run-generic-migration-smart.ps1 -MuleProjectPath ".\mule-source" -OutputPath "spring-output" -PackageName "com.company.api" -JavaVersion "17"
```

### Parameters
- `MuleProjectPath` - Path to your Mule project
- `OutputPath` - Where to generate the Spring Boot project (default: "spring-output")
- `PackageName` - Java package name for generated code (default: "com.example.api")
- `JavaVersion` - Java version to target (default: "11", supports "17")

## Features

- Automatic RAML to Spring REST Controller conversion
- Mule flows to Spring Service layer mapping
- Database operations conversion (Mule DB connector to JdbcTemplate)
- Dynamic model generation from RAML types
- H2 in-memory database setup with sample data
- Swagger UI integration
- Bean validation support
- Proper error handling

## Example Migration

```powershell
# Migrate the included employee demo
.\run-generic-migration-smart.ps1 -MuleProjectPath ".\mule-source" -OutputPath "employee-spring" -PackageName "com.company.employee" -JavaVersion "17"

# Navigate to output and run
cd employee-spring
mvn clean compile spring-boot:run
```

## Generated Project Structure

The migration creates a complete Spring Boot project with:
- Maven pom.xml
- Application.java (main class)
- REST Controllers (from RAML)
- Service layer (from Mule flows)
- Model classes (from RAML types)
- application.yml configuration
- schema.sql with sample data

## Notes

- The migration uses reflection-based row mappers to handle dynamic entity mapping
- Supports H2 in-memory database by default
- Generates Swagger documentation automatically
- Handles proper field name conversions (camelCase ↔ snake_case) 