// lib/services/booking_service.dart
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import 'package:intl/intl.dart';

class BookingService {
  final ApiClient _apiClient;

  BookingService(this._apiClient);

  DateTime _combineDateTime(DateTime date, String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  Future<Map<String, dynamic>> checkAvailabilityAndPrice({
    String? facilityId, // Changed to optional
    required DateTime startDate,
    required DateTime endDate,
    required String startTime,
    required String endTime,
    List<Map<String, dynamic>>? customFacilities, // ADDED for custom bookings
  }) async {
    try {
      DateTime startIso = _combineDateTime(startDate, startTime);
      DateTime endIso = _combineDateTime(endDate, endTime);

      if (!endIso.isAfter(startIso)) {
        endIso = endIso.add(const Duration(days: 1));
      }

      // Build payload dynamically based on backend requirements
      final Map<String, dynamic> payload = {
        'startDate': DateFormat('yyyy-MM-dd').format(startIso),
        'endDate': DateFormat('yyyy-MM-dd').format(endIso),
        'startTime': startIso.toUtc().toIso8601String(),
        'endTime': endIso.toUtc().toIso8601String(),
      };

      if (facilityId != null && facilityId.isNotEmpty) {
        payload['facilityId'] = facilityId;
      }

      if (customFacilities != null && customFacilities.isNotEmpty) {
        payload['customFacilities'] = customFacilities;
      }

      final response = await _apiClient.dio.post(
        '/bookings/check-availability',
        data: payload,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data['data']};
      }
      return {'success': false, 'message': 'Failed to verify availability.'};
    } on DioException catch (e) {
      String errorMessage = 'Server error: ${e.response?.statusCode}';
      if (e.response?.data is Map && e.response?.data['message'] != null) {
        errorMessage = e.response?.data['message'];
      }
      return {'success': false, 'message': errorMessage};
    } catch (e) {
      return {'success': false, 'message': 'App Error: $e'};
    }
  }

  // Ensure requestBooking allows facilityId to be nullable as well
  Future<Map<String, dynamic>> requestBooking({
    String? facilityId,
    required DateTime startDate,
    required DateTime endDate,
    required String startTime,
    required String endTime,
    required String eventPurpose,
    required int totalGuests,
    List<Map<String, dynamic>>? customFacilities,
  }) async {
    try {
      DateTime startIso = _combineDateTime(startDate, startTime);
      DateTime endIso = _combineDateTime(endDate, endTime);

      if (!endIso.isAfter(startIso)) {
        endIso = endIso.add(const Duration(days: 1));
      }

      final Map<String, dynamic> payload = {
        'facilityId': facilityId,
        'startDate': DateFormat('yyyy-MM-dd').format(startIso),
        'endDate': DateFormat('yyyy-MM-dd').format(endIso),
        'startTime': startIso.toUtc().toIso8601String(),
        'endTime': endIso.toUtc().toIso8601String(),
        'eventType': eventPurpose,
        'guestCount': totalGuests,
      };

      // If it's a partial booking, attach the alternative items just like the React frontend does
      if (customFacilities != null && customFacilities.isNotEmpty) {
        payload['customFacilities'] = customFacilities;
      }

      final response = await _apiClient.dio.post('/bookings', data: payload);

      if (response.statusCode == 201) {
        return {'success': true, 'data': response.data['data']};
      }
      return {'success': false, 'message': 'Failed to request booking.'};
    } on DioException catch (e) {
      String errorMessage = 'Server error: ${e.response?.statusCode}';
      if (e.response?.data is Map && e.response?.data['message'] != null) {
        errorMessage = e.response?.data['message'];
      }
      return {'success': false, 'message': errorMessage};
    } catch (e) {
      return {'success': false, 'message': 'App Error: $e'};
    }
  }
}