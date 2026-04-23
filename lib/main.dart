import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/di/service_locator.dart';
import 'screens/login_screen.dart';

void main() {
  // Ensure bindings are initialized before setting up the locator
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependency injection
  setupLocator();

  runApp(const BhavanBookingApp());
}

class BhavanBookingApp extends StatelessWidget {
  const BhavanBookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bhavan Booking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F172A)),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}