// lib/screens/my_bookings_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../core/di/service_locator.dart';
import '../services/user_booking_service.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _bookingService = getIt<UserBookingService>();
  final ImagePicker _picker = ImagePicker();
  late Razorpay _razorpay;

  List<dynamic> _bookings = [];
  bool _isLoading = true;

  final Map<String, String> _frontImages = {};
  final Map<String, String> _backImages = {};
  final Map<String, bool> _isUploading = {};
  final Map<String, String> _paymentPreferences = {};

  String? _processingBookingId;
  String? _processingPhase;

  @override
  void initState() {
    super.initState();
    _fetchBookings();

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _fetchBookings() async {
    setState(() => _isLoading = true);
    final result = await _bookingService.getMyBookings();
    if (result['success'] && mounted) {
      setState(() {
        _bookings = result['data'];
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
    }
  }

  // --- KYC UPLOAD LOGIC ---
  Future<void> _pickImage(String bookingId, bool isFront) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() {
        if (isFront) {
          _frontImages[bookingId] = image.path;
        } else {
          _backImages[bookingId] = image.path;
        }
      });
    }
  }

  Future<void> _uploadAadhaar(String bookingId) async {
    if (_frontImages[bookingId] == null || _backImages[bookingId] == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select both front and back images.')));
      return;
    }

    setState(() => _isUploading[bookingId] = true);

    final result = await _bookingService.uploadAadhaar(
      bookingId,
      _frontImages[bookingId]!,
      _backImages[bookingId]!,
    );

    if (!mounted) return;
    setState(() => _isUploading[bookingId] = false);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aadhaar uploaded successfully!'), backgroundColor: Colors.green));
      _fetchBookings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.redAccent));
    }
  }

  // --- RAZORPAY LOGIC ---
  Future<void> _initiatePayment(String bookingId, String phase, {String paymentOption = 'FULL'}) async {
    setState(() {
      _processingBookingId = bookingId;
      _processingPhase = phase;
    });

    final orderResult = await _bookingService.createPaymentOrder(bookingId, phase, paymentOption: paymentOption);

    if (!orderResult['success']) {
      setState(() => _processingBookingId = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(orderResult['message']), backgroundColor: Colors.redAccent));
      return;
    }

    final orderData = orderResult['data'];

    var options = {
      'key': orderData['keyId'],
      'amount': orderData['amount'],
      'name': 'Maharashtra Mandal',
      'order_id': orderData['orderId'],
      'description': '${phase == "INITIAL" ? (paymentOption == "HOLD" ? "Hold" : "Full") : "Balance"} Payment',
      'theme.color': '#e53e3e',
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() => _processingBookingId = null);
      debugPrint('Error: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_processingBookingId == null) return;

    final verifyResult = await _bookingService.verifyPayment(
      _processingBookingId!,
      _processingPhase!,
      {
        'razorpay_order_id': response.orderId,
        'razorpay_payment_id': response.paymentId,
        'razorpay_signature': response.signature,
      },
    );

    if (!mounted) return;

    if (verifyResult['success']) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment successful!'), backgroundColor: Colors.green));
      _fetchBookings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(verifyResult['message']), backgroundColor: Colors.redAccent));
    }

    setState(() => _processingBookingId = null);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _processingBookingId = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Failed: ${response.message}'), backgroundColor: Colors.redAccent));
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  // --- UI HELPERS ---
  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    return DateFormat('EEE, MMM dd yyyy, hh:mm a').format(DateTime.parse(dateStr).toLocal());
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING_CLERK_REVIEW':
      case 'PENDING_ADMIN_APPROVAL': return Colors.orange;
      case 'PENDING_PAYMENT': return Colors.blue;
      case 'ON_HOLD': return Colors.indigo;
      case 'CONFIRMED': return Colors.green;
      case 'REJECTED':
      case 'CANCELLED': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Bookings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
          ? const Center(child: Text('No bookings found.', style: TextStyle(fontSize: 16, color: Colors.grey)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookings.length,
        itemBuilder: (context, index) {
          final booking = _bookings[index];
          final status = booking['status'] ?? 'UNKNOWN';
          final pref = _paymentPreferences[booking['id']] ?? 'ONLINE';

          final financials = booking['financials'] ?? {};
          final double base = _parseDouble(financials['calculatedAmount']);
          final double deposit = _parseDouble(financials['securityDeposit']);

          final double holdPaid = _parseDouble(financials['holdAmountPaid']);
          final double advRequested = _parseDouble(financials['advanceAmountRequested']);
          final double advancePaid = holdPaid > 0 ? holdPaid : advRequested;

          final bool isPartial = financials['paymentStatus'] == 'PARTIAL';
          final bool isCompleted = financials['paymentStatus'] == 'COMPLETED';

          final double amountPaid = isCompleted ? base : (isPartial ? advancePaid : 0);
          final double amountDue = base - amountPaid;

          return Card(
            margin: const EdgeInsets.only(bottom: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: _getStatusColor(status).withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 🚨 FIX 1: Wrap Facility Name in Expanded
                      Expanded(
                        child: Text(
                          booking['facility']?['name'] ?? 'Facility',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _getStatusColor(status).withOpacity(0.5)),
                        ),
                        child: Text(
                          status.replaceAll('_', ' '),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(status)),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Check-in', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                                Text(_formatDate(booking['schedule']?['startTime']), style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Check-out', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                                Text(_formatDate(booking['schedule']?['endTime']), style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      // 🚨 FIX 2: Wrap Left Side Labels in Expanded
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(child: Text('Base Rent:', style: TextStyle(color: Colors.grey))),
                          Text('₹$base', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(child: Text('Security Deposit (Due at Desk):', style: TextStyle(color: Colors.orange))),
                          Text('₹$deposit', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                        ],
                      ),

                      if (isPartial || isCompleted)
                        Container(
                          margin: const EdgeInsets.only(top:12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Expanded(child: Text('Rent Paid:', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600))),
                                  Text('₹$amountPaid', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              if (amountDue > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Expanded(child: Text('Remaining Rent Due:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600))),
                                      Text('₹$amountDue', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                      if (status == 'PENDING_CLERK_REVIEW' || status == 'PENDING_ADMIN_APPROVAL')
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange, size: 20),
                              SizedBox(width: 8),
                              Expanded(child: Text('Waiting for admin approval. You will be able to pay and upload KYC once approved.', style: TextStyle(fontSize: 12, color: Colors.orange))),
                            ],
                          ),
                        ),

                      if (status == 'PENDING_PAYMENT') ...[
                        const SizedBox(height: 16),
                        if (booking['verification']?['aadharFrontImageUrl'] == null)
                          _buildKycUploadSection(booking['id'])
                        else
                          _buildPaymentSection(booking, pref),
                      ],

                      if (status == 'ON_HOLD' && financials['paymentStatus'] == 'PARTIAL') ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: _processingBookingId == booking['id'] ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.payment),
                            label: Text(_processingBookingId == booking['id'] ? 'Processing...' : 'Pay Remaining Balance'),
                            onPressed: _processingBookingId != null ? null : () => _initiatePayment(booking['id'], 'REMAINING'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKycUploadSection(String bookingId) {
    bool isUploading = _isUploading[bookingId] ?? false;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upload KYC to Enable Payment', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickImage(bookingId, true),
                  child: Text(_frontImages[bookingId] != null ? 'Front Added ✔' : 'Add Aadhaar Front', style: const TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickImage(bookingId, false),
                  child: Text(_backImages[bookingId] != null ? 'Back Added ✔' : 'Add Aadhaar Back', style: const TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isUploading ? null : () => _uploadAadhaar(bookingId),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: isUploading ? const Text('Uploading...', style: TextStyle(color: Colors.white)) : const Text('Upload & Continue', style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPaymentSection(dynamic booking, String currentPref) {
    final double base = _parseDouble(booking['financials']?['calculatedAmount']);
    final bool isHoldingAllowed = booking['financials']?['isHoldingAllowed'] == true;
    final double holdPercent = _parseDouble(booking['financials']?['holdingPercentage'] ?? 20);
    final double holdAmount = base * (holdPercent / 100);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified, color: Colors.green, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('KYC Verified. Select Payment Mode:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _paymentPreferences[booking['id']] = 'ONLINE'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: currentPref == 'ONLINE' ? Colors.green : Colors.transparent, borderRadius: const BorderRadius.horizontal(left: Radius.circular(7))),
                      child: Center(child: Text('Online', style: TextStyle(color: currentPref == 'ONLINE' ? Colors.white : Colors.green, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _paymentPreferences[booking['id']] = 'OFFLINE'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: currentPref == 'OFFLINE' ? Colors.green : Colors.transparent, borderRadius: const BorderRadius.horizontal(right: Radius.circular(7))),
                      child: Center(child: Text('Cash / Desk', style: TextStyle(color: currentPref == 'OFFLINE' ? Colors.white : Colors.green, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (currentPref == 'ONLINE') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _processingBookingId != null ? null : () => _initiatePayment(booking['id'], 'INITIAL', paymentOption: 'FULL'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                child: Text('Pay Full Rent (₹$base)'),
              ),
            ),
            if (isHoldingAllowed) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _processingBookingId != null ? null : () => _initiatePayment(booking['id'], 'INITIAL', paymentOption: 'HOLD'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.indigo, side: const BorderSide(color: Colors.indigo)),
                  // 🚨 FIX 3: Preventing button text overflow
                  child: Text('Hold Dates for ₹$holdAmount ($holdPercent%)', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                ),
              ),
            ]
          ] else ...[
            const Text('Please visit the Bhavan Clerk Desk to make your payment in cash. Note: Auto-cancels if unpaid before deadline.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          ]
        ],
      ),
    );
  }
}