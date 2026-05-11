// lib/screens/clerk_checkout_screen.dart
import 'package:flutter/material.dart';
import '../core/di/service_locator.dart';
import '../services/clerk_service.dart';

class ClerkCheckoutScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> userDetails;

  const ClerkCheckoutScreen({
    super.key,
    required this.bookingId,
    required this.userDetails,
  });

  @override
  State<ClerkCheckoutScreen> createState() => _ClerkCheckoutScreenState();
}

class _ClerkCheckoutScreenState extends State<ClerkCheckoutScreen> {
  final _clerkService = getIt<ClerkService>();
  late Future<Map<String, dynamic>?> _invoiceFuture;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Using the safe fetch method that handles 404s
    _invoiceFuture = _clerkService.fetchInvoiceIfExists(widget.bookingId);
  }

  Future<void> _handleCheckOut() async {
    setState(() => _isProcessing = true);

    final success = await _clerkService.checkOut(widget.bookingId);

    setState(() => _isProcessing = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checkout successful & Session finalized.'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to complete checkout process.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: const Text('Final Settlement & Invoice'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _invoiceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load invoice payload from backend.'));
          }

          final invoice = snapshot.data ?? {};

          // Data exactly mapped to backend invoice.model.js
          final baseAmount = invoice['baseAmount'] ?? 0;
          final securityDeposit = invoice['securityDepositHeld'] ?? 0;
          final electricity = invoice['electricityCharges'] ?? 0;
          final cleaning = invoice['cleaningCharges'] ?? 0;
          final generator = invoice['generatorCharges'] ?? 0;
          final discount = invoice['discountAmount'] ?? 0;
          final cgst = invoice['cgstAmount'] ?? 0;
          final sgst = invoice['sgstAmount'] ?? 0;
          final totalAmount = invoice['totalAmount'] ?? 0;

          final additionalItemsRaw = invoice['additionalItems'];
          final List<dynamic> additionalItems = additionalItemsRaw is List ? additionalItemsRaw : [];
          
          final damagesRaw = invoice['damagesAndPenalties'];
          final List<dynamic> damages = damagesRaw is List ? damagesRaw : [];

          final balanceDue = invoice['additionalBalanceDue'] ?? 0;
          final refundAmount = invoice['finalRefundAmount'] ?? 0;

          final invoiceNo = invoice['invoiceNumber'] ?? 'DRAFT-${widget.bookingId.substring(0,6).toUpperCase()}';

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                        ]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Bill Header
                        const Text(
                          'MAHARASHTRA MANDAL RAIPUR',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          invoice['approvalStatus'] == 'APPROVED' ? 'Final Tax Invoice' : 'Proforma / Draft Invoice',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: invoice['approvalStatus'] == 'APPROVED' ? Colors.green : Colors.orange),
                        ),
                        const SizedBox(height: 24),

                        // Guest & Invoice Meta
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Bill To:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  Text(invoice['customerName'] ?? widget.userDetails['fullName'] ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                  Text(invoice['customerPhone'] ?? widget.userDetails['mobile'] ?? '', overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Invoice #', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  Text(invoiceNo, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                  Text((invoice['createdAt'] ?? DateTime.now().toString()).split('T')[0], overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Bill Table Header
                        const Divider(color: Colors.black, thickness: 1.5, height: 1.5),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text('DESCRIPTION', style: TextStyle(fontWeight: FontWeight.bold))),
                              Expanded(flex: 1, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                        const Divider(color: Colors.black, thickness: 1.5, height: 1.5),
                        const SizedBox(height: 8),

                        // Standard Charges
                        _buildBillRow('Facility Base Charges', baseAmount),
                        if (securityDeposit > 0) _buildBillRow('Security Deposit Held', securityDeposit),
                        if (electricity > 0) _buildBillRow('Electricity Charges', electricity),
                        if (cleaning > 0) _buildBillRow('Cleaning Charges', cleaning),
                        if (generator > 0) _buildBillRow('Generator Charges', generator),

                        // Extra Amenities
                        if (additionalItems.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Extras & Amenities:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                          for (var item in additionalItems)
                            _buildBillRow(item['name'] ?? 'Extra Item', item['amount'] ?? 0),
                        ],

                        // Damages
                        if (damages.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Damages & Penalties:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
                          for (var dmg in damages)
                            _buildBillRow(dmg['reason'] ?? 'Penalty', dmg['amount'] ?? 0, color: Colors.red),
                        ],

                        // Taxes & Discounts
                        if (cgst > 0 || sgst > 0 || discount > 0) ...[
                          const SizedBox(height: 8),
                          const Divider(color: Colors.grey, height: 1),
                          const SizedBox(height: 8),
                          if (discount > 0) _buildBillRow('Discount Applied', discount, isNegative: true, color: Colors.green),
                          if (cgst > 0) _buildBillRow('CGST', cgst),
                          if (sgst > 0) _buildBillRow('SGST', sgst),
                        ],

                        const SizedBox(height: 16),

                        // Totals Section
                        const Divider(color: Colors.black, thickness: 1.5, height: 1.5),
                        _buildTotalRow('GRAND TOTAL', totalAmount, isBold: true),

                        // Settlement Status
                        if (balanceDue > 0)
                          _buildTotalRow('BALANCE DUE', balanceDue, isBold: true, fontSize: 18, textColor: Colors.red)
                        else if (refundAmount > 0)
                          _buildTotalRow('REFUND ISSUED', refundAmount, isBold: true, fontSize: 18, textColor: Colors.green)
                        else
                          _buildTotalRow('SETTLED', 0, isBold: true, fontSize: 18, textColor: Colors.indigo),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Action Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black12))),
                child: SafeArea(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _handleCheckOut,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isProcessing
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                        balanceDue > 0
                            ? 'Collect ₹${balanceDue.toStringAsFixed(0)} & Finish'
                            : (refundAmount > 0 ? 'Refund ₹${refundAmount.toStringAsFixed(0)} & Finish' : 'Complete Workflow'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  // Helper widget to maintain strict horizontal alignment without vertical separators
  Widget _buildBillRow(String title, num amount, {bool isNegative = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(title, style: TextStyle(color: color), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Expanded(
              flex: 1,
              child: Text(
                isNegative ? '-₹${amount.toStringAsFixed(2)}' : '₹${amount.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: TextStyle(color: color),
              )
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String title, num amount, {bool isBold = false, Color? textColor, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(title, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize, color: textColor), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize, color: textColor)),
        ],
      ),
    );
  }
}