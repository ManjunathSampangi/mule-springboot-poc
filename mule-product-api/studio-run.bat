@echo off
echo ========================================
echo Anypoint Studio Product API Runner
echo ========================================
echo.

echo Step 1: Cleaning target directory...
rd /s /q target 2>nul

echo Step 2: Creating minimal target structure...
mkdir target\classes

echo Step 3: Copying configuration files...
xcopy /s /y src\main\resources\* target\classes\ >nul

echo Step 4: Instructions for Anypoint Studio:
echo.
echo 1. In Anypoint Studio, right-click on your project
echo 2. Select "Run As" > "Run Configurations..."
echo 3. Create a new "Mule Application" configuration
echo 4. In the "Main" tab, ensure your project is selected
echo 5. In the "Arguments" tab, add these VM arguments:
echo    -Dmule.home=${mule.home} 
echo    -Dmaven.multiModuleProjectDirectory=${workspace_loc}/mule-product-api
echo    -Dmule.forceConsoleLog=true
echo.
echo 6. Click "Run"
echo.
echo Alternative: Run from command line using Maven wrapper:
echo    .\mvnw clean package -DskipTests
echo    .\mvnw mule:run
echo.
echo Product API will run on port 8082
echo Test endpoint: http://localhost:8082/test
echo API endpoints: http://localhost:8082/api/products
echo.
pause 