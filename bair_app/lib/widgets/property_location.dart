import 'package:flutter/material.dart';

import '../models/property.dart';
import 'brand.dart';

class PropertyLocation extends StatelessWidget {
  final Property property;
  final bool compact;
  const PropertyLocation({
    super.key,
    required this.property,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final labels = [
      property.district.trim(),
      property.complexName.trim(),
    ].where((value) => value.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labels.isNotEmpty)
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  labels.join(' · '),
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11 : 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        if (property.location.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            property.location,
            maxLines: compact ? 1 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              color: AppColors.secondaryText,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
