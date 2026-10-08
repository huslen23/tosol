import 'package:flutter/material.dart';

import '../models/property.dart';
import '../services/app_store.dart';
import '../widgets/location_map.dart';
import '../widgets/property_card.dart';

class PropertyMapPage extends StatefulWidget {
  final Map<String, String> query;
  final bool recommendations;
  final Widget Function(String url)? tileBuilder;
  const PropertyMapPage({
    super.key,
    required this.query,
    this.recommendations = false,
    this.tileBuilder,
  });
  @override
  State<PropertyMapPage> createState() => _PropertyMapPageState();
}

class _PropertyMapPageState extends State<PropertyMapPage> {
  String? bounds, error;
  List<Property> items = [];
  bool loading = false;
  int count = 0, requestId = 0;
  Future<void> search() async {
    if (bounds == null) return;
    final id = ++requestId;
    final bbox = bounds!;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await AppScope.read(context).api.properties({
        ...widget.query,
        'located': 'true',
        'bbox': bbox,
        'page_size': '100',
        'page': '1',
      }, recommendations: widget.recommendations);
      if (!mounted || id != requestId) return;
      setState(() {
        items = result.items;
        count = result.count;
      });
    } catch (e) {
      if (mounted && id == requestId) setState(() => error = '$e');
    } finally {
      if (mounted && id == requestId) setState(() => loading = false);
    }
  }

  void select(Property p) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: PropertyCard(property: p),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Газрын зураг дээр хайх')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'Байршлын цэгтэй зарууд харагдана. Таны хайлт, шүүлтүүр үйлчилнэ.',
          ),
        ),
        Expanded(
          child: LocationMap(
            tileBuilder: widget.tileBuilder,
            onBoundsChanged: (value) {
              final first = bounds == null;
              bounds = value;
              if (first) search();
            },
            pins: items
                .map(
                  (p) => MapPin(
                    MapPoint(p.latitude!, p.longitude!),
                    p.priceLabel,
                    onTap: () => select(p),
                  ),
                )
                .toList(),
          ),
        ),
        if (loading) const LinearProgressIndicator(),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (error != null)
                  Text(
                    error!,
                    style: const TextStyle(color: Colors.deepOrange),
                  ),
                Text(
                  loading
                      ? 'Зар хайж байна…'
                      : count == 0
                      ? 'Энэ хүрээнд тохирох зар алга.'
                      : '$count зар • ${items.length} тэмдэглэгээ',
                ),
                if (count > items.length)
                  const Text(
                    'Эхний 100 зар харагдаж байна. Зургийг томруулж хүрээгээ багасгаарай.',
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: loading ? null : search,
                  icon: const Icon(Icons.search),
                  label: const Text('Энэ орчимд хайх'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
