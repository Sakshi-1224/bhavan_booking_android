// lib/screens/facility_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../core/di/service_locator.dart';
import '../services/booking_service.dart';
import 'booking_form_screen.dart';

class FacilityDetailScreen extends StatefulWidget {
  final Map<String, dynamic> facility;

  const FacilityDetailScreen({super.key, required this.facility});

  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  int _currentImageIndex = 0;

  DateTimeRange? _selectedDateRange;
  DateTime? _singleDate;
  TimeOfDay? _startTime;
  Map<String, dynamic>? _selectedSlot;

  String _getValidImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return '';
    return rawUrl.replaceAll('127.0.0.1', '10.0.2.2').replaceAll('localhost', '10.0.2.2');
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) setState(() => _selectedDateRange = picked);
  }

  Future<void> _selectSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _singleDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _singleDate = picked);
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _startTime = picked);
  }

// Inside lib/screens/facility_detail_screen.dart

  void _proceedToCheckout(bool isHourlyOrFlexible, bool isFixedSlot, int durationHours) async {
    DateTime finalStart; DateTime finalEnd; String finalStartTimeStr; String finalEndTimeStr;

    // ... (Your existing validation logic for Start/End times goes here)
    if (isFixedSlot) {
      if (_singleDate == null || _selectedSlot == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a date and a time slot.')));
        return;
      }
      finalStart = _singleDate!; finalEnd = _singleDate!; finalStartTimeStr = _selectedSlot!['startTime']; finalEndTimeStr = _selectedSlot!['endTime'];
    } else if (isHourlyOrFlexible) {
      if (_singleDate == null || _startTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an event date and start time.')));
        return;
      }
      DateTime startDt = DateTime(_singleDate!.year, _singleDate!.month, _singleDate!.day, _startTime!.hour, _startTime!.minute);
      DateTime endDt = startDt.add(Duration(hours: durationHours));
      finalStart = startDt; finalEnd = endDt; finalStartTimeStr = _formatTimeOfDay(TimeOfDay.fromDateTime(startDt)); finalEndTimeStr = _formatTimeOfDay(TimeOfDay.fromDateTime(endDt));
    } else {
      if (_selectedDateRange == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your event dates.')));
        return;
      }
      finalStart = _selectedDateRange!.start; finalEnd = _selectedDateRange!.end;
      if (finalEnd.isAtSameMomentAs(finalStart)) { finalEnd = finalEnd.add(const Duration(days: 1)); }
      finalStartTimeStr = "10:00"; finalEndTimeStr = "08:00";
    }

    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    final bookingService = getIt<BookingService>();
    final result = await bookingService.checkAvailabilityAndPrice(
      facilityId: widget.facility['id'],
      startDate: finalStart, endDate: finalEnd, startTime: finalStartTimeStr, endTime: finalEndTimeStr,
    );

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (result['success']) {
      final responseData = result['data'];

      // 🚨 SAFE EXTRACTION OF API FLAGS
      final bool isAvailable = responseData['isAvailable'] == true;
      final bool isPartiallyAvailable = responseData['isPartiallyAvailable'] == true;

      // 1. FULLY AVAILABLE (Works perfectly!)
      if (isAvailable) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookingFormScreen(
              facility: widget.facility, startDate: finalStart, endDate: finalEnd,
              startTime: finalStartTimeStr, endTime: finalEndTimeStr,
              pricingData: responseData['pricing'] ?? {},
            ),
          ),
        );
      }
      // 2. PARTIALLY AVAILABLE (Launch the Orange Bottom Sheet)
      else if (isPartiallyAvailable) {
        _showPartialAvailabilitySheet(responseData, finalStart, finalEnd, finalStartTimeStr, finalEndTimeStr);
      }
      // 3. FULLY BOOKED (Show a safe snackbar without crashing)
      else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message'] ?? 'Dates are fully booked.'), backgroundColor: Colors.redAccent)
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.redAccent));
    }
  }

  // 🚨 THE NEW REACT-STYLE PARTIAL UI BOTTOM SHEET
  void _showPartialAvailabilitySheet(Map<String, dynamic> data, DateTime sDate, DateTime eDate, String sTime, String eTime) {
    final alternatives = data['availableAlternatives'] as List<dynamic>? ?? [];

    // Calculate new total just like React does
    double newTotal = 0;
    for (var alt in alternatives) {
      newTotal += double.tryParse(alt['baseRate']?.toString() ?? '0') ?? 0;
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
                Text('Some items are booked. We can offer this alternative package:', style: TextStyle(color: Colors.orange.shade900)),
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
                          Expanded(child: Text(alt['name'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87))),
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
                    Text('New Total (Base):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 16)),
                    Text('₹$newTotal', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.orange.shade900)),
                  ],
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close the sheet

                      // Mock a pricing map for the form
                      Map<String, dynamic> pseudoPricing = {
                        'baseCalculatedAmount': newTotal,
                        'securityDepositRequired': 0, // Fallback since partial doesn't return this
                        'estimatedTotal': newTotal,
                      };

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookingFormScreen(
                            facility: widget.facility,
                            startDate: sDate, endDate: eDate, startTime: sTime, endTime: eTime,
                            pricingData: pseudoPricing,
                            isPartial: true, // FLAG SET TO TRUE
                            partialAlternatives: alternatives,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Accept Partial & Book', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // --- DYNAMIC UI RENDERERS ---

  Widget _buildFixedDateSelector() {
    String dateDisplay = 'Select Check-in & Check-out';

    if (_selectedDateRange != null) {
      DateTime start = _selectedDateRange!.start;
      DateTime end = _selectedDateRange!.end;
      if (end.isAtSameMomentAs(start)) {
        end = end.add(const Duration(days: 1));
      }
      int displayDays = end.difference(start).inDays;
      dateDisplay = '${DateFormat('MMM dd').format(start)} - ${DateFormat('MMM dd, yyyy').format(end)} ($displayDays ${displayDays == 1 ? "Day" : "Days"})';
    }

    return InkWell(
      onTap: _selectDateRange,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12), color: Colors.grey.shade50),
        child: Row(
          children: [
            Icon(Icons.calendar_month, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Event Dates', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    dateDisplay,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildFlexibleSelector(int durationHours) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Required Duration: ', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
              Text('$durationHours Hours', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 16),
          _buildSingleDateBox(),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectStartTime,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border.all(color: Colors.blue.shade300), borderRadius: BorderRadius.circular(12), color: Colors.white),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Select Start Time', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_startTime != null ? _startTime!.format(context) : 'Tap to select', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_startTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'Check-out will be automatically calculated as $durationHours hours from ${_startTime!.format(context)}.',
                  style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildSlotSelector(List<dynamic> slots) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSingleDateBox(),
        const SizedBox(height: 16),
        const Text('Select Available Shift', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Column(
          children: slots.map((slot) {
            final isSelected = _selectedSlot != null && _selectedSlot!['id'] == slot['id'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: InkWell(
                onTap: () => setState(() => _selectedSlot = slot),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.shade50 : Colors.white,
                    border: Border.all(color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300, width: isSelected ? 2 : 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slot['label'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('${slot['startTime']} to ${slot['endTime']}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        )
      ],
    );
  }

  Widget _buildSingleDateBox() {
    return InkWell(
      onTap: _selectSingleDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12), color: Colors.white),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _singleDate != null ? DateFormat('EEEE, MMM dd, yyyy').format(_singleDate!) : 'Select Event Date',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Icon(Icons.edit, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final facility = widget.facility;
    final name = facility['name'] ?? 'Unknown Facility';
    final description = facility['description'] ?? 'No description available.';

    final price = facility['baseRate']?.toString() ?? facility['basePrice']?.toString() ?? facility['price']?.toString() ?? '0';
    final capacity = facility['maxCapacity']?.toString() ?? facility['capacity']?.toString();

    final pricingType = facility['pricingType'] ?? 'FIXED';
    final pricingDetails = facility['pricingDetails'] ?? {};
    final slotType = pricingDetails['slotType'];
    final slots = pricingDetails['slots'] as List<dynamic>? ?? [];
    final int durationHours = int.tryParse(pricingDetails['durationHours']?.toString() ?? '1') ?? 1;

    bool isHourlyOrFlexible = pricingType == 'HOURLY' || (pricingType == 'SLOT' && slotType == 'FLEXIBLE');
    bool isFixedSlot = pricingType == 'SLOT' && slotType == 'FIXED' && slots.isNotEmpty;

    List<String> validImages = (facility['images'] as List<dynamic>? ?? []).map((url) => _getValidImageUrl(url as String)).where((url) => url.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0, pinned: true, backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: validImages.isNotEmpty
                  ? PageView.builder(
                  itemCount: validImages.length,
                  onPageChanged: (idx) => setState(() => _currentImageIndex = idx),
                  itemBuilder: (c, i) => CachedNetworkImage(imageUrl: validImages[i], fit: BoxFit.cover)
              )
                  : Container(color: Colors.grey[200], child: const Icon(Icons.apartment, size: 80, color: Colors.grey)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.2))),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₹$price', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
                          const Text('/ base rate', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (capacity != null && capacity.isNotEmpty && capacity != 'null') ...[
                    Row(
                      children: [
                        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.indigo.shade50, shape: BoxShape.circle), child: Icon(Icons.people_alt, color: Colors.indigo.shade700, size: 20)),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Maximum Capacity', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Text('Up to $capacity guests', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 48),
                  ],
                  const Text('About this package', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(description, style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.6)),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),

                  // 🚨 FIX: MOVED THE DYNAMIC BOOKING UI HERE (Inside the scrollable body)
                  const Text('Select Your Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  if (isFixedSlot)
                    _buildSlotSelector(slots)
                  else if (isHourlyOrFlexible)
                    _buildFlexibleSelector(durationHours)
                  else
                    _buildFixedDateSelector(),

                  const SizedBox(height: 40), // Extra padding so it's not hidden behind the checkout button
                ],
              ),
            ),
          ),
        ],
      ),

      // 🚨 FIX: ONLY THE "PROCEED" BUTTON REMAINS STICKY
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), // Reduced padding
        decoration: BoxDecoration(color: Colors.white, boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))], borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _proceedToCheckout(isHourlyOrFlexible, isFixedSlot, durationHours),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Proceed to Checkout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}