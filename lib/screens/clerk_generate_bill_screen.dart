// lib/screens/clerk_generate_bill_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/di/service_locator.dart';
import '../services/clerk_service.dart';

class ClerkGenerateBillScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> bookingData;
  final Map<String, dynamic>? existingInvoice; // NEW: Accepts rejected invoice data

  const ClerkGenerateBillScreen({
    super.key,
    required this.bookingId,
    required this.bookingData,
    this.existingInvoice,
  });

  @override
  State<ClerkGenerateBillScreen> createState() => _ClerkGenerateBillScreenState();
}

class _ClerkGenerateBillScreenState extends State<ClerkGenerateBillScreen> {
  final _clerkService = getIt<ClerkService>();
  bool _isSubmitting = false;

  // Invoice & Settlement Settings
  String _invoiceType = 'GENERAL';
  String _settlementMode = 'ONLINE';
  bool _hasOnlinePayment = false;

  // Dynamic Tax Rates
  double _cgstRate = 0.025;
  double _sgstRate = 0.025;

  // Standard Charge Controllers
  final _discountCtrl = TextEditingController(text: '0');
  final _elecUnitsCtrl = TextEditingController(text: '0');
  final _cleaningCtrl = TextEditingController(text: '0');
  final _generatorCtrl = TextEditingController(text: '0');

  // Customer Details Controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  final List<Map<String, dynamic>> _additionalItems = [];
  final List<Map<String, dynamic>> _damagesAndPenalties = [];

  final _itemNameCtrl = TextEditingController();
  final _itemAmountCtrl = TextEditingController();
  final _damageReasonCtrl = TextEditingController();
  final _damageAmountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    // 1. Default user data parsing
    final user = widget.bookingData['user'] ?? {};
    _nameCtrl.text = user['fullName'] ?? '';
    _emailCtrl.text = user['email'] ?? '';
    _phoneCtrl.text = user['phone'] ?? user['mobile'] ?? '';

    // 2. PRE-FILL LOGIC: If an invoice was rejected, populate everything!
    if (widget.existingInvoice != null) {
      final inv = widget.existingInvoice!;

      _invoiceType = inv['invoiceType'] ?? 'GENERAL';
      _settlementMode = inv['settlementMode'] ?? 'ONLINE';

      // Remove trailing decimals (.0) for clean text field viewing
      _discountCtrl.text = (inv['discountAmount']?.toString() ?? '0').replaceAll(RegExp(r'\.0$'), '');
      _elecUnitsCtrl.text = (inv['electricityUnitsConsumed']?.toString() ?? '0');
      _cleaningCtrl.text = (inv['cleaningCharges']?.toString() ?? '0').replaceAll(RegExp(r'\.0$'), '');
      _generatorCtrl.text = (inv['generatorCharges']?.toString() ?? '0').replaceAll(RegExp(r'\.0$'), '');

      if (inv['customerName'] != null) _nameCtrl.text = inv['customerName'];
      if (inv['customerEmail'] != null) _emailCtrl.text = inv['customerEmail'];
      if (inv['customerPhone'] != null) _phoneCtrl.text = inv['customerPhone'];
      if (inv['billingAddress'] != null) _addressCtrl.text = inv['billingAddress'];

      if (inv['additionalItems'] != null && inv['additionalItems'] is List) {
        _additionalItems.addAll((inv['additionalItems'] as List).map((e) => {
          'name': e['name']?.toString() ?? '',
          'amount': double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0,
        }));
      }

      if (inv['damagesAndPenalties'] != null && inv['damagesAndPenalties'] is List) {
        _damagesAndPenalties.addAll((inv['damagesAndPenalties'] as List).map((e) => {
          'reason': e['reason']?.toString() ?? '',
          'amount': double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0,
        }));
      }
    }

    // 3. SECURE RAZORPAY CHECK
    final financials = widget.bookingData['financials'] ?? {};
    final rawIdsRaw = financials['razorpayPaymentIds'];
    final List<dynamic> rawIds = rawIdsRaw is List ? rawIdsRaw : [];
    _hasOnlinePayment = rawIds.any((id) => id != null && id.toString().startsWith('pay_'));

    // If no valid Razorpay ID exists, ensure ONLINE isn't accidentally selected
    if (!_hasOnlinePayment && _settlementMode == 'ONLINE') {
      _settlementMode = 'CASH';
    }

    // Add listeners to update the live preview on any keystroke
    _discountCtrl.addListener(() => setState(() {}));
    _elecUnitsCtrl.addListener(() => setState(() {}));
    _cleaningCtrl.addListener(() => setState(() {}));
    _generatorCtrl.addListener(() => setState(() {}));

