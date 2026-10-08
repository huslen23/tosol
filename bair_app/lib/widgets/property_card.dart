import 'package:flutter/material.dart';

import '../models/property.dart';
import 'property_location.dart';
import '../services/app_store.dart';
import '../screens/login_page.dart';
import '../screens/property_detail_page.dart';

void showMessage(BuildContext context, Object message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$message')));

Future<bool> requireLogin(BuildContext context) async {
  final store = AppScope.read(context);
  if (!store.loggedIn) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }
  return store.loggedIn;
}

class PropertyImageView extends StatelessWidget {
  final String? url;
  final double? height;
  const PropertyImageView({super.key, this.url, this.height});
  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
      color: const Color(0xFFEFF6FF),
      alignment: Alignment.center,
      child: const Icon(
        Icons.apartment_rounded,
        size: 64,
        color: Color(0xFF94A3B8),
      ),
    );
    return SizedBox(
      height: height,
      width: double.infinity,
      child: url == null
          ? fallback()
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => fallback(),
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(
                      color: const Color(0xFFEFF6FF),
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
            ),
    );
  }
}

class SaveButton extends StatelessWidget {
  final Property property;
  const SaveButton({super.key, required this.property});
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final saved = store.favorites[property.id] ?? property.isFavorite;
    return IconButton.filledTonal(
      tooltip: saved ? 'Хадгалснаас хасах' : 'Байр хадгалах',
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2563EB),
      ),
      icon: Icon(
        saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      ),
      onPressed: () async {
        if (!await requireLogin(context)) return;
        try {
          await store.toggleFavorite(property.id, property.isFavorite);
        } catch (e) {
          if (context.mounted) showMessage(context, e);
        }
      },
    );
  }
}

class PropertyCard extends StatelessWidget {
  final Property property;
  final bool compact;
  const PropertyCard({super.key, required this.property, this.compact = false});
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PropertyDetailPage(id: property.id)),
      ),
      child: compact
          ? _compact(context)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    PropertyImageView(
                      url: property.imageUrls.firstOrNull,
                      height: 190,
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          property.typeLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 8,
                      child: SaveButton(property: property),
                    ),
                    if (property.imageUrls.isNotEmpty)
                      Positioned(
                        bottom: 10,
                        right: 12,
                        child: Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(
                            Icons.photo_library_outlined,
                            size: 16,
                          ),
                          label: Text('${property.imageUrls.length}'),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PropertyLocation(property: property),
                      const SizedBox(height: 12),
                      Text(
                        property.priceLabel,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        property.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),
                      Wrap(
                        spacing: 18,
                        runSpacing: 6,
                        children: [
                          Text('${property.rooms} өрөө'),
                          Text(
                            '${property.area.toStringAsFixed(property.area % 1 == 0 ? 0 : 1)} м²',
                          ),
                          Text(
                            '${property.floor}/${property.totalFloors} давхар',
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: CompareButton(property: property),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    ),
  );

  Widget _compact(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          height: 144,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PropertyImageView(url: property.imageUrls.firstOrNull),
                Positioned(
                  left: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      property.typeLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PropertyLocation(property: property, compact: true),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      property.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: SaveButton(property: property),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  property.priceLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Spacer(),
                  CompareButton(property: property, compact: true),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _fact(
                    Icons.square_foot,
                    '${property.area.toStringAsFixed(property.area % 1 == 0 ? 0 : 1)} м²',
                  ),
                  _fact(Icons.bed_outlined, '${property.rooms} өрөө'),
                  _fact(
                    Icons.layers_outlined,
                    '${property.floor}/${property.totalFloors}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _fact(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: const Color(0xFF475569)),
      const SizedBox(width: 3),
      Text(
        text,
        style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
      ),
    ],
  );
}

class CompareButton extends StatelessWidget {
  final Property property;
  final bool compact;
  const CompareButton({
    super.key,
    required this.property,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final selected = store.comparison.contains(property.id);
    if (compact) {
      return SizedBox(
        width: 26,
        height: 22,
        child: IconButton(
          padding: EdgeInsets.zero,
          tooltip: selected ? 'Харьцуулалтаас хасах' : 'Харьцуулах',
          icon: Icon(selected ? Icons.check : Icons.compare_arrows, size: 17),
          onPressed: () {
            try {
              store.toggleComparison(property.id);
            } catch (e) {
              showMessage(context, e);
            }
          },
        ),
      );
    }
    return TextButton.icon(
      icon: Icon(selected ? Icons.check : Icons.compare_arrows),
      label: Text(selected ? 'Харьцуулалтаас хасах' : 'Харьцуулах'),
      onPressed: () {
        try {
          store.toggleComparison(property.id);
        } catch (e) {
          showMessage(context, e);
        }
      },
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title, message;
  final VoidCallback? onRetry;
  final String buttonLabel;
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.buttonLabel = 'Дахин оролдох',
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.home_work_outlined,
            size: 54,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onRetry, child: Text(buttonLabel)),
          ],
        ],
      ),
    ),
  );
}
