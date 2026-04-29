// lib/screens/booking_form_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/di/service_locator.dart';
import '../services/booking_service.dart';

class BookingFormScreen extends StatefulWidget {
  final Map<String, dynamic> facility;
  final DateTime startDate;
  final DateTime endDate;
  final String startTime;
  final String endTime;
  final Map<String, dynamic> pricingData;

  // VARIABLES FOR PARTIAL/CUSTOM FLOW
  final bool isPartial;
  final List<dynamic>? partialAlternatives;

  const BookingFormScreen({
    super.key,
    required this.facility,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.pricingData,
    this.isPartial = false,
    this.partialAlternatives,
  });

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bookingService = getIt<BookingService>();
  final _purposeController = TextEditingController();
  final _guestsController = TextEditingController();
  bool _isSubmitting = false;

  void _handleRequestBooking() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    // MAPPING ALTERNATIVES FOR THE BACKEND
    List<Map<String, dynamic>>? customs;
    if (widget.isPartial && widget.partialAlternatives != null) {
      // Explicitly cast to Map<String, dynamic> to prevent Dio serialization errors
      customs = widget.partialAlternatives!.map<Map<String, dynamic>>((alt) => {
        'facilityId': alt['facilityId'] ?? alt['id'],
        'quantity': alt['quantity'] ?? 1
      }).toList();
    }

    // Determine facilityId: if it's a purely custom booking with a dummy facility, pass null.
    // Otherwise, pass the actual facility ID.
    String? targetFacilityId = widget.facility['id'];
    if (widget.isPartial && (targetFacilityId == 'custom' || targetFacilityId == null)) {
      targetFacilityId = null;
    }

    final result = await _bookingService.requestBooking(
      facilityId: targetFacilityId,
      startDate: widget.startDate,
      endDate: widget.endDate,
      startTime: widget.startTime,
      endTime: widget.endTime,
      eventPurpose: _purposeController.text.trim(),
      totalGuests: int.parse(_guestsController.text.trim()),
      customFacilities: customs, // Attach mapped partials!
    );

    setState(() => _isSubmitting = false);
    if (!mounted) return;

    if (result['success']) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Icon(Icons.check_circle, color: Colors.green, size: 64),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Booking Requested!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              SizedBox(height: 12),
              Text('Your request has been sent to the admin for approval. You will be notified to make the payment once approved.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14)
                ),
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Back to Home', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            )
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to submit booking request.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          )
      );
    }
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _guestsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isSameDay = widget.startDate.isAtSameMomentAs(widget.endDate);

    // 🚨 ROBUST PRICING EXTRACTOR
    // Handles BOTH nested backend responses (Full Availability) AND flat maps (Partial Availability)
    final Map<String, dynamic> data = widget.pricingData;

    final Map<String, dynamic> sourceData =
    (data.containsKey('pricing') && data['pricing'] != null)
        ? data['pricing']
        : data;

    // Use double.tryParse to safeguard against the backend ORM sending Decimals as Strings
    final double rentAmount = double.tryParse(sourceData['baseCalculatedAmount']?.toString() ?? '0') ?? 0.0;
    final double depositAmount = double.tryParse(sourceData['securityDepositRequired']?.toString() ?? '0') ?? 0.0;
    final double totalEstimated = double.tryParse(sourceData['estimatedTotal']?.toString() ?? '0') ?? 0.0;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
          title: const Text('Request Booking', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Details Summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        widget.facility['name'] ?? 'Custom Booking',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.access_time, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isSameDay
                                ? '${DateFormat('MMM dd, yyyy').format(widget.startDate)}\n${widget.startTime} to ${widget.endTime}'
                                : '${DateFormat('MMM dd').format(widget.startDate)} to ${DateFormat('MMM dd, yyyy').format(widget.endDate)}\nCheck-in: ${widget.startTime} | Check-out: ${widget.endTime}',
                            style: const TextStyle(color: Colors.black87, height: 1.4, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 2. Forms Input
              const Text('Event Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _purposeController,
                decoration: InputDecoration(
                    labelText: 'Purpose of Event (e.g. Wedding)',
                    prefixIcon: const Icon(Icons.event_note),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter the event purpose' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _guestsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: 'Estimated Guests',
                    prefixIcon: const Icon(Icons.group),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Required';
                  if (int.tryParse(val) == null || int.parse(val) <= 0) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // 3. Pricing Summary Box
              const Text('Pricing Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green.shade200),
                    borderRadius: BorderRadius.circular(16)
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount Due (Rent)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                        Text('₹$rentAmount', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Security Deposit (Pay at Check-in)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.orange.shade800)),
                        Text('₹$depositAmount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.green)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Estimated Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        Text('₹$totalEstimated', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.green.shade800)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // 4. Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleRequestBooking,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Request for Approval', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}