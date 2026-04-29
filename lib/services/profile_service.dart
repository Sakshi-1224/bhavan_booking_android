import 'package:dio/dio.dart';
import '../core/network/api_client.dart';

class ProfileService {
  final ApiClient _apiClient;

  ProfileService(this._apiClient);

  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final response = await _apiClient.dio.get('/auth/me');
      return response.data['data']['user'];
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? e.message);
    } catch (e) {
      throw Exception('App Error: $e');
    }
  }

  Future<bool> changePassword(String oldPassword, String newPassword, String confirmNewPassword) async {
    try {
      final response = await _apiClient.dio.patch(
        '/auth/update-password',
        data: {
          'oldPassword': oldPassword,
          'newPassword': newPassword,
          'confirmNewPassword': confirmNewPassword,
        },
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? e.message);
    } catch (e) {
      throw Exception('App Error: $e');
    }
  }
}