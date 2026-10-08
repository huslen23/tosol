import 'package:flutter/material.dart';

import '../models/property.dart';
import '../services/app_store.dart';
import '../widgets/property_card.dart';
import 'property_page.dart';
import 'comfort_page.dart';

class DiscoveryPage extends StatefulWidget {
  final String kind, title;
  final Map<String, String> query;
  const DiscoveryPage({
    super.key,
    required this.kind,
    required this.title,
    this.query = const {},
  });
  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  final items = <Map<String, dynamic>>[];
  bool started = false, loading = false, hasNext = false;
  int page = 0;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      load();
    }
  }

  Future<void> load({bool more = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = more ? page + 1 : 1;
      final data = await AppScope.read(context).api.request(
        'GET',
        '${widget.kind}/',
        query: {...widget.query, 'page': '$next'},
      ) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        if (!more) items.clear();
        items.addAll((data['results'] as List).cast<Map<String, dynamic>>());
        hasNext = data['next'] != null;
        page = next;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: loading && items.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (error != null)
                  EmptyState(
                    title: 'Мэдээлэл ачаалж чадсангүй',
                    message: error!,
                    onRetry: load,
                  ),
                if (items.isEmpty && error == null)
                  const EmptyState(
                    title: 'Мэдээлэл алга',
                    message: 'Нийтлэгдсэн мэдээлэл энд харагдана.',
                  ),
                ...items.map(
                  (item) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_city),
                      title: Text('${item['name']}'),
                      subtitle: Text('${item['property_count']} зар'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DiscoveryDetailPage(
                            kind: widget.kind,
                            id: item['id'] as int,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (hasNext)
                  OutlinedButton(
                    onPressed: loading ? null : () => load(more: true),
                    child: const Text('Цааш үзэх'),
                  ),
              ],
            ),
          ),
  );
}

class DiscoveryDetailPage extends StatefulWidget {
  final String kind;
  final int id;
  const DiscoveryDetailPage({super.key, required this.kind, required this.id});
  @override
  State<DiscoveryDetailPage> createState() => _DiscoveryDetailPageState();
}

class _DiscoveryDetailPageState extends State<DiscoveryDetailPage> {
  Map<String, dynamic>? data;
  String? error;
  bool started = false, loading = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      load();
    }
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await AppScope.read(context).api.request(
        'GET',
        '${widget.kind}/${widget.id}/',
      ) as Map<String, dynamic>;
      if (mounted) setState(() => data = result);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final district = widget.kind == 'districts';
    return Scaffold(
      appBar: AppBar(title: Text('${d?['name'] ?? 'Дэлгэрэнгүй'}')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? EmptyState(
              title: 'Ачаалж чадсангүй',
              message: error!,
              onRetry: load,
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '${d!['name']}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(
                  '${d['description']}'.isEmpty
                      ? 'Тайлбар оруулаагүй.'
                      : '${d['description']}',
                ),
                if (!district) Text('${d['district_name']} • ${d['address']}'),
                Text('${d['property_count']} зар'),
                if (district)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      d['average_sale_price_per_m2'] == null
                          ? 'Үнийн мэдээлэл хүрэлцэхгүй байна.'
                          : 'Худалдах зарын дундаж: ${money(double.parse(d['average_sale_price_per_m2'] as String))} / м²\nАппад нийтлэгдсэн заруудаар тооцсон.',
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PropertyPage(
                        standalone: true,
                        initialQuery: {
                          if (district) 'district': '${d['name']}',
                          if (!district) 'complex': '${d['id']}',
                        },
                      ),
                    ),
                  ),
                  child: const Text('Заруудыг үзэх'),
                ),
                if (!district)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.reviews_outlined),
                    label: const Text('Тав тухын үнэлгээ, сэтгэгдэл'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ComfortPage(
                          complexId: widget.id,
                          name: '${d['name']}',
                        ),
                      ),
                    ),
                  ),
                if (district)
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DiscoveryPage(
                          kind: 'complexes',
                          title: '${d['name']} • Хотхонууд',
                          query: {'district': '${d['name']}'},
                        ),
                      ),
                    ),
                    child: const Text('Хотхонуудыг судлах'),
                  ),
              ],
            ),
    );
  }
}
