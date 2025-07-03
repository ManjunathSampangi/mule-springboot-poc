Write-Host "Testing Mule Employee API" -ForegroundColor Green
Write-Host "Base URL: http://localhost:8081" -ForegroundColor Yellow
Write-Host "=====================================`n" -ForegroundColor Green

$baseUrl = "http://localhost:8081"

# Test health check
Write-Host "1. Testing GET /test (Health Check)" -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/test" -Method Get
    Write-Host "✓ Success: $response" -ForegroundColor Green
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test get all employees
Write-Host "`n2. Testing GET /api/employees (Get all employees)" -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/employees" -Method Get
    Write-Host "✓ Success: Retrieved $($response.Count) employees" -ForegroundColor Green
    $response | Format-Table -AutoSize
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test get employee by ID
Write-Host "`n3. Testing GET /api/employees/1 (Get employee by ID)" -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/employees/1" -Method Get
    Write-Host "✓ Success: Retrieved employee with ID 1" -ForegroundColor Green
    $response | Format-Table -AutoSize
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test create employee
Write-Host "`n4. Testing POST /api/employees (Create new employee)" -ForegroundColor Cyan
$newEmployee = @{
    firstName = "John"
    lastName = "Doe"
    email = "john.doe@company.com"
    departmentId = 1
    hireDate = "2024-01-15"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/employees" -Method Post -Body $newEmployee -ContentType "application/json"
    Write-Host "✓ Success: Created new employee" -ForegroundColor Green
    $response | Format-Table -AutoSize
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test create another employee
Write-Host "`n5. Testing POST /api/employees (Create Alice Johnson)" -ForegroundColor Cyan
$newEmployee2 = @{
    firstName = "Alice"
    lastName = "Johnson"
    email = "alice.johnson@company.com"
    departmentId = 2
    hireDate = "2024-02-20"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/employees" -Method Post -Body $newEmployee2 -ContentType "application/json"
    Write-Host "✓ Success: Created Alice Johnson" -ForegroundColor Green
    $response | Format-Table -AutoSize
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test update employee
Write-Host "`n6. Testing PUT /api/employees/1 (Update employee)" -ForegroundColor Cyan
$updateEmployee = @{
    firstName = "Jane"
    lastName = "Doe"
    email = "jane.doe@company.com"
    departmentId = 2
    hireDate = "2024-01-20"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/employees/1" -Method Put -Body $updateEmployee -ContentType "application/json"
    Write-Host "✓ Success: Updated employee with ID 1" -ForegroundColor Green
    $response | Format-Table -AutoSize
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test delete employee
Write-Host "`n7. Testing DELETE /api/employees/3 (Delete employee)" -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/employees/3" -Method Delete
    Write-Host "✓ Success: Deleted employee with ID 3" -ForegroundColor Green
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Get all employees again to see final state
Write-Host "`n8. Testing GET /api/employees (Final state)" -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/employees" -Method Get
    Write-Host "✓ Success: Final employee list ($($response.Count) employees)" -ForegroundColor Green
    $response | Format-Table -AutoSize
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=====================================`n" -ForegroundColor Green
Write-Host "Test completed!" -ForegroundColor Yellow 