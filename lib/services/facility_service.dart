import '../core/network/api_client.dart';

class FacilityService {
  final ApiClient _apiClient;

  FacilityService(this._apiClient);

  Future<List<dynamic>> getFacilities() async {
    try {
      final response = await _apiClient.dio.get('/facilities');

      if (response.statusCode == 200) {
        return response.data['data'] ?? [];
      }
      return [];
    } catch (e) {
      print("Error fetching facilities: $e");
      throw Exception('Failed to load facilities');
    }
  }
}