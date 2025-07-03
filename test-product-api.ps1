#!/usr/bin/env pwsh

Write-Host "========================================" -ForegroundColor Green
Write-Host "Testing Mule Product API (Port 8082)" -ForegroundColor Green  
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

$baseUrl = "http://localhost:8082"

# Test 1: Basic connectivity
Write-Host "[1] Test 1: Basic connectivity" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/test" -Method GET
    Write-Host "SUCCESS: $response" -ForegroundColor Green
} catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 2: Get all products
Write-Host "[2] Test 2: Get all products" -ForegroundColor Yellow
try {
    $products = Invoke-RestMethod -Uri "$baseUrl/api/products" -Method GET
    Write-Host "SUCCESS: Found $($products.Count) products" -ForegroundColor Green
    $products | ForEach-Object { 
        Write-Host "   - ID: $($_.id), Name: $($_.name), Price: $($_.price), Category: $($_.category)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 3: Get product by ID
Write-Host "[3] Test 3: Get product by ID (ID=1)" -ForegroundColor Yellow
try {
    $product = Invoke-RestMethod -Uri "$baseUrl/api/products/1" -Method GET
    Write-Host "SUCCESS: Found product '$($product.name)' - Price: $($product.price)" -ForegroundColor Green
} catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 4: Filter by category
Write-Host "[4] Test 4: Filter products by category (Electronics)" -ForegroundColor Yellow
try {
    $electronics = Invoke-RestMethod -Uri "$baseUrl/api/products?category=Electronics" -Method GET
    Write-Host "SUCCESS: Found $($electronics.Count) electronics products" -ForegroundColor Green
    $electronics | ForEach-Object { 
        Write-Host "   - $($_.name): $($_.price)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 5: Create new product
Write-Host "[5] Test 5: Create new product" -ForegroundColor Yellow
$newProduct = @{
    name = "Test Keyboard"
    description = "Mechanical gaming keyboard"
    price = 149.99
    category = "Electronics"
    stock = 15
    active = $true
} | ConvertTo-Json

try {
    $created = Invoke-RestMethod -Uri "$baseUrl/api/products" -Method POST -Body $newProduct -ContentType "application/json"
    Write-Host "SUCCESS: Created product with ID $($created.id)" -ForegroundColor Green
    $newProductId = $created.id
} catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    $newProductId = $null
}
Write-Host ""

# Test 6: Update product (if creation was successful)
if ($newProductId) {
    Write-Host "[6] Test 6: Update product (ID=$newProductId)" -ForegroundColor Yellow
    $updateProduct = @{
        name = "Updated Test Keyboard"
        description = "RGB Mechanical gaming keyboard"
        price = 179.99
        category = "Electronics"
        stock = 12
        active = $true
    } | ConvertTo-Json

    try {
        $updated = Invoke-RestMethod -Uri "$baseUrl/api/products/$newProductId" -Method PUT -Body $updateProduct -ContentType "application/json"
        Write-Host "SUCCESS: Updated product '$($updated.name)' - Price: $($updated.price)" -ForegroundColor Green
    } catch {
        Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""

    # Test 7: Delete product
    Write-Host "[7] Test 7: Delete product (ID=$newProductId)" -ForegroundColor Yellow
    try {
        $response = Invoke-WebRequest -Uri "$baseUrl/api/products/$newProductId" -Method DELETE
        if ($response.StatusCode -eq 204) {
            Write-Host "SUCCESS: Product deleted (HTTP 204)" -ForegroundColor Green
        } else {
            Write-Host "PARTIAL: Delete returned HTTP $($response.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# Test 8: Get non-existent product (should return 404)
Write-Host "[8] Test 8: Get non-existent product (ID=999)" -ForegroundColor Yellow
try {
    $notFound = Invoke-RestMethod -Uri "$baseUrl/api/products/999" -Method GET
    Write-Host "UNEXPECTED: Should have returned 404" -ForegroundColor Yellow
} catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Host "SUCCESS: Correctly returned 404 for non-existent product" -ForegroundColor Green
    } else {
        Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "Product API Testing Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Access your API at:" -ForegroundColor Cyan
Write-Host "   • Test endpoint: http://localhost:8082/test" -ForegroundColor White
Write-Host "   • API endpoints: http://localhost:8082/api/products" -ForegroundColor White
Write-Host "   • RAML spec: See mule-product-api/src/main/resources/api/product-api.raml" -ForegroundColor White 