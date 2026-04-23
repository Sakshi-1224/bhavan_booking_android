// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/di/service_locator.dart';
import '../services/facility_service.dart';
import '../services/auth_service.dart';
import '../widgets/facility_card.dart';
import '../widgets/custom_builder_card.dart';
import 'custom_facility_screen.dart';
import 'login_screen.dart';
import 'facility_detail_screen.dart';
import 'my_bookings_screen.dart';
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _facilityService = getIt<FacilityService>();
  final _authService = getIt<AuthService>();

  late Future<List<dynamic>> _facilitiesFuture;

  @override
  void initState() {
    super.initState();
    _fetchFacilities();
  }

  void _fetchFacilities() {
    setState(() {
      _facilitiesFuture = _facilityService.getFacilities();
    });
  }

  void _handleLogout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(20.0),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            height: 350,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Bhavan Packages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withOpacity(0.3),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long, color: Colors.indigo),
            tooltip: 'My Bookings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyBookingsScreen()),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), onPressed: _handleLogout)
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _facilitiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return _buildShimmerLoading();
          if (snapshot.hasError) return const Center(child: Text('Failed to load facilities'));
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No data'));

          final allFacilities = snapshot.data!;

          // FILTERING LOGIC
          // Packages & Complexes go to the main feed
          final packages = allFacilities.where((f) =>
          f['facilityType'] == 'PACKAGE' || f['facilityType'] == 'COMPLEX'
          ).toList();

          // Everything else (Rooms, Halls, Lawns, Mattresses) goes to the Custom Screen
          final atomicFacilities = allFacilities.where((f) =>
          f['facilityType'] != 'PACKAGE' && f['facilityType'] != 'COMPLEX'
          ).toList();

          return RefreshIndicator(
            onRefresh: () async => _fetchFacilities(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              // +1 for the Custom Builder Card at the top
              itemCount: packages.length + 1,
              itemBuilder: (context, index) {

                // TOP ITEM: Custom Builder Card
                if (index == 0) {
                  return CustomBuilderCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomFacilityScreen(atomicFacilities: atomicFacilities),
                        ),
                      );
                    },
                  );
                }

                // REMAINING ITEMS: Standard Packages
                final packageData = packages[index - 1]; // Offset by 1
                return FacilityCard(
                  facility: packageData,
                    onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FacilityDetailScreen(facility: packageData),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}