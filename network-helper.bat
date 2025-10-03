@echo off
echo =================================
echo Network Configuration Helper
echo =================================
echo.

echo Your current IP configuration:
ipconfig | findstr /i "IPv4"

echo.
echo =================================
echo Common Steps to Fix Connection:
echo =================================
echo.
echo 1. Make sure your mobile phone is connected to the SAME WiFi network as this computer
echo 2. Use one of the IPv4 addresses shown above in your app
echo 3. Make sure Windows Firewall allows connections on port 8080
echo 4. Make sure your backend server is running on port 8080
echo.

echo =================================
echo Testing if server is running:
echo =================================
echo.
netstat -an | findstr :8080
if %ERRORLEVEL%==0 (
    echo ✓ Server appears to be running on port 8080
) else (
    echo ✗ No server found on port 8080
    echo   Start your backend server first!
)

echo.
echo =================================
echo Windows Firewall Rule Setup:
echo =================================
echo.
echo Run this command as Administrator to allow incoming connections:
echo netsh advfirewall firewall add rule name="TrailMix Backend" dir=in action=allow protocol=TCP localport=8080
echo.

echo =================================
echo Mobile Phone Network Test:
echo =================================
echo.
echo From your mobile phone, try to access:
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4"') do (
    for /f "tokens=1" %%b in ("%%a") do (
        echo http://%%b:8080/api/test
    )
)

echo.
pause