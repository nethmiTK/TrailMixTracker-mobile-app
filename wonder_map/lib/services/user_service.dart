import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class UserService {
  static String get baseUrl {
    // Use localhost for web, mobile IP for Android devices
    if (kIsWeb) {
      return 'http://localhost:8080/api';
    } else {
      return 'http://10.49.68.38:8080/api';
    }
  }

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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('secure_$key', value);
      return;
    }

    try {
      await _storage.write(key: key, value: value);
    } on PlatformException catch (e) {
      print('UserService - Secure storage write error: ${e.message}');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('secure_$key', value);
    } on MissingPluginException catch (e) {
      print('UserService - Plugin not found: ${e.message}');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('secure_$key', value);
    } catch (e) {
      print('UserService - Unexpected secure storage error: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('secure_$key', value);
    }
  }

  // Helper method to safely read from secure storage
  Future<String?> _secureRead(String key) async {
    if (!_isSecureStorageSupported) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('secure_$key');
    }

    try {
      return await _storage.read(key: key);
    } on PlatformException catch (e) {
      print('UserService - Secure storage read error: ${e.message}');
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('secure_$key');
    } on MissingPluginException catch (e) {
      print('UserService - Plugin not found: ${e.message}');
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('secure_$key');
    } catch (e) {
      print('UserService - Unexpected secure storage error: $e');
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('secure_$key');
    }
  }

  // Store user data after login
  Future<void> storeUserData(
      Map<String, dynamic> userData, String token) async {
    try {
      print('UserService - Storing token and user data...');
      await _secureWrite('auth_token', token);
      
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', json.encode(userData));
        print('UserService - Successfully stored user data');
      } catch (e) {
        print('UserService - Failed to store user data in SharedPreferences: $e');
        // Continue even if SharedPreferences fails
      }
    } catch (e) {
      print('UserService - Error storing user data: $e');
      // Don't rethrow, allow login to proceed even if storage fails
    }
  }

  // Get stored user data
  Future<Map<String, dynamic>?> getStoredUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      return json.decode(userDataString);
    }
    return null;
  }

  // Get user profile
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final token = await _secureRead('auth_token');
      if (token == null) {
        return {
          'success': false,
          'message': 'User not authenticated',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/users/profile'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        await _storage.write(key: 'user_profile', value: json.encode(data));
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get user profile',
        };
      }
    } catch (e) {
      print('Error getting user profile: $e');
      return {
        'success': false,
        'message': 'Error getting user profile: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>?> getCachedProfile() async {
    try {
      final profileJson = await _storage.read(key: 'user_profile');
      if (profileJson != null) {
        return json.decode(profileJson);
      }
      return null;
    } catch (e) {
      print('Error getting cached profile: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> updateProfileField({
    String? username,
    String? email,
    String? bio,
  }) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        return {
          'success': false,
          'message': 'User not authenticated',
        };
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/users/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          if (username != null) 'username': username,
          if (email != null) 'email': email,
          if (bio != null) 'bio': bio,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        await _storage.write(key: 'user_profile', value: json.encode(data));
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update profile',
        };
      }
    } catch (e) {
      print('Error updating profile: $e');
      return {
        'success': false,
        'message': 'Error updating profile: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> updateProfileImage(File imageFile) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        return {
          'success': false,
          'message': 'User not authenticated',
        };
      }

      final mimeType = lookupMimeType(imageFile.path);
      if (mimeType == null || !mimeType.startsWith('image/')) {
        return {
          'success': false,
          'message': 'Invalid image file',
        };
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/users/profile/image'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      request.files.add(
        await http.MultipartFile.fromPath(
          'profile_image',
          imageFile.path,
          contentType: MediaType.parse(mimeType),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        await _storage.write(key: 'user_profile', value: json.encode(data));
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update profile image',
        };
      }
    } catch (e) {
      print('Error updating profile image: $e');
      return {
        'success': false,
        'message': 'Error updating profile image: ${e.toString()}',
      };
    }
  }

  // Clear all stored data on logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _storage.deleteAll();
  }
}
