@echo off
echo Starting Real-Time Order Management System...
echo.

echo Starting Spring Boot Backend...
start "Backend" cmd /k "cd order-service && mvn spring-boot:run"

echo Waiting for backend to start...
timeout /t 10 /nobreak > nul

echo Starting React Frontend...
start "Frontend" cmd /k "cd order-ui && npm start"

echo.
echo Application is starting...
echo Backend will be available at: http://localhost:8080
echo Frontend will be available at: http://localhost:3000
echo.
echo Press any key to stop all services...
pause > nul

echo Stopping services...
taskkill /f /im java.exe > nul 2>&1
taskkill /f /im node.exe > nul 2>&1
echo Services stopped. 