# TrailMix Mobile App - Network Connection Fix

## Problem
Your Flutter app shows "Network error, unable to connect" when running on your mobile phone.

## Root Cause
The app can't connect to your backend server running on your computer because of network configuration issues.

## Solutions

### 1. Ensure Same Network Connection
- Make sure your mobile phone is connected to the SAME WiFi network as your computer
- Your computer IP is: `10.49.68.38`
- Your phone must be on the same network (10.49.68.x range)

### 2. Windows Firewall Configuration
**Run PowerShell as Administrator** and execute:
```powershell
netsh advfirewall firewall add rule name="TrailMix Backend" dir=in action=allow protocol=TCP localport=8080
```

### 3. Test Server Connection
Your backend server is running on: `http://10.49.68.38:8080`

To test from your phone's browser, visit:
- `http://10.49.68.38:8080/api/test`

### 4. Updated Code Features

I've updated your Flutter app with these improvements:

1. **Automatic Server Discovery**: The app now tries multiple IP addresses automatically
2. **Better Error Messages**: More helpful error messages when connection fails
3. **Robust Connection Handling**: Falls back to different URLs if one fails

### 5. IP Addresses the App Will Try
1. `http://10.49.68.38:8080/api` (Your current WiFi IP)
2. `http://192.168.1.100:8080/api` (Common router range)
3. `http://192.168.0.100:8080/api` (Another common range)
4. `http://10.0.2.2:8080/api` (Android emulator)

### 6. Manual IP Configuration
If your IP changes, update the first IP in the list in:
`lib/services/api_config.dart`

### 7. Troubleshooting Steps

1. **Check if server is running**:
   ```
   netstat -an | Select-String ":8080"
   ```
   Should show: `TCP    0.0.0.0:8080           0.0.0.0:0              LISTENING`

2. **Check your IP address**:
   ```
   ipconfig
   ```
   Look for "IPv4 Address" under your WiFi adapter

3. **Test from phone browser**:
   Open browser on your phone and go to: `http://10.49.68.38:8080`

4. **Restart backend server if needed**:
   ```
   cd "Mobile Backend"
   npm start
   ```

### 8. Alternative Solution - Use Router IP
If the above doesn't work, find your router's IP range:
- Common ranges: 192.168.1.x or 192.168.0.x
- Update the IP in `api_config.dart` accordingly

## Quick Test Procedure

1. Run PowerShell as Administrator
2. Execute: `netsh advfirewall firewall add rule name="TrailMix Backend" dir=in action=allow protocol=TCP localport=8080`
3. Make sure backend server is running: `cd "Mobile Backend" && npm start`
4. Connect your phone to the same WiFi as your computer
5. Test the updated Flutter app

The app will now automatically try different IP addresses and show better error messages to help you troubleshoot.