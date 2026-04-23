import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../network/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/facility_service.dart';
// 1. Make sure this import is here
import '../../services/booking_service.dart';
import '../../services/user_booking_service.dart';

final getIt = GetIt.instance;

void setupLocator() {
  getIt.registerLazySingleton<FlutterSecureStorage>(() => const FlutterSecureStorage());
  getIt.registerLazySingleton<ApiClient>(() => ApiClient(getIt<FlutterSecureStorage>()));

  getIt.registerLazySingleton<AuthService>(() => AuthService(getIt<ApiClient>(), getIt<FlutterSecureStorage>()));
  getIt.registerLazySingleton<FacilityService>(() => FacilityService(getIt<ApiClient>()));

  // 2. Make sure this line is here!
  getIt.registerLazySingleton<BookingService>(() => BookingService(getIt<ApiClient>()));
  getIt.registerLazySingleton<UserBookingService>(() => UserBookingService(getIt<ApiClient>()));
}