// lib/screens/clerk_dashboard_screen.dart
import 'package:flutter/material.dart';
import '../core/di/service_locator.dart';
import '../services/clerk_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'clerk_booking_detail_screen.dart';
import 'profile_screen.dart';
class ClerkDashboardScreen extends StatefulWidget {
  const ClerkDashboardScreen({super.key});

  @override
  State<ClerkDashboardScreen> createState() => _ClerkDashboardScreenState();
}

class _ClerkDashboardScreenState extends State<ClerkDashboardScreen> {
  final _clerkService = getIt<ClerkService>();
  final _authService = getIt<AuthService>();
  late Future<List<dynamic>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  void _fetchBookings() {
    setState(() {
      _bookingsFuture = _clerkService.getAllBookings();
    });
  }

  void _handleLogout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Clerk Portal', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 1,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchBookings),
          IconButton(
            icon: const Icon(Icons.account_circle, size: 28),
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), onPressed: _handleLogout)
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _bookingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text('Failed to load queue. Please check network.'));
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Queue is empty.'));

          final bookings = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async => _fetchBookings(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                final booking = bookings[index];

                // Safely extract from nested user object
                final user = booking['user'] ?? {};
                final userName = user['fullName'] ?? 'Unknown Guest';
                final userMobile = user['phone'] ?? 'No Contact';


                return Card(
                  color: Colors.white,
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ClerkBookingDetailScreen(bookingId: booking['id']),
                        ),
                      ).then((_) => _fetchBookings()); // Refresh queue when returning
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ID: ${booking['id'].toString().substring(0, 8)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                              Chip(
                                label: Text(booking['status'] ?? 'PENDING', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                backgroundColor: _getStatusColor(booking['status']).withOpacity(0.15),
                                side: BorderSide.none,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Contact: $userMobile', style: TextStyle(color: Colors.grey.shade700)),
                          const SizedBox(height: 12),
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Text('View Full Details →', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'PENDING': return Colors.orange;
      case 'CLERK_VERIFIED': return Colors.blue;
      case 'CONFIRMED': return Colors.green;
      case 'CHECKED_IN': return Colors.teal;
      case 'REJECTED': return Colors.red;
      case 'CANCELLATION_REQUESTED': return Colors.deepOrange;
      case 'REFUND_PENDING': return Colors.deepOrangeAccent;
      default: return Colors.grey;
    }
  }
}