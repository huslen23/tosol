import 'package:flutter/material.dart';

import '../models/property.dart';
import '../services/app_store.dart';
import '../widgets/property_card.dart';
import '../widgets/brand.dart';
import 'property_page.dart';
import 'property_form_page.dart';
import 'discovery_page.dart';
import 'filter_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final search = TextEditingController();
  String listingType = 'sale';
  List<Property> items = [], featured = [];
  String? error;
  bool loading = true;
  int revision = -1, requestId = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = AppScope.of(context).revision;
    if (revision != r) {
      revision = r;
      load();
    }
  }

  Future<void> load() async {
    final store = AppScope.read(context);
    final id = ++requestId;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        store.api.properties({'page_size': '6', 'listing_type': listingType}),
        store.api.properties({
          'page_size': '6',
          'featured': 'true',
          'listing_type': listingType,
        }),
      ]);
      final result = results.first;
      if (mounted && id == requestId) {
        store.rememberFavorites(result.items);
        setState(() {
          items = result.items;
          featured = results.last.items;
        });
      }
    } catch (e) {
      if (mounted && id == requestId) setState(() => error = '$e');
    } finally {
      if (mounted && id == requestId) setState(() => loading = false);
    }
  }

  void browse({String? district, String? type}) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PropertyPage(
        standalone: true,
        initialQuery: {
          'listing_type': listingType,
          if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
          'district': ?district,
          'property_type': ?type,
        },
      ),
    ),
  );
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                children: [
                  const BrandMark(size: 32),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Өргөө',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          'Таны мөрөөдлийн байр',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Зар нэмэх',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: addListing,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (user != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Сайн байна уу, ${user['first_name']}',
                    style: const TextStyle(color: AppColors.secondaryText),
                  ),
                ),
              const Text(
                'Танд тохирох байраа олоорой',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Байршлаа сонгоод шинэ гэрээ хайж эхлээрэй.',
                style: TextStyle(color: AppColors.secondaryText, height: 1.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => browse(),
                decoration: InputDecoration(
                  hintText: 'Дүүрэг, хотхон, байршлаар хайх...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: IconButton(
                    tooltip: 'Хайх',
                    onPressed: browse,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Хаана байр хайж байна вэ?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: districts
                      .take(9)
                      .map(
                        (d) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(d),
                            onPressed: () => browse(district: d),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Дүүрэг судлах'),
                    avatar: const Icon(Icons.location_city, size: 18),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DiscoveryPage(
                          kind: 'districts',
                          title: 'Дүүрэг судлах',
                        ),
                      ),
                    ),
                  ),
                  ActionChip(
                    label: const Text('Хотхонууд'),
                    avatar: const Icon(Icons.apartment, size: 18),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DiscoveryPage(
                          kind: 'complexes',
                          title: 'Хотхонууд',
                        ),
                      ),
                    ),
                  ),
                  ActionChip(
                    label: const Text('Танд тохирох байр'),
                    avatar: const Icon(Icons.tune, size: 18),
                    onPressed: recommendations,
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Row(
                children: propertyTypes.entries
                    .map(
                      (e) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            children: [
                              Material(
                                color: e.key == 'apartment'
                                    ? AppColors.primary
                                    : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: e.key == 'apartment'
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => browse(type: e.key),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 19,
                                      vertical: 12,
                                    ),
                                    child: Icon(
                                      {
                                        'apartment': Icons.home_outlined,
                                        'house': Icons.cottage_outlined,
                                        'office': Icons.business_outlined,
                                        'land': Icons.landscape_outlined,
                                      }[e.key],
                                      size: 23,
                                      color: e.key == 'apartment'
                                          ? Colors.white
                                          : AppColors.secondaryText,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                e.value,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'sale', label: Text('Худалдах')),
                  ButtonSegment(value: 'rent', label: Text('Түрээслэх')),
                ],
                selected: {listingType},
                onSelectionChanged: (s) {
                  setState(() => listingType = s.first);
                  load();
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Онцлох байр',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: browse,
                    child: const Text('Бүгдийг харах'),
                  ),
                ],
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (error != null)
                EmptyState(
                  title: 'Зар ачаалж чадсангүй',
                  message: error!,
                  onRetry: load,
                )
              else ...[
                if (featured.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Одоогоор онцолсон зар алга.'),
                  ),
                ...featured.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PropertyCard(property: p),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Шинээр нэмэгдсэн',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: browse,
                    child: const Text('Бүгдийг үзэх'),
                  ),
                ],
              ),
              if (!loading && error == null && items.isEmpty)
                EmptyState(
                  title: 'Эхний зарыг нэмээрэй',
                  message: 'Шинэ зарууд энд харагдана.',
                  buttonLabel: 'Зар нэмэх',
                  onRetry: addListing,
                ),
              if (!loading && error == null)
                ...items.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PropertyCard(property: p, compact: true),
                  ),
                ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Таны мөрөөдлийн байр эндээс эхэлнэ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Өөрийн байраа худалдах эсвэл түрээслэх зараа нэмээрэй.',
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: addListing,
                        icon: const Icon(Icons.add),
                        label: const Text('Зар нэмэх'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> addListing() async {
    if (!await requireLogin(context) || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PropertyFormPage()),
    );
  }

  Future<void> recommendations() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FilterSheet(
        query: {'listing_type': listingType},
        recommendations: true,
      ),
    );
    if (result == null || result['max_price'] == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PropertyPage(
          standalone: true,
          recommendations: true,
          initialQuery: result,
        ),
      ),
    );
  }
}
