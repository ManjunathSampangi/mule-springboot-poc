Write-Host "`n=== Testing Mule Employee API ===" -ForegroundColor Cyan
Write-Host "Base URL: http://localhost:8081/api/employees" -ForegroundColor Yellow

# Test 1: GET all employees
Write-Host "`n[TEST 1] GET all employees" -ForegroundColor Green
try {
    $response = Invoke-RestMethod -Uri "http://localhost:8081/api/employees" -Method Get
    Write-Host "SUCCESS: Retrieved $($response.Count) employees" -ForegroundColor Green
    $response | Format-Table -AutoSize
} catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
}

# Test 2: GET employee by ID
Write-Host "`n[TEST 2] GET employee by ID (ID=1)" -ForegroundColor Green
try {
    $response = Invoke-RestMethod -Uri "http://localhost:8081/api/employees/1" -Method Get
    Write-Host "SUCCESS: Retrieved employee" -ForegroundColor Green
    $response | Format-List
} catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
}

# Test 3: GET non-existent employee
Write-Host "`n[TEST 3] GET non-existent employee (ID=999)" -ForegroundColor Green
try {
    $response = Invoke-RestMethod -Uri "http://localhost:8081/api/employees/999" -Method Get
    Write-Host "FAILED: Should have returned 404" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Host "SUCCESS: Correctly returned 404 Not Found" -ForegroundColor Green
    } else {
        Write-Host "FAILED: $_" -ForegroundColor Red
    }
}

# Test 4: POST create new employee
Write-Host "`n[TEST 4] POST create new employee" -ForegroundColor Green
$newEmployee = @{
    firstName = "Alice"
    lastName = "Williams"
    email = "alice.williams@example.com"
    departmentId = 3
    hireDate = "2024-01-15"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "http://localhost:8081/api/employees" -Method Post -Body $newEmployee -ContentType "application/json"
    Write-Host "SUCCESS: Created employee with ID: $($response.id)" -ForegroundColor Green
    $response | Format-List
    $script:createdId = $response.id
} catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
}

# Test 5: PUT update employee
Write-Host "`n[TEST 5] PUT update employee (ID=2)" -ForegroundColor Green
$updateEmployee = @{
    firstName = "Jane"
    lastName = "Doe"
    email = "jane.doe@example.com"
    departmentId = 3
    hireDate = "2023-02-20"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "http://localhost:8081/api/employees/2" -Method Put -Body $updateEmployee -ContentType "application/json"
    Write-Host "SUCCESS: Updated employee" -ForegroundColor Green
    $response | Format-List
} catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
}

# Test 6: PUT update non-existent employee
Write-Host "`n[TEST 6] PUT update non-existent employee (ID=999)" -ForegroundColor Green
try {
    $response = Invoke-RestMethod -Uri "http://localhost:8081/api/employees/999" -Method Put -Body $updateEmployee -ContentType "application/json"
    Write-Host "FAILED: Should have returned 404" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Host "SUCCESS: Correctly returned 404 Not Found" -ForegroundColor Green
    } else {
        Write-Host "FAILED: $_" -ForegroundColor Red
    }
}

# Test 7: DELETE employee
Write-Host "`n[TEST 7] DELETE employee (ID=$script:createdId)" -ForegroundColor Green
if ($script:createdId) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8081/api/employees/$script:createdId" -Method Delete
        if ($response.StatusCode -eq 204) {
            Write-Host "SUCCESS: Deleted employee (204 No Content)" -ForegroundColor Green
        } else {
            Write-Host "SUCCESS: Deleted employee (Status: $($response.StatusCode))" -ForegroundColor Green
        }
    } catch {
        Write-Host "FAILED: $_" -ForegroundColor Red
    }
} else {
    Write-Host "SKIPPED: No employee ID to delete" -ForegroundColor Yellow
}

# Test 8: DELETE non-existent employee
Write-Host "`n[TEST 8] DELETE non-existent employee (ID=999)" -ForegroundColor Green
try {
    $response = Invoke-RestMethod -Uri "http://localhost:8081/api/employees/999" -Method Delete
    Write-Host "FAILED: Should have returned 404" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Host "SUCCESS: Correctly returned 404 Not Found" -ForegroundColor Green
    } else {
        Write-Host "FAILED: $_" -ForegroundColor Red
    }
}

# Final check: GET all employees again
Write-Host "`n[FINAL CHECK] GET all employees to verify state" -ForegroundColor Green
try {
    $response = Invoke-RestMethod -Uri "http://localhost:8081/api/employees" -Method Get
    Write-Host "SUCCESS: Retrieved $($response.Count) employees" -ForegroundColor Green
    $response | Format-Table -AutoSize
} catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
}

Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "All CRUD operations have been tested!" -ForegroundColor Yellow 