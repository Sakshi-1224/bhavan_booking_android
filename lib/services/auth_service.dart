// lib/services/auth_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';

class AuthService {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  AuthService(this._apiClient, this._storage);

  /// Single portal login that attempts Admin, then Clerk, then User endpoints.
  Future<Map<String, dynamic>> login(String mobile, String password) async {
    // 1. Attempt Admin Login First
    var result = await _attemptLogin('/auth/admin/login', mobile, password, 'ADMIN');
    if (result['success']) return result;

    // 2. Fallback to Clerk Login
    result = await _attemptLogin('/auth/admin/clerk/login', mobile, password, 'CLERK');
    if (result['success']) return result;

    // 3. Fallback to Standard User Login
    result = await _attemptLogin('/auth/user/login', mobile, password, 'USER');
    return result;
  }

  // Private helper method to handle the API calls
  Future<Map<String, dynamic>> _attemptLogin(String endpoint, String mobile, String password, String expectedRole) async {
    try {
      final response = await _apiClient.dio.post(endpoint, data: {
        'mobile': mobile,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data['data'];
        final token = data['token'];
        final role = data['user']['role'] ?? expectedRole;

        if (token != null) {
          await _storage.write(key: 'jwt_token', value: token);
          await _storage.write(key: 'user_role', value: role);

          return {
            'success': true,
            'message': response.data['message'] ?? 'Login Successful',
            'role': role
          };
        }
      }
      return {'success': false, 'message': 'Token missing in response'};
    } on DioException catch (e) {
      // If it's a 401 or 404, we just let it fail silently so the next waterfall step can run
      final errorMessage = e.response?.data['message'] ?? e.message;
      return {'success': false, 'message': errorMessage};
    } catch (e) {
      return {'success': false, 'message': 'App Error: $e'};
    }
  }

  Future<Map<String, dynamic>> register({required String name, required String mobile, required String password}) async {
    try {
      final response = await _apiClient.dio.post('/auth/user/register', data: {
        'fullName': name,
        'mobile': mobile,
        'password': password,
      });

      if (response.statusCode == 201) {
        return {'success': true, 'message': 'Registration Successful'};
      }
      return {'success': false, 'message': 'Registration failed'};
    } on DioException catch (e) {
      final errorMessage = e.response?.data['message'] ?? e.message;
      return {'success': false, 'message': errorMessage};
    } catch (e) {
      return {'success': false, 'message': 'App Error: $e'};
    }
  }

  Future<String?> getToken() async => await _storage.read(key: 'jwt_token');
  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_role');
  }
}