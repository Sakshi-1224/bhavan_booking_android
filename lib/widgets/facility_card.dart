// lib/widgets/facility_card.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FacilityCard extends StatelessWidget {
  final Map<String, dynamic> facility;
  final VoidCallback onTap;

  const FacilityCard({
    super.key,
    required this.facility,
    required this.onTap,
  });

  String _getValidImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return '';
    return rawUrl.replaceAll('127.0.0.1', '10.0.2.2').replaceAll('localhost', '10.0.2.2');
  }

  @override
  Widget build(BuildContext context) {
    final name = facility['name'] ?? 'Unknown Facility';
    final description = facility['description'] ?? 'No description available.';
    final price = facility['baseRate']?.toString() ?? '0';
    final capacity = facility['maxCapacity']?.toString();

    String? rawImageUrl = (facility['images'] != null && facility['images'].isNotEmpty)
        ? facility['images'][0]
        : null;
    final validImageUrl = _getValidImageUrl(rawImageUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      // Wrap in Material & InkWell to make the whole card a button with a ripple effect
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // IMAGE HERO SECTION
              Stack(
                children: [
                  SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: validImageUrl.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: validImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[200]),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[100],
                        child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                      ),
                    )
                        : Container(color: Colors.grey[100], child: const Icon(Icons.apartment, size: 60, color: Colors.grey)),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Text('₹$price', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Theme.of(context).colorScheme.primary)),
                    ),
                  ),
                ],
              ),

              // CONTENT SECTION
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (capacity != null && capacity.isNotEmpty && capacity != 'null')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4), borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              children: [
                                Icon(Icons.people_alt_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text('Cap: $capacity', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )
                        else const SizedBox.shrink(),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: onTap, // Button also triggers the same onTap event
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Book Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}