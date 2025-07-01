param(
    [string]$BaseUrl = "http://localhost:8081"
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Product API Testing Suite" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Base URL: $BaseUrl" -ForegroundColor Yellow
Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow

# Generate unique timestamp for test data
$timestamp = [DateTimeOffset]::Now.ToUnixTimeSeconds()

# Test results tracking
$testResults = @()

# Function to test API endpoints
function Test-ApiEndpoint {
    param(
        [string]$Method,
        [string]$Endpoint,
        [string]$Body,
        [string]$Description,
        [int]$ExpectedStatusCode = 200
    )
    
    $result = @{
        Test = $Description
        Status = "FAIL"
        StatusCode = 0
        Success = $false
    }
    
    try {
        $response = $null
        
        switch ($Method) {
            "GET" {
                $response = Invoke-WebRequest -Uri "$BaseUrl$Endpoint" -Method Get
            }
            "POST" {
                $response = Invoke-WebRequest -Uri "$BaseUrl$Endpoint" -Method Post `
                    -Body $Body -ContentType "application/json"
            }
            "PUT" {
                $response = Invoke-WebRequest -Uri "$BaseUrl$Endpoint" -Method Put `
                    -Body $Body -ContentType "application/json"
            }
            "DELETE" {
                $response = Invoke-WebRequest -Uri "$BaseUrl$Endpoint" -Method Delete
            }
        }
        
        $result.StatusCode = $response.StatusCode
        
        if ($response.StatusCode -eq $ExpectedStatusCode) {
            $result.Status = "PASS"
            $result.Success = $true
        } else {
            $result.Status = "FAIL"
        }
    } catch {
        if ($_.Exception.Response) {
            $result.StatusCode = $_.Exception.Response.StatusCode.value__
            if ($result.StatusCode -eq $ExpectedStatusCode) {
                $result.Status = "PASS"
                $result.Success = $true
            }
        }
    }
    
    return $result
}

Write-Host "`nRunning tests..." -ForegroundColor Yellow

# Test 1: GET all products
$testResults += Test-ApiEndpoint -Method "GET" -Endpoint "/products" `
    -Description "GET all products"

# Test 2: GET product by ID
$testResults += Test-ApiEndpoint -Method "GET" -Endpoint "/products/1" `
    -Description "GET product by ID (ID=1)"

# Test 3: GET non-existent product
$testResults += Test-ApiEndpoint -Method "GET" -Endpoint "/products/999" `
    -Description "GET non-existent product (ID=999) - Should return 404" `
    -ExpectedStatusCode 404

# Test 4: POST create new product
$newProduct = @{
    name = "Test Product $timestamp"
    description = "Product created during testing"
    price = 99.99
    category = "Test Category"
    stock = 100
    active = $true
} | ConvertTo-Json

$createResult = Test-ApiEndpoint -Method "POST" -Endpoint "/products" `
    -Body $newProduct -Description "POST create new product" -ExpectedStatusCode 201
$testResults += $createResult

# Extract created product ID if successful
$createdId = $null
if ($createResult.Success) {
    try {
        Start-Sleep -Seconds 1  # Give the database time to commit
        $allProducts = Invoke-RestMethod -Uri "$BaseUrl/products" -Method GET
        $createdProduct = $allProducts | Where-Object { $_.name -eq "Test Product $timestamp" } | Select-Object -First 1
        
        if ($createdProduct) {
            $createdId = $createdProduct.id
            Write-Host "`nCreated product ID: $createdId" -ForegroundColor Cyan
        } else {
            Write-Host "`nWarning: Could not find created product" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "`nWarning: Could not extract created product ID" -ForegroundColor Yellow
    }
}

# Test 5: PUT update product
if ($createdId) {
    $updateProduct = @{
        id = $createdId
        name = "Updated Product $timestamp"
        description = "Product updated during testing"
        price = 149.99
        category = "Updated Category"
        stock = 50
        active = $false
    } | ConvertTo-Json
    
    $testResults += Test-ApiEndpoint -Method "PUT" -Endpoint "/products/$createdId" `
        -Body $updateProduct -Description "PUT update product (ID=$createdId)"
} else {
    $testResults += @{
        Test = "PUT update product"
        Status = "SKIPPED"
        StatusCode = 0
        Success = $false
    }
}

# Test 6: DELETE product
if ($createdId) {
    $testResults += Test-ApiEndpoint -Method "DELETE" -Endpoint "/products/$createdId" `
        -Description "DELETE product (ID=$createdId)" -ExpectedStatusCode 204
    
    # Test 7: Verify deletion
    $testResults += Test-ApiEndpoint -Method "GET" -Endpoint "/products/$createdId" `
        -Description "GET deleted product (ID=$createdId) - Should return 404" `
        -ExpectedStatusCode 404
} else {
    $testResults += @{
        Test = "DELETE product"
        Status = "SKIPPED"
        StatusCode = 0
        Success = $false
    }
    $testResults += @{
        Test = "GET deleted product - Should return 404"
        Status = "SKIPPED"
        StatusCode = 0
        Success = $false
    }
}

# Test 8: POST with partial data
$partialProduct = @{
    name = "Partial Product"
    # Missing some fields - API should handle gracefully
} | ConvertTo-Json

$testResults += Test-ApiEndpoint -Method "POST" -Endpoint "/products" `
    -Body $partialProduct -Description "POST with partial data" -ExpectedStatusCode 201

# Display results
Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Test Results:" -ForegroundColor Cyan
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

# Summary
$passCount = ($testResults | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = ($testResults | Where-Object { $_.Status -eq "FAIL" }).Count
$skippedCount = ($testResults | Where-Object { $_.Status -eq "SKIPPED" }).Count

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Total Tests: $($testResults.Count)" -ForegroundColor White
Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor Red
Write-Host "Skipped: $skippedCount" -ForegroundColor Yellow

$executedTests = $testResults.Count - $skippedCount
$successRate = if ($executedTests -gt 0) { 
    [math]::Round(($passCount / $executedTests) * 100, 2) 
} else { 0 }

Write-Host "`nSuccess Rate: $successRate%" -ForegroundColor $(if ($successRate -eq 100) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })

# Sample GET request output
if ($passCount -gt 0) {
    Write-Host "`n================================================" -ForegroundColor Cyan
    Write-Host "Sample API Response:" -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan
    try {
        $sampleProducts = Invoke-RestMethod -Uri "$BaseUrl/products" -Method Get | Select-Object -First 2
        $sampleProducts | ConvertTo-Json -Depth 5 | Write-Host
    } catch {}
}

Write-Host "`nAPI Documentation: $BaseUrl/swagger-ui.html" -ForegroundColor Cyan 