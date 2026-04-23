// lib/screens/custom_facility_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CustomFacilityScreen extends StatefulWidget {
  final List<dynamic> atomicFacilities;

  const CustomFacilityScreen({super.key, required this.atomicFacilities});

  @override
  State<CustomFacilityScreen> createState() => _CustomFacilityScreenState();
}

class _CustomFacilityScreenState extends State<CustomFacilityScreen> {
  // Keeps track of selected quantities for each facility ID
  final Map<String, int> _selectedQuantities = {};

  String _getValidImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return '';
    return rawUrl.replaceAll('127.0.0.1', '10.0.2.2').replaceAll('localhost', '10.0.2.2');
  }

  double get _totalEstimatedPrice {
    double total = 0;
    for (var facility in widget.atomicFacilities) {
      final id = facility['id'];
      final qty = _selectedQuantities[id] ?? 0;
      if (qty > 0) {
        final price = double.tryParse(facility['baseRate']?.toString() ?? '0') ?? 0;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Custom Booking', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
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
                final price = facility['baseRate']?.toString() ?? '0';
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
                    side: BorderSide(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        // Thumbnail
                        Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.grey[200]),
                          clipBehavior: Clip.antiAlias,
                          child: validImageUrl.isNotEmpty
                              ? CachedNetworkImage(imageUrl: validImageUrl, fit: BoxFit.cover)
                              : const Icon(Icons.apartment, color: Colors.grey),
                        ),
                        const SizedBox(width: 16),
                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('₹$price', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        // Controls (Checkbox vs Counter)
                        inventoryCount > 1
                            ? Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              color: qty > 0 ? Colors.redAccent : Colors.grey,
                              onPressed: () => _updateQuantity(id, -1, inventoryCount),
                            ),
                            Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              color: qty < inventoryCount ? Theme.of(context).colorScheme.primary : Colors.grey,
                              onPressed: () => _updateQuantity(id, 1, inventoryCount),
                            ),
                          ],
                        )
                            : Checkbox(
                          value: isSelected,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (val) {
                            setState(() => _selectedQuantities[id] = (val == true) ? 1 : 0);
                          },
                        ),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Estimated Total', style: TextStyle(color: Colors.grey, fontSize: 14)),
                      Text('₹$_totalEstimatedPrice', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: _totalEstimatedPrice > 0 ? () {
                      // TODO: Navigate to Booking Form with selected items
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