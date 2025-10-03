import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class AuthService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    wOptions: WindowsOptions(),
    lOptions: LinuxOptions(),
    webOptions: WebOptions(),
  );

  // Check if secure storage is available on current platform
  static bool get _isSecureStorageSupported {
    if (kIsWeb) return true;
    return Platform.isAndroid || Platform.isIOS || Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  // Helper method to safely write to secure storage with platform check
  Future<void> _secureWrite(String key, String value) async {
    if (!_isSecureStorageSupported) {
      // Fallback to SharedPreferences for unsupported platforms
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('secure_$key', value);
      return;
    }

    try {
      await _storage.write(key: key, value: value);
    } on PlatformException catch (e) {
      print('Secure storage write error: ${e.message}');
      print('Error code: ${e.code}');
      // Fallback to SharedPreferences if secure storage fails
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('secure_$key', value);
    } on MissingPluginException catch (e) {
      print('Plugin not found: ${e.message}');
      // Fallback to SharedPreferences if plugin is missing
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('secure_$key', value);
    } catch (e) {
      print('Unexpected secure storage error: $e');
      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('secure_$key', value);
    }
  }

  // Helper method to safely read from secure storage with platform check
  Future<String?> _secureRead(String key) async {
    if (!_isSecureStorageSupported) {
      // Fallback to SharedPreferences for unsupported platforms
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('secure_$key');
    }

    try {
      return await _storage.read(key: key);
    } on PlatformException catch (e) {
      print('Secure storage read error: ${e.message}');
      print('Error code: ${e.code}');
      // Fallback to SharedPreferences if secure storage fails
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('secure_$key');
    } on MissingPluginException catch (e) {
      print('Plugin not found: ${e.message}');
      // Fallback to SharedPreferences if plugin is missing
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('secure_$key');
    } catch (e) {
      print('Unexpected secure storage error: $e');
      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('secure_$key');
    }
  }

  // Helper method to safely delete from secure storage with platform check
  Future<void> _secureDelete(String key) async {
    if (!_isSecureStorageSupported) {
      // Fallback to SharedPreferences for unsupported platforms
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('secure_$key');
      return;
    }

    try {
      await _storage.delete(key: key);
    } on PlatformException catch (e) {
      print('Secure storage delete error: ${e.message}');
      print('Error code: ${e.code}');
      // Fallback to SharedPreferences if secure storage fails
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('secure_$key');
    } on MissingPluginException catch (e) {
      print('Plugin not found: ${e.message}');
      // Fallback to SharedPreferences if plugin is missing
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('secure_$key');
    } catch (e) {
      print('Unexpected secure storage error: $e');
      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('secure_$key');
    }
  }

  // Login user
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await ApiConfig.makeRequest(
        '/users/login',
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response == null) {
        return {
          'success': false,
          'message': ApiConfig.getNetworkErrorMessage(),
        };
      }

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Save token using secure storage with error handling
        try {
          await _secureWrite('auth_token', data['token']);
          print('Token saved successfully');
        } catch (e) {
          print('Failed to save token: $e');
        }

        // Save user data - with fallback mechanism
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_data', json.encode(data['user']));
          print('User data saved successfully');
        } catch (e) {
          print('Failed to save user data: $e');
          // Even if storage fails, allow login to proceed
        }

        return {
          'success': true,
          'token': data['token'],
          'user': data['user'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      print('Login error: $e');
      return {
        'success': false,
        'message': 'Network error: Unable to connect to server - $e',
      };
    }
  }

  // Register user
  Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    try {
      print('Attempting to register user...');

      final response = await ApiConfig.makeRequest(
        '/users/register',
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      if (response == null) {
        return {
          'success': false,
          'message': ApiConfig.getNetworkErrorMessage(),
        };
      }

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Registration successful',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      print('Registration error details: $e');
      return {
        'success': false,
        'message': 'Error during registration: $e',
      };
    }
  }

  // Logout
  Future<void> logout() async {
    await _secureDelete('auth_token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await _secureRead('auth_token');
    return token != null;
  }

  // Get stored token
  Future<String?> getToken() async {
    return await _secureRead('auth_token');
  }

  // Get user role
  Future<String?> getRole() async {
    return await _secureRead('userRole');
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');

      if (userData != null) {
        return {
          'success': true,
          'data': json.decode(userData),
        };
      }
      return {
        'success': false,
        'message': 'No user data found',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
}
