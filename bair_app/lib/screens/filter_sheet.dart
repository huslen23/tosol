import 'package:flutter/material.dart';

import '../models/property.dart';

class FilterSheet extends StatefulWidget {
  final Map<String, String> query;
  final bool recommendations;
  const FilterSheet({
    super.key,
    required this.query,
    this.recommendations = false,
  });
  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  final form = GlobalKey<FormState>();
  late Map<String, String> query;
  late final Map<String, TextEditingController> numbers;
  @override
  void initState() {
    super.initState();
    query = Map.of(widget.query);
    numbers = {
      for (final k in ['min_price', 'max_price', 'min_area', 'max_area'])
        k: TextEditingController(text: query[k]),
    };
  }

  @override
  void dispose() {
    for (final c in numbers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget number(String key, String label) => TextFormField(
    controller: numbers[key],
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    validator: (v) {
      if (v == null || v.trim().isEmpty) {
        return widget.recommendations && key == 'max_price'
            ? 'Төсвөө оруулна уу.'
            : null;
      }
      final n = double.tryParse(v.trim());
      if (n == null || !n.isFinite || n < 0) return 'Эерэг тоо оруулна уу.';
      if (key.startsWith('max')) {
        final min = double.tryParse(
          numbers[key.replaceFirst('max', 'min')]!.text.trim(),
        );
        if (min != null && n < min) return 'Доод хэмжээнээс бага байна.';
      }
      return null;
    },
  );
  Widget select(String key, String label, Map<String, String> options) =>
      DropdownButtonFormField<String>(
        initialValue: query[key]?.isNotEmpty == true ? query[key] : '',
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem(value: '', child: Text('Бүгд')),
          ...options.entries.map(
            (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
          ),
        ],
        onChanged: (v) => query[key] = v ?? '',
      );
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      16,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Form(
      key: form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.recommendations
                        ? 'Танд тохирох байр'
                        : 'Хайлтын шүүлтүүр',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Хаах',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            select('district', 'Дүүрэг', {for (final d in districts) d: d}),
            const SizedBox(height: 16),
            select('property_type', 'Үл хөдлөхийн төрөл', propertyTypes),
            const SizedBox(height: 16),
            select('rooms', 'Өрөөний тоо', {
              for (var n = 1; n <= 10; n++) '$n': '$n өрөө',
            }),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: number('min_price', 'Доод үнэ • ₮')),
                const SizedBox(width: 12),
                Expanded(child: number('max_price', 'Дээд үнэ • ₮')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: number('min_area', 'Доод талбай • м²')),
                const SizedBox(width: 12),
                Expanded(child: number('max_area', 'Дээд талбай • м²')),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                for (final e in numbers.entries) {
                  query[e.key] = e.value.text.trim();
                }
                query.removeWhere((k, v) => v.isEmpty);
                Navigator.pop(context, query);
              },
              child: const Text('Үр дүнг харах'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, <String, String>{
                if (widget.recommendations)
                  'max_price': numbers['max_price']!.text.trim().isNotEmpty
                      ? numbers['max_price']!.text.trim()
                      : widget.query['max_price'] ?? '',
                if (widget.query['listing_type']?.isNotEmpty == true)
                  'listing_type': widget.query['listing_type']!,
                if (widget.query['search']?.isNotEmpty == true)
                  'search': widget.query['search']!,
              }),
              child: const Text('Бүх шүүлтүүр арилгах'),
            ),
          ],
        ),
      ),
    ),
  );
}
