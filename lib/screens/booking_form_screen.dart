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

  // NEW VARIABLES FOR PARTIAL FLOW
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
      customs = widget.partialAlternatives!.map((alt) => {
        'facilityId': alt['facilityId'] ?? alt['id'],
        'quantity': alt['quantity'] ?? 1
      }).toList();
    }

    final result = await _bookingService.requestBooking(
      facilityId: widget.facility['id'],
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
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Back to Home', style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSameDay = widget.startDate.isAtSameMomentAs(widget.endDate);

    // 🚨 PERFECT MATCH TO BACKEND PRICING SERVICE
    // The backend uses these exact keys inside the 'pricing' object
    final double rentAmount = (widget.pricingData['baseCalculatedAmount'] ?? 0).toDouble();
    final double depositAmount = (widget.pricingData['securityDepositRequired'] ?? 0).toDouble();
    final double totalEstimated = (widget.pricingData['estimatedTotal'] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Request Booking', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0),
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
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.facility['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.access_time, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isSameDay
                                ? '${DateFormat('MMM dd, yyyy').format(widget.startDate)}\n${widget.startTime} to ${widget.endTime}'
                                : '${DateFormat('MMM dd').format(widget.startDate)} to ${DateFormat('MMM dd, yyyy').format(widget.endDate)}\nCheck-in: ${widget.startTime} | Check-out: ${widget.endTime}',
                            style: const TextStyle(color: Colors.black87, height: 1.4),
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
                decoration: InputDecoration(labelText: 'Purpose of Event (e.g. Wedding)', prefixIcon: const Icon(Icons.event_note), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                validator: (val) => val == null || val.isEmpty ? 'Please enter the event purpose' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _guestsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Estimated Guests', prefixIcon: const Icon(Icons.group), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 32),

              // 3. The "BookingWidget" Style Pricing Box
              // 3. The "BookingWidget" Style Pricing Box
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
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Request for Approval', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}