    _fetchTaxSettings();
  }

  Future<void> _fetchTaxSettings() async {
    try {
      final settings = await _clerkService.getSystemSettings();
      if (mounted) {
        setState(() {
          double cgstPercent = double.tryParse(settings['cgstPercentage']?.toString() ?? '2.5') ?? 2.5;
          double sgstPercent = double.tryParse(settings['sgstPercentage']?.toString() ?? '2.5') ?? 2.5;
          _cgstRate = cgstPercent / 100.0;
          _sgstRate = sgstPercent / 100.0;
        });
      }
    } catch (e) {
      // Safe failure, retains default
    }
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _elecUnitsCtrl.dispose();
    _cleaningCtrl.dispose();
    _generatorCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // --- Financial Calculations ---
  double get _baseAmount => double.tryParse(widget.bookingData['financials']?['calculatedAmount']?.toString() ?? '0') ?? 0;
  double get _securityDeposit => double.tryParse(widget.bookingData['financials']?['securityDeposit']?.toString() ?? '0') ?? 0;
  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _discountedBase => (_baseAmount - _discount) > 0 ? (_baseAmount - _discount) : 0;

  int get _elecUnits => int.tryParse(_elecUnitsCtrl.text) ?? 0;
  double get _electricityCharges => _elecUnits * 14.0;
  double get _cleaning => double.tryParse(_cleaningCtrl.text) ?? 0;
  double get _generator => double.tryParse(_generatorCtrl.text) ?? 0;

  double get _extrasTotal => _additionalItems.fold(0, (sum, item) => sum + (item['amount'] as double));
  double get _damagesTotal => _damagesAndPenalties.fold(0, (sum, item) => sum + (item['amount'] as double));

  double get _taxableAmount => _discountedBase + _electricityCharges + _cleaning + _generator + _extrasTotal + _damagesTotal;

  double get _cgst => _invoiceType == 'GENERAL' ? _taxableAmount * _cgstRate : 0.0;
  double get _sgst => _invoiceType == 'GENERAL' ? _taxableAmount * _sgstRate : 0.0;

  double get _grandTotal => _taxableAmount + _cgst + _sgst;

  Future<void> _submitDraftInvoice() async {
    if (_invoiceType == 'DONATION') {
      if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().length != 10 || _addressCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name, valid 10-digit Phone, and Address are strictly required for Donation invoices.')));
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'bookingId': widget.bookingId,
        'invoiceType': _invoiceType,
        'settlementMode': _settlementMode,
        if (_settlementMode == 'ONLINE')
          'dueDate': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        'discountAmount': _discount,
        'electricityUnitsConsumed': _elecUnits,
        'electricityCharges': _electricityCharges,
        'cleaningCharges': _cleaning,
        'generatorCharges': _generator,
        'additionalItems': _additionalItems,
        'damagesAndPenalties': _damagesAndPenalties,
      };

      if (_invoiceType == 'DONATION') {
        payload['customerName'] = _nameCtrl.text.trim();
        payload['customerEmail'] = _emailCtrl.text.trim();
        payload['customerPhone'] = _phoneCtrl.text.trim();
        payload['billingAddress'] = _addressCtrl.text.trim();
      }

      final success = await _clerkService.generateDraftInvoice(payload);

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft Invoice generated! Awaiting Admin Approval.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _addListItem(List<Map<String, dynamic>> list, TextEditingController nameCtrl, TextEditingController amountCtrl, String nameKey) {
    if (nameCtrl.text.trim().isEmpty || amountCtrl.text.trim().isEmpty) return;
    setState(() {
      list.add({
        nameKey: nameCtrl.text.trim(),
        'amount': double.tryParse(amountCtrl.text.trim()) ?? 0,
      });
      nameCtrl.clear();
      amountCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Generate Draft Bill'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // 1. LIVE PREVIEW CARD
            Card(
              color: Colors.indigo.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.indigo.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(child: Text('Live Financial Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(_invoiceType, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                          backgroundColor: _invoiceType == 'GENERAL' ? Colors.indigo : Colors.green,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        )
                      ],
                    ),
                    const Divider(),
                    _previewRow('Facility Base Amount', _baseAmount),
                    if (_discount > 0) _previewRow('Discount Applied', -_discount, color: Colors.green),
                    if (_discount > 0) const Divider(height: 8, color: Colors.indigo),
                    if (_discount > 0) _previewRow('Discounted Base Price', _discountedBase, isBold: true),

                    if (_elecUnits > 0) _previewRow('Electricity (${_elecUnits} units @ ₹14)', _electricityCharges),
                    if (_cleaning > 0) _previewRow('Cleaning Charges', _cleaning),
                    if (_generator > 0) _previewRow('Generator Charges', _generator),
                    if (_extrasTotal > 0) _previewRow('Additional Amenities', _extrasTotal),
                    if (_damagesTotal > 0) _previewRow('Damages / Penalties', _damagesTotal, color: Colors.red),

                    const Divider(color: Colors.indigo),

                    if (_invoiceType == 'GENERAL') ...[
                      _previewRow('CGST (${(_cgstRate * 100).toStringAsFixed(1)}%)', _cgst),
                      _previewRow('SGST (${(_sgstRate * 100).toStringAsFixed(1)}%)', _sgst),
                    ] else ...[
                      _previewRow('Taxes (Donation Exemption)', 0.0, color: Colors.green, isBold: true),
                    ],

                    const Divider(color: Colors.indigo),
                    _previewRow('Estimated Grand Total', _grandTotal, isBold: true, fontSize: 18),
                    const SizedBox(height: 4),
                    const Text('*Taxes will be finalized precisely by the server database.', style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 8),
                    Text('Security Deposit Held: ₹${_securityDeposit.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. INVOICE CATEGORY & SETTLEMENT
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Invoice Scope', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _invoiceType,
                      decoration: const InputDecoration(labelText: 'Invoice Category', border: OutlineInputBorder()),
                      items: [
                        DropdownMenuItem(value: 'GENERAL', child: Text('General (Taxable at ${((_cgstRate + _sgstRate) * 100).toStringAsFixed(1)}%)')),
                        const DropdownMenuItem(value: 'DONATION', child: Text('Donation (Tax Exempt - 0%)')),
                      ],
                      onChanged: (val) => setState(() => _invoiceType = val!),
                    ),
                    const SizedBox(height: 16),

                    if (!_hasOnlinePayment)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                        child: const Text('No Razorpay payment detected. Auto-online processing is locked.', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),

                    DropdownButtonFormField<String>(
                      value: _settlementMode,
                      decoration: const InputDecoration(labelText: 'Final Settlement Mode', border: OutlineInputBorder()),
                      items: [
                        if (_hasOnlinePayment)
                          const DropdownMenuItem(value: 'ONLINE', child: Text('Online / Payment Gateway')),
                        const DropdownMenuItem(value: 'CASH', child: Text('Cash Handover')),
                        const DropdownMenuItem(value: 'QR', child: Text('UPI / QR Code')),
                      ],
                      onChanged: (val) => setState(() => _settlementMode = val!),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. CUSTOMER DETAILS (IF DONATION)
            if (_invoiceType == 'DONATION') ...[
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.green.shade200)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Donation Details (Mandatory)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                      const SizedBox(height: 16),
                      _buildTextField('Full Name', _nameCtrl),
                      const SizedBox(height: 12),
                      _buildTextField('Email Address', _emailCtrl),
                      const SizedBox(height: 12),
                      _buildNumericField('Mobile Number (10 digits)', _phoneCtrl),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addressCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Complete Billing Address', border: OutlineInputBorder(), isDense: true),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 4. STANDARD CHARGES & DISCOUNTS
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Standard Usage & Discounts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    _buildNumericField('Discount on Base Price (₹)', _discountCtrl),
                    const SizedBox(height: 12),
                    _buildNumericField('Electricity Units Consumed (₹14/unit)', _elecUnitsCtrl),
                    const SizedBox(height: 12),
                    _buildNumericField('Cleaning Charges (₹)', _cleaningCtrl),
                    const SizedBox(height: 12),
                    _buildNumericField('Generator Charges (₹)', _generatorCtrl),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 5. ADDITIONAL AMENITIES
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Extra Amenities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(flex: 2, child: _buildTextField('Item Name', _itemNameCtrl)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildNumericField('Amount', _itemAmountCtrl)),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.indigo, size: 36),
                          onPressed: () => _addListItem(_additionalItems, _itemNameCtrl, _itemAmountCtrl, 'name'),
                        )
                      ],
                    ),
                    const Divider(),
                    ..._additionalItems.map((item) => ListTile(
                      title: Text(item['name']), trailing: Text('₹${item['amount']}'), dense: true, contentPadding: EdgeInsets.zero,
                      leading: IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setState(() => _additionalItems.remove(item))),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 6. DAMAGES & PENALTIES
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Damages & Penalties', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(flex: 2, child: _buildTextField('Reason/Detail', _damageReasonCtrl)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildNumericField('Penalty', _damageAmountCtrl)),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.red, size: 36),
                          onPressed: () => _addListItem(_damagesAndPenalties, _damageReasonCtrl, _damageAmountCtrl, 'reason'),
                        )
                      ],
                    ),
                    const Divider(),
                    ..._damagesAndPenalties.map((item) => ListTile(
                      title: Text(item['reason']), trailing: Text('₹${item['amount']}'), dense: true, contentPadding: EdgeInsets.zero,
                      leading: IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setState(() => _damagesAndPenalties.remove(item))),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SafeArea(
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitDraftInvoice,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 54)),
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Draft Invoice & Request Approval', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _previewRow(String title, double amount, {bool isBold = false, Color? color, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(title, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize, color: color), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize, color: color)),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(controller: controller, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true));
  }

  Widget _buildNumericField(String label, TextEditingController controller) {
    return TextField(controller: controller, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true));
  }
}