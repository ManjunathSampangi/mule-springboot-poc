@echo off
echo ========================================
echo Employee API Basic Authentication Test
echo ========================================
echo.
echo Default credentials (from application.properties):
echo Username: admin
echo Password: password123
echo Base64 encoded: YWRtaW46cGFzc3dvcmQxMjM=
echo.

echo 1. Testing without authentication (should return 401):
echo --------------------------------------------------------
curl -X GET http://localhost:8081/api/employees
echo.
echo.

echo 2. Testing with valid credentials (should return employee list):
echo ----------------------------------------------------------------
curl -X GET http://localhost:8081/api/employees -H "Authorization: Basic YWRtaW46cGFzc3dvcmQxMjM="
echo.
echo.

echo 3. Testing with invalid credentials (should return 401):
echo --------------------------------------------------------
curl -X GET http://localhost:8081/api/employees -H "Authorization: Basic aW52YWxpZDppbnZhbGlk"
echo.
echo.

echo 4. Testing POST with authentication (create employee):
echo -------------------------------------------------------
curl -X POST http://localhost:8081/api/employees ^
  -H "Authorization: Basic YWRtaW46cGFzc3dvcmQxMjM=" ^
  -H "Content-Type: application/json" ^
  -d "{\"firstName\":\"Test\",\"lastName\":\"User\",\"email\":\"test@example.com\",\"departmentId\":1,\"hireDate\":\"2025-01-01\"}"
echo.
echo.

echo 5. Testing GET specific employee with authentication:
echo -----------------------------------------------------
curl -X GET http://localhost:8081/api/employees/1 -H "Authorization: Basic YWRtaW46cGFzc3dvcmQxMjM="
echo.
echo.

echo 6. Alternative test using curl's built-in basic auth:
echo -----------------------------------------------------
curl -X GET http://localhost:8081/api/employees -u admin:password123
echo.
echo.

echo ========================================
echo Test completed!
echo ========================================
pause 