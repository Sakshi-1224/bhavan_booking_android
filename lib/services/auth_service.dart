import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';

class AuthService {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  AuthService(this._apiClient, this._storage);

  Future<Map<String, dynamic>> login(String mobile, String password) async {
    try {
      final response = await _apiClient.dio.post('/auth/user/login', data: {
        'mobile': mobile,
        'password': password,
      });

      if (response.statusCode == 200) {
        final token = response.data['data']['token'];
        if (token != null) {
          await _storage.write(key: 'jwt_token', value: token);
          return {'success': true, 'message': 'Login Successful'};
        }
        return {'success': false, 'message': 'Token not found in response'};
      }
      return {'success': false, 'message': 'Login failed'};
    } on DioException catch (e) {
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
  Future<void> logout() async => await _storage.delete(key: 'jwt_token');
}