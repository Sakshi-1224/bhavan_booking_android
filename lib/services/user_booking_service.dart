// lib/services/user_booking_service.dart
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';

class UserBookingService {
  final ApiClient _apiClient;

  UserBookingService(this._apiClient);

  Future<Map<String, dynamic>> getMyBookings() async {
    try {
      final response = await _apiClient.dio.get('/bookings/my-bookings');
      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data['data']};
      }
      return {'success': false, 'message': 'Failed to load bookings.'};
    } on DioException catch (e) {
      return {'success': false, 'message': e.response?.data['message'] ?? e.message};
    } catch (e) {
      return {'success': false, 'message': 'App Error: $e'};
    }
  }

  Future<Map<String, dynamic>> uploadAadhaar(String bookingId, String frontPath, String backPath) async {
    try {
      FormData formData = FormData.fromMap({
        'frontImage': await MultipartFile.fromFile(frontPath, filename: 'front.jpg'),
        'backImage': await MultipartFile.fromFile(backPath, filename: 'back.jpg'),
      });

      final response = await _apiClient.dio.post(
        '/bookings/$bookingId/upload-aadhaar',
        data: formData,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Aadhaar uploaded successfully'};
      }
      return {'success': false, 'message': 'Upload failed.'};
    } on DioException catch (e) {
      return {'success': false, 'message': e.response?.data['message'] ?? e.message};
    } catch (e) {
      return {'success': false, 'message': 'App Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createPaymentOrder(String bookingId, String phase, {String paymentOption = 'FULL'}) async {
    try {
      final url = phase == 'INITIAL' ? '/payments/initial/create-order' : '/payments/remaining/create-order';
      final payload = phase == 'INITIAL' ? {'bookingId': bookingId, 'paymentOption': paymentOption} : {'bookingId': bookingId};

      final response = await _apiClient.dio.post(url, data: payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': response.data['data']};
      }
      return {'success': false, 'message': 'Failed to create order.'};
    } on DioException catch (e) {
      return {'success': false, 'message': e.response?.data['message'] ?? e.message};
    }
  }

  Future<Map<String, dynamic>> verifyPayment(String bookingId, String phase, Map<String, dynamic> verificationData) async {
    try {
      final url = phase == 'INITIAL' ? '/payments/initial/verify' : '/payments/remaining/verify';
      verificationData['bookingId'] = bookingId;

      final response = await _apiClient.dio.post(url, data: verificationData);

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Payment verified!'};
      }
      return {'success': false, 'message': 'Verification failed.'};
    } on DioException catch (e) {
      return {'success': false, 'message': e.response?.data['message'] ?? e.message};
    }
  }
}