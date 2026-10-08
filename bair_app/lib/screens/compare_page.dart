import 'package:flutter/material.dart';

import '../models/property.dart';
import '../services/app_store.dart';
import '../services/api_client.dart';
import '../widgets/property_card.dart';
import 'property_detail_page.dart';

class ComparePage extends StatefulWidget {
  const ComparePage({super.key});
  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  List<Property> items = [];
  Set<int> unavailable = {};
  bool started = false, loading = true;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      load();
    }
  }

  Future<void> load() async {
    final store = AppScope.read(context);
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final missing = <int>{};
      final result = await Future.wait(
        List<int>.of(store.comparison).map((id) async {
          try {
            return await store.api.property(id);
          } on ApiException catch (e) {
            if (e.status != 404) rethrow;
            missing.add(id);
            return null;
          }
        }),
      );
      if (mounted) {
        setState(() {
          items = result.whereType<Property>().toList();
          unavailable = missing;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final selected = items
        .where((p) => store.comparison.contains(p.id))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Байр харьцуулах')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? EmptyState(
              title: 'Харьцуулалт ачаалж чадсангүй',
              message: error!,
              onRetry: load,
            )
          : selected.isEmpty &&
                unavailable.every((id) => !store.comparison.contains(id))
          ? const EmptyState(
              title: 'Байр сонгоно уу',
              message: 'Зарын харьцуулах товчоор 2–3 байр сонгоорой.',
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final id in unavailable.where(store.comparison.contains))
                  Card(
                    child: ListTile(
                      title: Text('Зар #$id боломжгүй болсон.'),
                      trailing: IconButton(
                        tooltip: 'Харьцуулалтаас хасах',
                        icon: const Icon(Icons.close),
                        onPressed: () => store.toggleComparison(id),
                      ),
                    ),
                  ),
                const Text(
                  '2–3 байр сонгон үнэ, талбай, байршлыг харьцуулна. Сонголт энэ сессэд хадгалагдана.',
                ),
                const SizedBox(height: 16),
                if (selected.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        const DataColumn(label: Text('Үзүүлэлт')),
                        ...selected.map(
                          (p) => DataColumn(
                            label: SizedBox(
                              width: 170,
                              child: Text(p.title, maxLines: 3),
                            ),
                          ),
                        ),
                      ],
                      rows: [
                        for (final row in <String, String Function(Property)>{
                          'Төрөл': (p) => p.typeLabel,
                          'Үнэ': (p) => p.priceLabel,
                          'Үнэ / м²': (p) => money(p.price / p.area),
                          'Дүүрэг': (p) => p.district,
                          'Хаяг': (p) => p.location,
                          'Өрөө': (p) => '${p.rooms}',
                          'Талбай': (p) => '${p.area} м²',
                          'Давхар': (p) => '${p.floor}/${p.totalFloors}',
                        }.entries)
                          DataRow(
                            cells: [
                              DataCell(Text(row.key)),
                              ...selected.map(
                                (p) => DataCell(
                                  SizedBox(
                                    width: 170,
                                    child: Text(row.value(p)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        DataRow(
                          cells: [
                            const DataCell(Text('Үйлдэл')),
                            ...selected.map(
                              (p) => DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Зар үзэх',
                                      icon: const Icon(Icons.open_in_new),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PropertyDetailPage(id: p.id),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Харьцуулалтаас хасах',
                                      icon: const Icon(Icons.close),
                                      onPressed: () =>
                                          store.toggleComparison(p.id),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
