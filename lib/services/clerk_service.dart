// lib/services/clerk_service.dart
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';

class ClerkService {
  final ApiClient _apiClient;

  ClerkService(this._apiClient);

  // ==========================================================
  // ADMIN AUTH ROUTES (Mapped from admin.auth.routes.js)
  // ==========================================================

  /// Fetch the list of all bookings
  Future<List<dynamic>> getAllBookings() async {
    try {
      final response = await _apiClient.dio.get('/auth/admin/bookings');
      return response.data['data'] ?? [];
    } catch (e) {
      throw Exception('Failed to fetch bookings: $e');
    }
  }

  /// Fetch full comprehensive details of a single booking
  Future<Map<String, dynamic>> getBookingDetails(String bookingId) async {
    try {
      final response = await _apiClient.dio.get('/auth/admin/bookings/$bookingId');
      return response.data['data'] ?? {};
    } catch (e) {
      throw Exception('Failed to fetch booking details: $e');
    }
  }

  /// Verify a booking (Clerk Action Only)
  Future<bool> verifyBooking(String bookingId) async {
    try {
      final response = await _apiClient.dio.patch('/auth/admin/bookings/$bookingId/verify');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }


  // ==========================================================
  // BOOKING ROUTES (Mapped from booking.routes.js)
  // ==========================================================

  /// Reject a booking (Clerk/Admin Action)
  Future<bool> rejectBooking(String bookingId) async {
    try {
      final response = await _apiClient.dio.patch('/bookings/$bookingId/reject');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Check-in a guest with allocated rooms
  Future<bool> checkIn(String bookingId, bool securityDepositCollected) async {
    try {
      final response = await _apiClient.dio.patch(
        '/bookings/$bookingId/check-in',
        data: {
          'securityDepositCollected': securityDepositCollected
        },
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? e.message);
    } catch (e) {
      throw Exception('App Error: $e');
    }
  }

  /// Check-out a guest
  Future<bool> checkOut(String bookingId) async {
    try {
      final response = await _apiClient.dio.patch('/bookings/$bookingId/check-out');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }


  /// Complete manual refund directly (Cash/Bank) - Bypass Credit Notes entirely
  Future<bool> completeManualRefund(String bookingId, String refundMode, String remarks) async {
    try {
      final response = await _apiClient.dio.patch(
        '/bookings/$bookingId/complete-manual-refund',
        data: {
          'refundMode': refundMode,
          'remarks': remarks
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchInvoiceIfExists(String bookingId) async {
    try {
      final response = await _apiClient.dio.get('/billing/$bookingId/invoice');
      // Extract the 'invoice' object from the backend response payload
      return response.data['data']?['invoice'] ?? response.data['data'];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null; // No draft exists yet
      }
      throw Exception('Failed to fetch invoice: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      throw Exception('App Error: $e');
    }
  }

  /// Check-out a guest and finalize the booking state
  Future<bool> generateDraftInvoice(Map<String, dynamic> invoiceData) async {
    try {
      final response = await _apiClient.dio.post(
        '/billing/draft-invoice',
        data: invoiceData,
      );
      return response.statusCode == 201; // Backend returns 201 Created
    } on DioException catch (e) {
      final errorMsg = e.response?.data['message'] ?? e.message;
      throw Exception('Failed to generate draft: $errorMsg');
    } catch (e) {
      throw Exception('App error: $e');
    }
  }

  Future<bool> recordOfflineAdvance(String bookingId, String paymentMode, double amountCollected, String paymentOption) async {
    try {
      final response = await _apiClient.dio.post(
        '/payments/advance/offline',
        data: {
          'bookingId': bookingId,
          'paymentMode': paymentMode,
          'amountCollected': amountCollected,
          'paymentOption': paymentOption, // 'HOLD' or 'FULL'
        },
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? e.message);
    } catch (e) {
      throw Exception('App Error: $e');
    }
  }

  /// STAFF: Records an offline (Cash/UPI) remaining balance payment
  Future<bool> recordOfflineRemaining(String bookingId, String paymentMode, double amountCollected) async {
    try {
      final response = await _apiClient.dio.post(
        '/payments/offline-remaining',
        data: {
          'bookingId': bookingId,
          'paymentMode': paymentMode,
          'amountCollected': amountCollected,
        },
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? e.message);
    } catch (e) {
      throw Exception('App Error: $e');
    }
  }

  Future<bool> uploadKycOnBehalf(String bookingId, String frontImagePath, String backImagePath) async {
    try {
      final formData = FormData.fromMap({
        'frontImage': await MultipartFile.fromFile(
            frontImagePath, filename: 'front.jpg'),
        'backImage': await MultipartFile.fromFile(
            backImagePath, filename: 'back.jpg'),
      });

      // Matches your backend route: /admin/:bookingId/upload-aadhaar
      final response = await _apiClient.dio.patch(
        '/bookings/admin/$bookingId/upload-aadhaar',
        data: formData,
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? e.message);
    } catch (e) {
      throw Exception('App Error: $e');
    }
  }

  Future<Map<String, dynamic>> getSystemSettings() async {
    try {
      // Hits the settings route defined in your routes/v1/index.js
      final response = await _apiClient.dio.get('/settings/taxes');
      // If your backend returns an array, take the first item, else take the object
      if (response.data['data'] is List && response.data['data'].isNotEmpty) {
        return response.data['data'][0];
      }
      return response.data['data'] ?? {};
    } catch (e) {
      // Safely fallback to database defaults if the route fails or isn't accessible
      return {'cgstPercentage': 2.5, 'sgstPercentage': 2.5};
    }
  }

}


