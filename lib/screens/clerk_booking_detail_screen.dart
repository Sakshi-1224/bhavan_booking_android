// lib/screens/clerk_booking_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../core/di/service_locator.dart';
import '../services/clerk_service.dart';
import 'clerk_generate_bill_screen.dart';

class ClerkBookingDetailScreen extends StatefulWidget {
  final String bookingId;

  const ClerkBookingDetailScreen({super.key, required this.bookingId});

  @override
  State<ClerkBookingDetailScreen> createState() => _ClerkBookingDetailScreenState();
}

class _ClerkBookingDetailScreenState extends State<ClerkBookingDetailScreen> {
  final _clerkService = getIt<ClerkService>();
  final ImagePicker _picker = ImagePicker();

  late Future<Map<String, dynamic>> _detailsFuture;
  late Future<Map<String, dynamic>?> _invoiceFuture;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  void _fetchDetails() {
    setState(() {
      _detailsFuture = _clerkService.getBookingDetails(widget.bookingId);
      _invoiceFuture = _clerkService.fetchInvoiceIfExists(widget.bookingId);
    });
  }

  Future<void> _executeAction(Future<bool> Function() action, String successMessage) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await action();
      if (!mounted) return;
      Navigator.pop(context); // Clear loader

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? successMessage : 'Action failed.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) _fetchDetails();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Clear loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openPdf(String url) async {
    final Uri pdfUri = Uri.parse(url);
    if (!await launchUrl(pdfUri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the PDF invoice.'), backgroundColor: Colors.red),
      );
    }
  }

  // --- ENHANCED CHECK-IN DIALOG ---
  void _showCheckInDialog(double securityDeposit) {
    bool isSecurityCollected = securityDeposit <= 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Check-In Guest'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Allocate Rooms:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(hintText: 'e.g. Room 101, Room 102', border: OutlineInputBorder()),
                  ),
                  if (securityDeposit > 0) ...[
                    const SizedBox(height: 16),
                    const Text('Please confirm the collection of the security deposit to proceed.', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CheckboxListTile(
                        title: Text(
                          'I confirm I have collected the Security Deposit of ₹${securityDeposit.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange),
                        ),
                        value: isSecurityCollected,
                        activeColor: Colors.orange,
                        checkColor: Colors.white,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        onChanged: (val) {
                          setDialogState(() => isSecurityCollected = val ?? false);
                        },
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    const Text(
                        'No security deposit is pending for this booking.',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)
                    ),
                  ]
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: isSecurityCollected
                      ? () {
                    Navigator.pop(context);
                    _executeAction(
                            () => _clerkService.checkIn(widget.bookingId, isSecurityCollected),
                        'Guest Checked In Successfully'
                    );
                  }
                      : null,
                  child: const Text('Confirm Check-In'),
                ),
              ],
            );
          }
      ),
    );
  }

  // --- SMART REFUND DIALOG (STRICT CASH/QR FALLBACK) ---
  void _showRefundDialog(Map<String, dynamic> data) {
    final controller = TextEditingController();

    final financials = data['financials'] ?? {};

    // SAFE PARSING: Prevents Map to List cast errors
    final rawIdsRaw = financials['razorpayPaymentIds'];
    final List<dynamic> rawIds = rawIdsRaw is List ? rawIdsRaw : [];

    final bool hasOnlinePayment = rawIds.any((id) => id != null && id.toString().startsWith('pay_'));

    String mode = hasOnlinePayment ? 'BANK_TRANSFER' : 'CASH';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Process Direct Refund'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!hasOnlinePayment)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Expanded(child: Text('No Razorpay payment record found. Refund must be processed manually via Cash or QR.', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  DropdownButtonFormField<String>(
                    value: mode,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Refund Mode'),
                    items: [
                      if (hasOnlinePayment)
                        const DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Original Bank Mode (Razorpay)')),
                      const DropdownMenuItem(value: 'CASH', child: Text('Cash Handover')),
                      const DropdownMenuItem(value: 'QR', child: Text('UPI / QR Code')),
                    ],
                    onChanged: (val) => setDialogState(() => mode = val!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'Remarks (Optional)', border: OutlineInputBorder()),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: () {
                    Navigator.pop(context);
                    _executeAction(
                            () => _clerkService.completeManualRefund(widget.bookingId, mode, controller.text),
                        'Refund Completed via $mode'
                    );
                  },
                  child: const Text('Complete Refund', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
      ),
    );
  }

  // --- KYC UPLOAD DIALOG ---
  void _showKycUploadDialog() {
    XFile? frontImage;
    XFile? backImage;

    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                  title: const Text('Upload KYC for Guest'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.credit_card, color: Colors.indigo),
                        title: const Text('Aadhaar Front'),
                        subtitle: Text(frontImage == null ? 'Not selected' : 'Selected', style: TextStyle(color: frontImage == null ? Colors.red : Colors.green)),
                        trailing: IconButton(
                          icon: const Icon(Icons.camera_alt),
                          onPressed: () async {
                            final picked = await _picker.pickImage(source: ImageSource.gallery);
                            if (picked != null) setDialogState(() => frontImage = picked);
                          },
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.credit_card, color: Colors.indigo),
                        title: const Text('Aadhaar Back'),
                        subtitle: Text(backImage == null ? 'Not selected' : 'Selected', style: TextStyle(color: backImage == null ? Colors.red : Colors.green)),
                        trailing: IconButton(
                          icon: const Icon(Icons.camera_alt),
                          onPressed: () async {
                            final picked = await _picker.pickImage(source: ImageSource.gallery);
                            if (picked != null) setDialogState(() => backImage = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                      onPressed: (frontImage != null && backImage != null) ? () {
                        Navigator.pop(context);
                        _executeAction(
                                () => _clerkService.uploadKycOnBehalf(widget.bookingId, frontImage!.path, backImage!.path),
                            'KYC Uploaded successfully! You can now collect payment.'
                        );
                      } : null,
                      child: const Text('Upload KYC'),
                    ),
                  ]
              );
            }
        )
    );
  }

  // --- OFFLINE PAYMENT DIALOGS ---
  void _showOfflineAdvanceDialog(Map<String, dynamic> data) {
    bool isHoldAllowed = data['financials']?['isHoldingAllowed'] ?? false;
    double holdPercentage = double.tryParse(data['financials']?['holdingPercentage']?.toString() ?? '0') ?? 0;
    double totalCost = double.tryParse(data['financials']?['calculatedAmount']?.toString() ?? '0') ?? 0;

    double holdAmount = totalCost * (holdPercentage / 100);

    String paymentOption = 'FULL';
    String paymentMode = 'CASH';
    final amountCtrl = TextEditingController(text: totalCost.toStringAsFixed(0));

    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              double requiredAmount = paymentOption == 'HOLD' ? holdAmount : totalCost;

              return AlertDialog(
                  title: const Text('Collect Advance Payment'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Security deposit will be collected securely at Check-Out.', style: TextStyle(color: Colors.indigo, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),

                        if (isHoldAllowed) ...[
                          const Text('Payment Option:', style: TextStyle(fontWeight: FontWeight.bold)),
                          RadioListTile<String>(
                            title: Text('Full Payment (₹${totalCost.toStringAsFixed(0)})'),
                            value: 'FULL',
                            groupValue: paymentOption,
                            onChanged: (val) => setDialogState(() { paymentOption = val!; amountCtrl.text = totalCost.toStringAsFixed(0); }),
                          ),
                          RadioListTile<String>(
                            title: Text('Hold Payment ($holdPercentage% - ₹${holdAmount.toStringAsFixed(0)})'),
                            value: 'HOLD',
                            groupValue: paymentOption,
                            onChanged: (val) => setDialogState(() { paymentOption = val!; amountCtrl.text = holdAmount.toStringAsFixed(0); }),
                          ),
                          const Divider(),
                        ],

                        const Text('Payment Mode:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: paymentMode,
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'CASH', child: Text('Cash Handover')),
                            DropdownMenuItem(value: 'QR', child: Text('UPI / QR Code')),
                          ],
                          onChanged: (val) => setDialogState(() {
                            paymentMode = val!;
                          }),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Amount Collected (₹)', border: OutlineInputBorder()),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                      onPressed: () {
                        final amt = double.tryParse(amountCtrl.text) ?? 0;

                        if (amt < requiredAmount) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Amount must be at least ₹$requiredAmount')));
                          return;
                        }

                        Navigator.pop(context);
                        _executeAction(
                                () => _clerkService.recordOfflineAdvance(widget.bookingId, paymentMode, amt, paymentOption),
                            'Offline Payment Logged Successfully!'
                        );
                      },
                      child: const Text('Confirm Collection'),
                    )
                  ]
              );
            }
        )
    );
  }

  void _showOfflineRemainingDialog(Map<String, dynamic> data) {
    double totalCost = double.tryParse(data['financials']?['calculatedAmount']?.toString() ?? '0') ?? 0;
    double holdPaid = double.tryParse(data['financials']?['holdAmountPaid']?.toString() ?? '0') ?? 0;
    double remaining = totalCost - holdPaid;

    String paymentMode = 'CASH';
    final amountCtrl = TextEditingController(text: remaining.toStringAsFixed(0));

    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                  title: const Text('Collect Remaining Balance'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Text('Remaining Balance Due: ₹${remaining.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                        ),
                        const SizedBox(height: 16),
                        const Text('Payment Mode:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: paymentMode,
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'CASH', child: Text('Cash Handover')),
                            DropdownMenuItem(value: 'QR', child: Text('UPI / QR Code')),
                          ],
                          onChanged: (val) => setDialogState(() {
                            paymentMode = val!;
                          }),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Amount Collected (₹)', border: OutlineInputBorder()),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                      onPressed: () {
                        final amt = double.tryParse(amountCtrl.text) ?? 0;

                        if (amt < remaining) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Amount must be at least ₹$remaining')));
                          return;
                        }

                        Navigator.pop(context);
                        _executeAction(
                                () => _clerkService.recordOfflineRemaining(widget.bookingId, paymentMode, amt),
                            'Remaining Balance Cleared!'
                        );
                      },
                      child: const Text('Confirm Collection'),
                    )
                  ]
              );
            }
        )
    );
  }

  // --- Detailed Financial Breakdown Helper ---
  Widget _buildInvoiceBreakdown(Map<String, dynamic> invoice) {
    double safeParse(dynamic value) => double.tryParse(value?.toString() ?? '0') ?? 0.0;

    final baseAmount = safeParse(invoice['baseAmount']);
    final electricity = safeParse(invoice['electricityCharges']);
    final cleaning = safeParse(invoice['cleaningCharges']);
    final generator = safeParse(invoice['generatorCharges']);
    final discount = safeParse(invoice['discountAmount']);
    final cgst = safeParse(invoice['cgstAmount']);
    final sgst = safeParse(invoice['sgstAmount']);
    final totalAmount = safeParse(invoice['totalAmount']);
    final balDue = safeParse(invoice['additionalBalanceDue']);
    final refAmt = safeParse(invoice['finalRefundAmount']);

    // SAFE PARSING: Prevents Map to List cast errors
    final extrasRaw = invoice['additionalItems'];
    final extrasList = extrasRaw is List ? extrasRaw : [];
    final extrasTotal = extrasList.fold(0.0, (sum, item) => sum + safeParse(item['amount']));

    // SAFE PARSING: Prevents Map to List cast errors
    final damagesRaw = invoice['damagesAndPenalties'];
    final damagesList = damagesRaw is List ? damagesRaw : [];
    final damagesTotal = damagesList.fold(0.0, (sum, item) => sum + safeParse(item['amount']));

    Widget summaryRow(String label, num amount, {Color? color, bool isBold = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
            Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        summaryRow('Facility Base Charges', baseAmount),
        if (electricity > 0) summaryRow('Electricity Charges', electricity),
        if (cleaning > 0) summaryRow('Cleaning Charges', cleaning),
        if (generator > 0) summaryRow('Generator Charges', generator),
        if (extrasTotal > 0) summaryRow('Additional Amenities (${extrasList.length} items)', extrasTotal),
        if (damagesTotal > 0) summaryRow('Damages & Penalties', damagesTotal, color: Colors.red),
        if (discount > 0) summaryRow('Discount Applied', -discount, color: Colors.green),
        if (cgst > 0) summaryRow('CGST Tax', cgst),
        if (sgst > 0) summaryRow('SGST Tax', sgst),
        const Divider(),
        summaryRow('Grand Total', totalAmount, isBold: true),
        const SizedBox(height: 8),
        if (balDue > 0) summaryRow('Balance Collected', balDue, color: Colors.red, isBold: true),
        if (refAmt > 0) summaryRow('Refund Issued', refAmt, color: Colors.green, isBold: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Full Booking Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh PDF/Data',
            onPressed: () {
              _fetchDetails();
            },
          )
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([_detailsFuture, _invoiceFuture]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text('Error loading payload from backend.'));
          if (!snapshot.hasData) return const Center(child: Text('No details found.'));

          final data = snapshot.data![0] as Map<String, dynamic>;
          final invoice = snapshot.data![1] as Map<String, dynamic>?;

          final user = data['user'] ?? {};
          final status = data['status'];
          final facility = data['facility'];

          // SAFE PARSING: Prevents Map to List cast errors
          final customDetailsRaw = data['customDetails'];
          final List<dynamic> customDetails = customDetailsRaw is List ? customDetailsRaw : [];

          final financials = data['financials'] ?? {};

          final bool hasKyc = data['verification']?['aadharFrontImageUrl'] != null && data['verification']?['aadharBackImageUrl'] != null;

          // Rent & Deposit Parsing
          final paymentStatus = financials['paymentStatus'] ?? 'PENDING';
          final calculatedAmount = double.tryParse(financials['calculatedAmount']?.toString() ?? '0') ?? 0;
          final holdAmountPaid = double.tryParse(financials['holdAmountPaid']?.toString() ?? '0') ?? 0;
          final securityDeposit = double.tryParse(financials['securityDeposit']?.toString() ?? '0') ?? 0;

          double amountPaidSoFar = 0;
          if (paymentStatus == 'COMPLETED') {
            amountPaidSoFar = calculatedAmount;
          } else if (paymentStatus == 'PARTIAL') {
            amountPaidSoFar = holdAmountPaid;
          }

          return RefreshIndicator(
            onRefresh: () async {
              _fetchDetails();
              await Future.wait([_detailsFuture, _invoiceFuture]);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Header
                  Card(
                    color: Colors.indigo.shade50,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('System Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Chip(
                              label: Text(
                                (status ?? 'UNKNOWN').replaceAll('_', ' '),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Comprehensive User Context
                  const Text('Guest Credentials', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.person, color: Colors.white)),
                    title: Text(user['fullName'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Mobile: ${user['phone'] ?? user['mobile'] ?? 'N/A'}\nEmail: ${user['email'] ?? 'N/A'}'),
                    isThreeLine: true,
                  ),
                  const SizedBox(height: 24),

                  // ==========================================
                  // FACILITY & BOOKING SCOPE
                  // ==========================================
                  const Text('Facility & Booking Scope', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  const Divider(),
                  if (facility != null)
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.indigo.shade100),
                            borderRadius: BorderRadius.circular(8)
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.meeting_room, color: Colors.indigo),
                                const SizedBox(width: 8),
                                Expanded(child: Text(facility['name'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Type: ${facility['facilityType'] ?? 'N/A'}  •  Model: ${facility['pricingType'] ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade700)),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Facility Charges:', style: TextStyle(fontWeight: FontWeight.w500)),
                                Text('₹${calculatedAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Security Deposit:', style: TextStyle(fontWeight: FontWeight.w500)),
                                Text('₹${securityDeposit.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 16)),
                              ],
                            ),
                          ],
                        )
                    ),

                  if (customDetails.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Custom Selection Breakdown:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: customDetails.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${item['name']} (x${item['quantity']})', style: const TextStyle(color: Colors.black87)),
                              Text('₹${item['price']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ==========================================
                  // RENT PAYMENT & SECURITY DEPOSIT STATUS
                  // ==========================================
                  if (amountPaidSoFar > 0 && (status == 'CONFIRMED' || status == 'ON_HOLD'))
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            border: Border.all(color: Colors.green.shade200),
                            borderRadius: BorderRadius.circular(8)
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Rent Payment Done: ₹${amountPaidSoFar.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16))),
                                ],
                              ),
                              if (status == 'CONFIRMED' && securityDeposit > 0) ...[
                                const Divider(color: Colors.green),
                                Row(
                                    children: [
                                      const Icon(Icons.info_outline, color: Colors.teal),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(
                                              'Security Deposit of ₹${securityDeposit.toStringAsFixed(2)} will be collected at the time of Check-In.',
                                              style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)
                                          )
                                      ),
                                    ]
                                )
                              ]
                            ]
                        )
                    ),

                  const SizedBox(height: 24),

                  // Detailed Financials / Schedule Context
                  const Text('Schedule Context', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, color: Colors.indigo),
                    title: Text('Arrival: ${data['schedule']?['startTime']?.split('T')[0] ?? 'N/A'}'),
                    subtitle: Text('Departure: ${data['schedule']?['endTime']?.split('T')[0] ?? 'N/A'}'),
                  ),

                  const SizedBox(height: 32),

                  // ==========================================
                  // 1. PAYMENT COLLECTION BLOCKS
                  // ==========================================

                  if (status == 'PENDING_PAYMENT' || status == 'AWAITING_CASH_PAYMENT') ...[
                    if (!hasKyc)
                      Card(
                          color: Colors.red.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade200)),
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  const Row(
                                      children: [
                                        Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                                        SizedBox(width: 12),
                                        Expanded(child: Text('KYC Missing. The guest must upload their Aadhaar (Front & Back) online before payment can be collected.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                                      ]
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade100,
                                      foregroundColor: Colors.red.shade900,
                                      elevation: 0,
                                      minimumSize: const Size(double.infinity, 44),
                                    ),
                                    icon: const Icon(Icons.upload_file),
                                    label: const Text('Upload KYC on Behalf of Guest'),
                                    onPressed: _showKycUploadDialog,
                                  )
                                ],
                              )
                          )
                      )
                    else
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                        icon: const Icon(Icons.payments),
                        label: const Text('Collect Advance Payment (Desk)'),
                        onPressed: () => _showOfflineAdvanceDialog(data),
                      ),
                    const SizedBox(height: 12),
                  ],

                  if (status == 'ON_HOLD') ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                      icon: const Icon(Icons.account_balance_wallet),
                      label: const Text('Collect Remaining Balance (Desk)'),
                      onPressed: () => _showOfflineRemainingDialog(data),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ==========================================
                  // 2. DYNAMIC WORKFLOW & INVOICE SECTION
                  // ==========================================

                  // --- INVOICE REJECTED ALERT ---
                  if (invoice != null && invoice['approvalStatus'] == 'REJECTED') ...[
                    Card(
                      color: Colors.red.shade50,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade200)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red),
                                SizedBox(width: 8),
                                Expanded(child: Text('Invoice Rejected by Admin', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16))),
                              ],
                            ),
                            const Divider(color: Colors.red),
                            const SizedBox(height: 8),
                            Text('Remarks: ${invoice['adminRemarks'] ?? 'No remarks provided.'}', style: const TextStyle(color: Colors.black87)),
                            const SizedBox(height: 12),
                            const Text('Please generate a new final bill addressing these remarks.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (invoice != null && invoice['approvalStatus'] == 'PENDING_ADMIN_APPROVAL') ...[
                    Card(
                      color: Colors.orange.shade50,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.orange.shade200)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.hourglass_empty, color: Colors.orange),
                                SizedBox(width: 8),
                                Expanded(child: Text('Awaiting Admin Approval', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 16))),
                              ],
                            ),
                            const Divider(color: Colors.orange),
                            const SizedBox(height: 8),
                            _buildInvoiceBreakdown(invoice),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // --- SUCCESS CHECK OUT WITH REFRESH ALERT ---
                  if (status == 'CHECKED_OUT' && invoice != null && invoice['approvalStatus'] == 'APPROVED') ...[
                    Card(
                      color: Colors.green.shade50,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.green.shade200)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Expanded(child: Text('Checkout Complete & Bill Approved', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16))),
                              ],
                            ),
                            const Divider(color: Colors.green),
                            const SizedBox(height: 8),

                            _buildInvoiceBreakdown(invoice),

                            if (invoice['invoicePdfUrl'] != null && invoice['invoicePdfUrl'].toString().isNotEmpty) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 50)
                                ),
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text('View/Download Final Invoice PDF'),
                                onPressed: () => _openPdf(invoice['invoicePdfUrl']),
                              ),
                            ] else ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade300)
                                ),
                                child: const Row(
                                  children: [
                                    SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green)),
                                    SizedBox(width: 12),
                                    Expanded(child: Text('PDF is generating. Please tap the refresh icon at the top right.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                                  ],
                                ),
                              )
                            ]
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (status == 'CHECKED_IN' && (invoice == null || invoice['approvalStatus'] == 'REJECTED'))
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16)
                      ),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Generate Final Bill (Clerk Draft)'),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ClerkGenerateBillScreen(
                              bookingId: widget.bookingId,
                              bookingData: data,
                              existingInvoice: invoice,
                            ),
                          ),
                        );
                        if (result == true) {
                          _fetchDetails();
                        }
                      },
                    ),

                  // ==========================================
                  // 3. STATE MACHINE ACTION BUTTONS
                  // ==========================================

                  if (status == 'PENDING' || status == 'PENDING_CLERK_REVIEW') ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                      icon: const Icon(Icons.verified),
                      label: const Text('Verify Guest (Clerk Approval)'),
                      onPressed: () => _executeAction(() => _clerkService.verifyBooking(widget.bookingId), 'Booking Verified. Forwarded to Admin.'),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      label: const Text('Reject Application', style: TextStyle(color: Colors.red)),
                      onPressed: () => _executeAction(() => _clerkService.rejectBooking(widget.bookingId), 'Application Rejected.'),
                    ),
                  ],

                  if (status == 'CONFIRMED')
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                      icon: const Icon(Icons.login),
                      label: const Text('Check In Guest'),
                      onPressed: () => _showCheckInDialog(securityDeposit),
                    ),

                  if (status == 'CANCELLATION_REQUESTED' || status == 'REFUND_PENDING')
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                      icon: const Icon(Icons.currency_exchange),
                      label: const Text('Execute Direct Refund'),
                      onPressed: () => _showRefundDialog(data),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}