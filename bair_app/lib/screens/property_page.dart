import 'dart:async';

import 'package:flutter/material.dart';

import '../models/property.dart';
import '../services/app_store.dart';
import '../widgets/property_card.dart';
import 'filter_sheet.dart';
import 'compare_page.dart';
import 'property_map_page.dart';

class PropertyPage extends StatefulWidget {
  final bool saved, mine, standalone;
  final bool recommendations;
  final Map<String, String> initialQuery;
  const PropertyPage({
    super.key,
    this.saved = false,
    this.mine = false,
    this.standalone = false,
    this.recommendations = false,
    this.initialQuery = const {},
  });
  @override
  State<PropertyPage> createState() => _PropertyPageState();
}

class _PropertyPageState extends State<PropertyPage> {
  late Map<String, String> query;
  late TextEditingController search;
  Timer? debounce;
  List<Property> items = [];
  bool loading = true, loadingMore = false, hasNext = false;
  String? error;
  int count = 0, page = 1, revision = -1, requestId = 0;
  @override
  void initState() {
    super.initState();
    query = Map.of(widget.initialQuery);
    search = TextEditingController(text: query['search']);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = AppScope.of(context).revision;
    if (revision != r) {
      revision = r;
      load();
    }
  }

  Future<void> load({bool more = false}) async {
    if (more && (loadingMore || loading || !hasNext)) return;
    final store = AppScope.read(context);
    final id = ++requestId;
    final nextPage = more ? page + 1 : 1;
    setState(() {
      if (more) {
        loadingMore = true;
      } else {
        loading = true;
        loadingMore = false;
      }
      error = null;
    });
    try {
      final result = await store.api.properties({
        ...query,
        'page': '$nextPage',
        if (widget.saved) 'saved': 'true',
        if (widget.mine) 'mine': 'true',
      }, recommendations: widget.recommendations);
      if (!mounted || id != requestId) return;
      store.rememberFavorites(result.items);
      setState(() {
        items = more ? [...items, ...result.items] : result.items;
        count = result.count;
        hasNext = result.hasNext;
        page = nextPage;
      });
    } catch (e) {
      if (mounted && id == requestId) setState(() => error = '$e');
    } finally {
      if (mounted && id == requestId) {
        setState(() {
          loading = false;
          loadingMore = false;
        });
      }
    }
  }

  void searchChanged(String value) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), () {
      query['search'] = value.trim();
      load();
    });
  }

  Future<void> filters() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          FilterSheet(query: query, recommendations: widget.recommendations),
    );
    if (result == null || !mounted) return;
    debounce?.cancel();
    setState(() {
      query = result;
      search.text = query['search'] ?? '';
    });
    load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.saved
        ? 'Хадгалсан байр'
        : widget.mine
        ? 'Миний зарууд'
        : widget.recommendations
        ? 'Танд тохирох байр'
        : 'Бүх байр';
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.standalone,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Газрын зураг дээр хайх',
            icon: const Icon(Icons.map_outlined),
            onPressed: () {
              debounce?.cancel();
              query['search'] = search.text.trim();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PropertyMapPage(
                    query: {
                      ...query,
                      if (widget.saved) 'saved': 'true',
                      if (widget.mine) 'mine': 'true',
                    },
                    recommendations: widget.recommendations,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Байр харьцуулах',
            icon: Badge(
              label: Text('${AppScope.of(context).comparison.length}'),
              child: const Icon(Icons.compare_arrows),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ComparePage()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: search,
              onChanged: searchChanged,
              onSubmitted: (v) {
                debounce?.cancel();
                query['search'] = v.trim();
                load();
              },
              decoration: InputDecoration(
                hintText: 'Хотхон, дүүрэг, хаяг',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Шүүлтүүр',
                  onPressed: filters,
                  icon: Badge(
                    isLabelVisible: query.keys.any(
                      (k) =>
                          !['search', 'ordering', 'listing_type'].contains(k),
                    ),
                    child: const Icon(Icons.tune),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: districts.length + 1,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final district = index == 0 ? '' : districts[index - 1];
                return ChoiceChip(
                  label: Text(index == 0 ? 'Бүх дүүрэг' : district),
                  selected: (query['district'] ?? '') == district,
                  showCheckmark: false,
                  onSelected: (_) {
                    debounce?.cancel();
                    setState(() {
                      query['search'] = search.text.trim();
                      if (district.isEmpty) {
                        query.remove('district');
                      } else {
                        query['district'] = district;
                        query.remove('complex');
                      }
                    });
                    load();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: '', label: Text('Бүгд')),
                      ButtonSegment(value: 'sale', label: Text('Худалдах')),
                      ButtonSegment(value: 'rent', label: Text('Түрээс')),
                    ],
                    selected: {query['listing_type'] ?? ''},
                    onSelectionChanged: (s) {
                      setState(() => query['listing_type'] = s.first);
                      load();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$count зар',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                DropdownButton<String>(
                  value: query['ordering'] ?? '-created_at',
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                      value: '-created_at',
                      child: Text('Шинэ эхэнд'),
                    ),
                    DropdownMenuItem(
                      value: 'price',
                      child: Text('Үнэ өсөхөөр'),
                    ),
                    DropdownMenuItem(
                      value: '-price',
                      child: Text('Үнэ буурахаар'),
                    ),
                    DropdownMenuItem(
                      value: '-area',
                      child: Text('Талбай ихээс'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => query['ordering'] = v);
                      load();
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null && items.isEmpty
                ? EmptyState(
                    title: 'Зар ачаалж чадсангүй',
                    message: error!,
                    onRetry: load,
                  )
                : RefreshIndicator(
                    onRefresh: load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (query.keys.any(
                          (k) => ![
                            'search',
                            'ordering',
                            'listing_type',
                          ].contains(k),
                        ))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (query['district']?.isNotEmpty == true)
                                  Chip(label: Text(query['district']!)),
                                if (query['property_type']?.isNotEmpty == true)
                                  Chip(
                                    label: Text(
                                      propertyTypes[query['property_type']] ??
                                          '',
                                    ),
                                  ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      query = {
                                        if (widget.recommendations &&
                                            query['max_price'] != null)
                                          'max_price': query['max_price']!,
                                        if (query['listing_type']?.isNotEmpty ==
                                            true)
                                          'listing_type':
                                              query['listing_type']!,
                                      };
                                      search.clear();
                                    });
                                    load();
                                  },
                                  child: const Text('Шүүлтүүр арилгах'),
                                ),
                              ],
                            ),
                          ),
                        if (items.isEmpty)
                          EmptyState(
                            title: widget.saved
                                ? 'Хадгалсан байр алга'
                                : 'Тохирох зар олдсонгүй',
                            message: widget.saved
                                ? 'Зарын зүрхэн товчийг дарж энд хадгалаарай.'
                                : 'Хайлтын үг болон шүүлтүүрээ өөрчилж үзээрэй.',
                          ),
                        ...items.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PropertyCard(property: p, compact: true),
                          ),
                        ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(error!, textAlign: TextAlign.center),
                          ),
                        if (hasNext)
                          OutlinedButton(
                            onPressed: loadingMore
                                ? null
                                : () => load(more: true),
                            child: loadingMore
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Дараагийн зарууд'),
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
