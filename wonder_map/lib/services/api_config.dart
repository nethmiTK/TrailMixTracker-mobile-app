import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ApiConfig {
  // List of possible server URLs to try
  static List<String> get serverUrls {
    if (kIsWeb) {
      return ['http://localhost:8080/api'];
    } else {
      return [
        'http://10.49.68.38:8080/api', // Current WiFi IP
        'http://192.168.1.100:8080/api', // Common router IP range
        'http://192.168.0.100:8080/api', // Another common range
        'http://10.0.2.2:8080/api', // Android emulator
      ];
    }
  }

  static String get baseUrl {
    // Return the first URL as default
    return serverUrls.first;
  }

  // Test server connectivity
  static Future<String?> findWorkingServer() async {
    for (String url in serverUrls) {
      try {
        print('Testing server at: $url');
        final response = await http.get(
          Uri.parse('$url/test'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(Duration(seconds: 5));

        if (response.statusCode == 200 || response.statusCode == 404) {
          // 404 is OK too, means server is running but route doesn't exist
          print('Server found at: $url');
          return url;
        }
      } catch (e) {
        print('Server at $url failed: $e');
        continue;
      }
    }
    print('No working server found');
    return null;
  }

  // Make HTTP request with automatic server discovery
  static Future<http.Response?> makeRequest(
    String endpoint, {
    required String method,
    Map<String, String>? headers,
    String? body,
  }) async {
    // First try to find a working server
    String? workingUrl = await findWorkingServer();

    if (workingUrl == null) {
      // If no server found, try all URLs
      for (String url in serverUrls) {
        try {
          Uri uri = Uri.parse('$url$endpoint');
          http.Response response;

          switch (method.toUpperCase()) {
            case 'POST':
              response = await http
                  .post(uri, headers: headers, body: body)
                  .timeout(Duration(seconds: 15));
              break;
            case 'GET':
              response = await http
                  .get(uri, headers: headers)
                  .timeout(Duration(seconds: 15));
              break;
            case 'PUT':
              response = await http
                  .put(uri, headers: headers, body: body)
                  .timeout(Duration(seconds: 15));
              break;
            case 'DELETE':
              response = await http
                  .delete(uri, headers: headers)
                  .timeout(Duration(seconds: 15));
              break;
            default:
              throw Exception('Unsupported HTTP method: $method');
          }

          return response;
        } catch (e) {
          print('Request to $url failed: $e');
          continue;
        }
      }
      return null;
    } else {
      // Use the working server
      try {
        Uri uri = Uri.parse('$workingUrl$endpoint');
        http.Response response;

        switch (method.toUpperCase()) {
          case 'POST':
            response = await http
                .post(uri, headers: headers, body: body)
                .timeout(Duration(seconds: 15));
            break;
          case 'GET':
            response = await http
                .get(uri, headers: headers)
                .timeout(Duration(seconds: 15));
            break;
          case 'PUT':
            response = await http
                .put(uri, headers: headers, body: body)
                .timeout(Duration(seconds: 15));
            break;
          case 'DELETE':
            response = await http
                .delete(uri, headers: headers)
                .timeout(Duration(seconds: 15));
            break;
          default:
            throw Exception('Unsupported HTTP method: $method');
        }

        return response;
      } catch (e) {
        print('Request failed: $e');
        return null;
      }
    }
  }

  // Make multipart request for file uploads
  static Future<http.StreamedResponse?> makeMultipartRequest(
    String endpoint, {
    required String method,
    Map<String, String>? headers,
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
  }) async {
    String? workingUrl = await findWorkingServer();

    if (workingUrl == null) {
      // Try all URLs for multipart requests
      for (String url in serverUrls) {
        try {
          var request =
              http.MultipartRequest(method, Uri.parse('$url$endpoint'));

          if (headers != null) {
            request.headers.addAll(headers);
          }

          if (fields != null) {
            request.fields.addAll(fields);
          }

          if (files != null) {
            request.files.addAll(files);
          }

          var response = await request.send().timeout(Duration(seconds: 30));
          return response;
        } catch (e) {
          print('Multipart request to $url failed: $e');
          continue;
        }
      }
      return null;
    } else {
      try {
        var request =
            http.MultipartRequest(method, Uri.parse('$workingUrl$endpoint'));

        if (headers != null) {
          request.headers.addAll(headers);
        }

        if (fields != null) {
          request.fields.addAll(fields);
        }

        if (files != null) {
          request.files.addAll(files);
        }

        var response = await request.send().timeout(Duration(seconds: 30));
        return response;
      } catch (e) {
        print('Multipart request failed: $e');
        return null;
      }
    }
  }

  static String getNetworkErrorMessage() {
    return 'Network error: Unable to connect to any server. Please check:\n'
        '1. Your phone is connected to WiFi\n'
        '2. Your computer and phone are on the same network\n'
        '3. The backend server is running\n'
        '4. Windows Firewall allows connections on port 8080';
  }
}
