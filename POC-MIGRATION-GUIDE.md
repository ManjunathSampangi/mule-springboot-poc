# POC Migration Guide - 2 Mule Projects

## Available Mule Projects

### 1. Employee API (mule-source)
- **Type**: Employee Management System
- **Operations**: Full CRUD (Create, Read, Update, Delete)
- **Database**: H2 in-memory database
- **Features**: 
  - Get all employees
  - Get employee by ID
  - Create new employee
  - Update employee
  - Delete employee

### 2. Product Catalog API (mule-product-api)
- **Type**: Product Management System
- **Operations**: Full CRUD with filtering
- **Database**: H2 in-memory database
- **Features**:
  - Get all products with category/status filtering
  - Get product by ID
  - Create new product
  - Update product details
  - Delete product
  - Stock management
  - Category classification (Electronics, Clothing, Food, Books, Other)

## Migration Commands

### Migrate Employee API
```powershell
.\run-generic-migration-smart.ps1 `
    -MuleProjectPath ".\mule-source" `
    -OutputPath "employee-spring-boot" `
    -PackageName "com.company.employee" `
    -JavaVersion "17"
```

### Migrate Product API
```powershell
.\run-generic-migration-smart.ps1 `
    -MuleProjectPath ".\mule-product-api" `
    -OutputPath "product-spring-boot" `
    -PackageName "com.company.product" `
    -JavaVersion "17"
```

## Running the Migrated Applications

### Employee API
```powershell
cd employee-spring-boot
mvn clean compile spring-boot:run
# Access at http://localhost:8081/employees
```

### Product API
```powershell
cd product-spring-boot
mvn clean compile spring-boot:run
# Access at http://localhost:8081/products
```

## Testing Endpoints

### Employee API Endpoints
- GET `/employees` - Get all employees
- GET `/employees/{id}` - Get employee by ID
- POST `/employees` - Create new employee
- PUT `/employees/{id}` - Update employee
- DELETE `/employees/{id}` - Delete employee

### Product API Endpoints
- GET `/products` - Get all products
- GET `/products?category=Electronics` - Filter by category
- GET `/products?active=true` - Filter by status
- GET `/products/{id}` - Get product by ID
- POST `/products` - Create new product
- PUT `/products/{id}` - Update product
- DELETE `/products/{id}` - Delete product

## Sample Test Data

### Employee JSON
```json
{
  "firstName": "John",
  "lastName": "Doe",
  "email": "john.doe@company.com",
  "departmentId": 1,
  "hireDate": "2024-01-15"
}
```

### Product JSON
```json
{
  "name": "Laptop",
  "description": "High performance laptop",
  "price": 999.99,
  "category": "Electronics",
  "stock": 50,
  "active": true
}
```

## Features Demonstrated
1. **RAML to Spring REST conversion**
2. **Mule flows to Spring Services**
3. **Database operations mapping**
4. **Error handling**
5. **Bean validation**
6. **Swagger UI integration**
7. **H2 console access** 