param(
    [string]$BaseUrl = "http://localhost:8080"
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Employee API Testing Suite" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Base URL: $BaseUrl" -ForegroundColor Yellow
Write-Host ""

$testResults = @()
$passCount = 0
$failCount = 0

# Function to test an API endpoint
function Test-ApiEndpoint {
    param(
        [string]$Method,
        [string]$Endpoint,
        [string]$Body = $null,
        [string]$Description,
        [int]$ExpectedStatusCode = 0
    )
    
    Write-Host "`nTesting: $Description" -ForegroundColor Yellow
    Write-Host "Method: $Method $Endpoint" -ForegroundColor White
    
    try {
        $params = @{
            Uri = "$BaseUrl$Endpoint"
            Method = $Method
            ContentType = "application/json"
        }
        
        if ($Body) {
            $params.Body = $Body
            Write-Host "Body: $Body" -ForegroundColor Gray
        }
        
        $response = Invoke-WebRequest @params
        
        Write-Host "✅ Status: $($response.StatusCode)" -ForegroundColor Green
        
        if ($response.Content) {
            $json = $response.Content | ConvertFrom-Json
            Write-Host "Response:" -ForegroundColor White
            $json | ConvertTo-Json -Depth 10 | Write-Host -ForegroundColor Gray
        }
        
        $script:passCount++
        return @{
            Test = $Description
            Status = "PASS"
            StatusCode = $response.StatusCode
            Success = $true
        }
    }
    catch {
        $statusCode = if ($_.Exception.Response) { 
            [int]$_.Exception.Response.StatusCode 
        } else { 
            "N/A" 
        }
        
        # Check if this is an expected status code
        if ($ExpectedStatusCode -gt 0 -and $statusCode -eq $ExpectedStatusCode) {
            Write-Host "✅ Status: $statusCode (Expected)" -ForegroundColor Green
            $script:passCount++
            return @{
                Test = $Description
                Status = "PASS"
                StatusCode = $statusCode
                Success = $true
            }
        }
        
        Write-Host "❌ FAILED - Status: $statusCode" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        
        $script:failCount++
        return @{
            Test = $Description
            Status = "FAIL"
            StatusCode = $statusCode
            Error = $_.ToString()
            Success = $false
        }
    }
}

# Test 1: GET all employees
$testResults += Test-ApiEndpoint -Method "GET" -Endpoint "/employees" `
    -Description "GET all employees"

# Test 2: GET employee by ID
$testResults += Test-ApiEndpoint -Method "GET" -Endpoint "/employees/1" `
    -Description "GET employee by ID (ID=1)"

# Test 3: GET non-existent employee
$testResults += Test-ApiEndpoint -Method "GET" -Endpoint "/employees/999" `
    -Description "GET non-existent employee (ID=999) - Should return 404" `
    -ExpectedStatusCode 404

# Test 4: POST create new employee
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$newEmployee = @{
    firstName = "Test"
    lastName = "Employee"
    email = "test.employee.$timestamp@company.com"
    departmentId = "2"
    hireDate = "2024-01-01"
} | ConvertTo-Json

$createResult = Test-ApiEndpoint -Method "POST" -Endpoint "/employees" `
    -Body $newEmployee -Description "POST create new employee"

$testResults += $createResult

# Extract created employee ID if successful
$createdId = $null
if ($createResult.Success) {
    try {
        Start-Sleep -Seconds 1  # Give the database time to commit
        $allEmployees = Invoke-RestMethod -Uri "$BaseUrl/employees" -Method GET
        $createdEmployee = $allEmployees | Where-Object { $_.email -eq "test.employee.$timestamp@company.com" } | Select-Object -First 1
        
        if ($createdEmployee) {
            $createdId = $createdEmployee.id
            Write-Host "`nCreated employee ID: $createdId" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "`nCould not find created employee" -ForegroundColor Yellow
    }
}

# Test 5: PUT update employee
if ($createdId) {
    $updateEmployee = @{
        id = $createdId
        firstName = "Updated"
        lastName = "Employee"
        email = "updated.employee.$timestamp@company.com"
        departmentId = "3"
        hireDate = "2024-01-01"
    } | ConvertTo-Json
    
    $testResults += Test-ApiEndpoint -Method "PUT" -Endpoint "/employees/$createdId" `
        -Body $updateEmployee -Description "PUT update employee (ID=$createdId)"
    
    # Test 6: DELETE employee
    $testResults += Test-ApiEndpoint -Method "DELETE" -Endpoint "/employees/$createdId" `
        -Description "DELETE employee (ID=$createdId)"
    
    # Test 7: Verify deletion
    $testResults += Test-ApiEndpoint -Method "GET" -Endpoint "/employees/$createdId" `
        -Description "GET deleted employee (ID=$createdId) - Should return 404" `
        -ExpectedStatusCode 404
} else {
    Write-Host "`nSkipping PUT/DELETE tests - no created employee ID found" -ForegroundColor Yellow
    # Add placeholder results
    $testResults += @{Test = "PUT update employee"; Status = "SKIPPED"; StatusCode = "N/A"; Success = $false}
    $testResults += @{Test = "DELETE employee"; Status = "SKIPPED"; StatusCode = "N/A"; Success = $false}
    $testResults += @{Test = "GET deleted employee"; Status = "SKIPPED"; StatusCode = "N/A"; Success = $false}
}

# Test 8: POST with partial data
$partialEmployee = @{
    firstName = "Partial"
    # Missing some fields - API should handle gracefully
} | ConvertTo-Json

$testResults += Test-ApiEndpoint -Method "POST" -Endpoint "/employees" `
    -Body $partialEmployee -Description "POST with partial data"

# Display summary
Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "TEST RESULTS SUMMARY" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$testResults | ForEach-Object {
    switch ($_.Status) {
        "PASS" { 
            $color = "Green"
            $icon = "✅"
        }
        "SKIPPED" {
            $color = "Yellow" 
            $icon = "⚠️"
        }
        default {
            $color = "Red"
            $icon = "❌"
        }
    }
    Write-Host "$icon $($_.Test) - $($_.Status) (Status Code: $($_.StatusCode))" -ForegroundColor $color
}

Write-Host "`n================================================" -ForegroundColor Cyan
$skippedCount = ($testResults | Where-Object { $_.Status -eq "SKIPPED" }).Count
Write-Host "Total Tests: $($testResults.Count)" -ForegroundColor White
Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor Red
Write-Host "Skipped: $skippedCount" -ForegroundColor Yellow

$executedTests = $testResults.Count - $skippedCount
$successRate = if ($executedTests -gt 0) { 
    [math]::Round(($passCount / $executedTests) * 100, 2) 
} else { 0 }

Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -eq 100) { "Green" } else { "Yellow" })
Write-Host "================================================" -ForegroundColor Cyan

# Check API documentation
Write-Host "`nAPI Documentation URLs:" -ForegroundColor Yellow
Write-Host "Swagger UI: $BaseUrl/swagger-ui.html" -ForegroundColor White
Write-Host "OpenAPI Spec: $BaseUrl/api-docs" -ForegroundColor White
Write-Host "H2 Console: $BaseUrl/h2-console" -ForegroundColor White 