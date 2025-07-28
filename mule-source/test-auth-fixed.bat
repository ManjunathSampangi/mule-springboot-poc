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
curl -X GET http://localhost:8081/api/employees
echo.
echo.

echo 2. Testing with valid credentials (should return employee list):
curl -X GET http://localhost:8081/api/employees -H "Authorization: Basic YWRtaW46cGFzc3dvcmQxMjM="
echo.
echo.

echo 3. Testing with invalid credentials (should return 401):
curl -X GET http://localhost:8081/api/employees -H "Authorization: Basic aW52YWxpZDppbnZhbGlk"
echo.
echo.

echo 4. Alternative using username:password format (curl will encode automatically):
curl -X GET http://localhost:8081/api/employees -u admin:password123
echo.
echo.

echo 5. Testing POST with authentication:
curl -X POST http://localhost:8081/api/employees ^
  -H "Content-Type: application/json" ^
  -H "Authorization: Basic YWRtaW46cGFzc3dvcmQxMjM=" ^
  -d "{\"firstName\":\"Test\",\"lastName\":\"User\",\"email\":\"test@example.com\",\"departmentId\":1,\"hireDate\":\"2024-01-01\"}"
echo.
echo.

pause 