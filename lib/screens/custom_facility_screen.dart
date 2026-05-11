// lib/screens/custom_facility_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../core/config/app_config.dart';
import '../core/di/service_locator.dart';
import '../services/booking_service.dart';
import 'booking_form_screen.dart';

class CustomFacilityScreen extends StatefulWidget {
  final List<dynamic> atomicFacilities;

  const CustomFacilityScreen({super.key, required this.atomicFacilities});

  @override
  State<CustomFacilityScreen> createState() => _CustomFacilityScreenState();
}

class _CustomFacilityScreenState extends State<CustomFacilityScreen> {
  final Map<String, int> _selectedQuantities = {};

  String _getValidImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return '';
    return rawUrl
        .replaceAll('127.0.0.1', AppConfig.apiHost)
        .replaceAll('localhost', AppConfig.apiHost);
  }

  // Robust parsing to fix the 0 price issue locally
  double get _totalEstimatedPrice {
    double total = 0;
    for (var facility in widget.atomicFacilities) {
      final id = facility['id'];
      final qty = _selectedQuantities[id] ?? 0;
      if (qty > 0) {
        double price = 0.0;
        final rawRate = facility['baseRate'];
        if (rawRate is num) {
          price = rawRate.toDouble();
        } else if (rawRate is String) {
          price = double.tryParse(rawRate) ?? 0.0;
        }
        total += (price * qty);
      }
    }
    return total;
  }

  void _updateQuantity(String id, int delta, int maxLimit) {
    setState(() {
      int current = _selectedQuantities[id] ?? 0;
      int next = current + delta;
      if (next >= 0 && next <= maxLimit) {
        _selectedQuantities[id] = next;
      }
    });
  }

  // --- NEW: THE ORANGE PARTIAL AVAILABILITY SHEET ---
  void _showCustomPartialAvailabilitySheet(Map<String, dynamic> data, DateTime sDate, DateTime eDate, String sTime, String eTime) {
    final alternatives = data['availableAlternatives'] as List<dynamic>? ?? [];

    double newTotal = 0;
    for (var alt in alternatives) {
      double rate = double.tryParse(alt['baseRate']?.toString() ?? '0') ?? 0.0;
      int qty = int.tryParse(alt['quantity']?.toString() ?? '1') ?? 1;
      newTotal += (rate * qty);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.orange.shade200, width: 2),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 28),
                    const SizedBox(width: 12),
                    Text('Partial Availability', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Some items in your custom package are booked for these dates. We can offer this adjusted package:', style: TextStyle(color: Colors.orange.shade900)),
                const SizedBox(height: 16),

                // List of available items
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                  child: Column(
                    children: alternatives.map((alt) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: Text(
                                  '${alt['name'] ?? 'Item'} (x${alt['quantity'] ?? 1})',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)
                              )
                          ),
                          Text('₹${alt['baseRate']}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                        ],
                      ),
                    )).toList(),
                  ),
                ),

                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('New Total (Base):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 16), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Text('₹$newTotal', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.orange.shade900)),
                  ],
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close the orange sheet

                      // Mock a pricing map for the form
                      Map<String, dynamic> pseudoPricing = {
                        'baseCalculatedAmount': newTotal,
                        'securityDepositRequired': 0, // Fallback
                        'estimatedTotal': newTotal,
                      };

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookingFormScreen(
                            facility: const {'id': 'custom', 'name': 'Adjusted Custom Package'},
                            startDate: sDate, endDate: eDate, startTime: sTime, endTime: eTime,
                            pricingData: pseudoPricing,
                            isPartial: true,
                            partialAlternatives: alternatives,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Accept Available Items & Book', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // --- DATE/TIME SELECTION & AVAILABILITY CHECK ---
  void _showDateSelectionSheet(List<Map<String, dynamic>> selectedFacilities) {
    DateTime startDate = DateTime.now().add(const Duration(days: 1));
    DateTime endDate = DateTime.now().add(const Duration(days: 2));
    TimeOfDay startTime = const TimeOfDay(hour: 10, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);
    bool isChecking = false;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                Future<void> pickDate(bool isStart) async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: isStart ? startDate : endDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setModalState(() {
                      if (isStart) startDate = picked;
                      else endDate = picked;
                      if (endDate.isBefore(startDate)) endDate = startDate;
                    });
                  }
                }

                Future<void> pickTime(bool isStart) async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: isStart ? startTime : endTime,
                  );
                  if (picked != null) {
                    setModalState(() {
                      if (isStart) startTime = picked;
                      else endTime = picked;
                    });
                  }
                }

                return Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
                      left: 24, right: 24, top: 24
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Dates & Time', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),

                      // Start Date & Time
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Check-in Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              subtitle: Text(DateFormat('MMM dd, yyyy').format(startDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: const Icon(Icons.calendar_today, size: 20, color: Colors.green),
                              onTap: () => pickDate(true),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Check-in Time', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              subtitle: Text(startTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: const Icon(Icons.access_time, size: 20, color: Colors.green),
                              onTap: () => pickTime(true),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),

                      // End Date & Time
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Check-out Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              subtitle: Text(DateFormat('MMM dd, yyyy').format(endDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: const Icon(Icons.calendar_today, size: 20, color: Colors.redAccent),
                              onTap: () => pickDate(false),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Check-out Time', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              subtitle: Text(endTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: const Icon(Icons.access_time, size: 20, color: Colors.redAccent),
                              onTap: () => pickTime(false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // VERIFY AVAILABILITY BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Theme.of(this.context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          onPressed: isChecking ? null : () async {
                            setModalState(() => isChecking = true);

                            final startTimeStr = "${startTime.hour.toString().padLeft(2,'0')}:${startTime.minute.toString().padLeft(2,'0')}";
                            final endTimeStr = "${endTime.hour.toString().padLeft(2,'0')}:${endTime.minute.toString().padLeft(2,'0')}";

                            final response = await getIt<BookingService>().checkAvailabilityAndPrice(
                              customFacilities: selectedFacilities,
                              startDate: startDate, endDate: endDate,
                              startTime: startTimeStr, endTime: endTimeStr,
                            );

                            setModalState(() => isChecking = false);

                            if (response['success']) {
                              final responseData = response['data'];

                              // Safely extract backend flags
                              final bool isAvailable = responseData['isAvailable'] == true;
                              final bool isPartiallyAvailable = responseData['isPartiallyAvailable'] == true;

                              Navigator.pop(ctx); // Close Date Sheet FIRST

                              // 1. FULLY AVAILABLE
                              if (isAvailable) {
                                Navigator.push(
                                    this.context,
                                    MaterialPageRoute(
                                        builder: (_) => BookingFormScreen(
                                          facility: const {'id': 'custom', 'name': 'Custom Package'},
                                          startDate: startDate, endDate: endDate,
                                          startTime: startTimeStr, endTime: endTimeStr,
                                          pricingData: responseData,
                                          isPartial: true,
                                          partialAlternatives: selectedFacilities,
                                        )
                                    )
                                );
                              }
                              // 2. PARTIALLY AVAILABLE (Trigger the Orange Bottom Sheet!)
                              else if (isPartiallyAvailable) {
                                _showCustomPartialAvailabilitySheet(responseData, startDate, endDate, startTimeStr, endTimeStr);
                              }
                              // 3. FULLY BOOKED
                              else {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(content: Text(responseData['message'] ?? 'Dates are fully booked.'), backgroundColor: Colors.redAccent)
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(content: Text(response['message'] ?? 'Failed to verify dates.'), backgroundColor: Colors.redAccent)
                              );
                            }
                          },
                          child: isChecking
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Check Availability & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                );
              }
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Custom Booking', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.atomicFacilities.length,
              itemBuilder: (context, index) {
                final facility = widget.atomicFacilities[index];
                final id = facility['id'];
                final name = facility['name'];

                double displayPrice = 0.0;
                final rawRate = facility['baseRate'];
                if (rawRate is num) displayPrice = rawRate.toDouble();
                else if (rawRate is String) displayPrice = double.tryParse(rawRate) ?? 0.0;

                final inventoryCount = facility['inventoryCount'] ?? 1;

                String? rawImageUrl = (facility['images'] != null && facility['images'].isNotEmpty) ? facility['images'][0] : null;
                final validImageUrl = _getValidImageUrl(rawImageUrl);

                final isSelected = (_selectedQuantities[id] ?? 0) > 0;
                final qty = _selectedQuantities[id] ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: isSelected ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Container(
                          height: 80, width: 80,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.grey[200]),
                          clipBehavior: Clip.antiAlias,
                          child: validImageUrl.isNotEmpty
                              ? CachedNetworkImage(imageUrl: validImageUrl, fit: BoxFit.cover)
                              : const Icon(Icons.apartment, color: Colors.grey),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('₹${displayPrice.toStringAsFixed(2)}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        inventoryCount > 1
                            ? Row(
                          children: [
                            IconButton(icon: const Icon(Icons.remove_circle_outline), color: qty > 0 ? Colors.redAccent : Colors.grey, onPressed: () => _updateQuantity(id, -1, inventoryCount)),
                            Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(icon: const Icon(Icons.add_circle_outline), color: qty < inventoryCount ? Theme.of(context).colorScheme.primary : Colors.grey, onPressed: () => _updateQuantity(id, 1, inventoryCount)),
                          ],
                        )
                            : Checkbox(value: isSelected, activeColor: Theme.of(context).colorScheme.primary, onChanged: (val) => setState(() => _selectedQuantities[id] = (val == true) ? 1 : 0)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // BOTTOM STICKY BAR
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Estimated Total', style: TextStyle(color: Colors.grey, fontSize: 14), overflow: TextOverflow.ellipsis),
                        Text('₹$_totalEstimatedPrice', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _totalEstimatedPrice > 0 ? () {
                      final List<Map<String, dynamic>> selectedFacilities = [];
                      _selectedQuantities.forEach((id, qty) {
                        if (qty > 0) selectedFacilities.add({'facilityId': id, 'quantity': qty});
                      });
                      _showDateSelectionSheet(selectedFacilities);
                    } : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}