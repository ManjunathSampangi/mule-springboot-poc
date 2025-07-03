@echo off
echo Starting Product API...
echo.
echo Using Maven Wrapper with Maven 3.6.3 (compatible with Mule)
echo.
call mvnw clean install
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
echo Running Product API...
call mvnw mule:run
pause 