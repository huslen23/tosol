import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/property.dart';
import '../services/app_store.dart';
import '../widgets/property_card.dart';
import '../widgets/property_location.dart';
import 'property_form_page.dart';
import 'compare_page.dart';

class PropertyDetailPage extends StatefulWidget {
  final int id;
  const PropertyDetailPage({super.key, required this.id});
  @override
  State<PropertyDetailPage> createState() => _PropertyDetailPageState();
}

class _PropertyDetailPageState extends State<PropertyDetailPage> {
  Property? property;
  String? error;
  bool loading = true, deleting = false;
  int photoIndex = 0;
  bool started = false;
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
      final p = await store.api.property(widget.id);
      store.rememberFavorites([p]);
      if (mounted) {
        setState(() {
          property = p;
          photoIndex = 0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> remove() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Зарыг устгах уу?'),
        content: const Text('Энэ зар болон хадгалсан холбоосууд устна.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final store = AppScope.read(context);
    setState(() => deleting = true);
    try {
      await store.api.request('DELETE', 'properties/${widget.id}/');
      store.favorites.remove(widget.id);
      store.changed();
      if (mounted) {
        showMessage(context, 'Зар устгагдлаа.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = property;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Байрны дэлгэрэнгүй'),
        actions: [
          if (p != null) SaveButton(property: p),
          IconButton(
            tooltip: 'Байр харьцуулах',
            icon: const Icon(Icons.compare_arrows),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ComparePage()),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? EmptyState(
              title: 'Зар ачаалж чадсангүй',
              message: error!,
              onRetry: load,
            )
          : p == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                    child: PropertyLocation(property: p),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(
                      height: 290,
                      child: Stack(
                        children: [
                          if (p.imageUrls.isEmpty)
                            const PropertyImageView()
                          else
                            PageView.builder(
                              key: ValueKey(p.updatedKey),
                              itemCount: p.imageUrls.length,
                              onPageChanged: (i) =>
                                  setState(() => photoIndex = i),
                              itemBuilder: (_, i) => GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PhotoGallery(
                                      urls: p.imageUrls,
                                      initialIndex: i,
                                    ),
                                  ),
                                ),
                                child: PropertyImageView(url: p.imageUrls[i]),
                              ),
                            ),
                          if (p.imageUrls.isNotEmpty)
                            Positioned(
                              bottom: 16,
                              right: 20,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${photoIndex + 1} / ${p.imageUrls.length}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Chip(
                          label: Text(
                            '${p.typeLabel} • ${propertyTypes[p.propertyType]}',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          p.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          p.priceLabel,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (p.area > 0 && p.listingType == 'sale')
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${money(p.price / p.area)} / м²',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        const SizedBox(height: 16),
                        CompareButton(property: p),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Газрын зурагт хайх'),
                          onPressed: () async {
                            try {
                              final url = Uri.https(
                                'www.google.com',
                                '/maps/search/',
                                {
                                  'api': '1',
                                  'query':
                                      p.latitude != null && p.longitude != null
                                      ? '${p.latitude},${p.longitude}'
                                      : '${p.district} ${p.location}, Улаанбаатар',
                                },
                              );
                              if (!await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              )) {
                                throw Exception('Газрын зураг нээж чадсангүй.');
                              }
                            } catch (e) {
                              if (context.mounted) showMessage(context, e);
                            }
                          },
                        ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _Fact(
                                  icon: Icons.bed_outlined,
                                  value: '${p.rooms}',
                                  label: 'өрөө',
                                ),
                                _Fact(
                                  icon: Icons.square_foot,
                                  value: '${p.area}',
                                  label: 'м² талбай',
                                ),
                                _Fact(
                                  icon: Icons.layers_outlined,
                                  value: '${p.floor}/${p.totalFloors}',
                                  label: 'давхар',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Байрны тухай',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          p.description.isEmpty
                              ? 'Нэмэлт тайлбар оруулаагүй.'
                              : p.description,
                          style: const TextStyle(height: 1.65),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Зар нийтэлсэн',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person_outline),
                            ),
                            title: Text(
                              p.owner == null
                                  ? 'Зар нийтлэгч'
                                  : '${p.owner!['last_name']} ${p.owner!['first_name']}'
                                        .trim(),
                            ),
                            subtitle: Text(
                              p.phone.isEmpty ? 'Утас оруулаагүй' : p.phone,
                            ),
                            trailing: IconButton(
                              tooltip: 'Утас хуулах',
                              onPressed: p.phone.isEmpty
                                  ? null
                                  : () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: p.phone),
                                      );
                                      if (context.mounted) {
                                        showMessage(
                                          context,
                                          'Утасны дугаар хуулагдлаа.',
                                        );
                                      }
                                    },
                              icon: const Icon(Icons.copy_outlined),
                            ),
                          ),
                        ),
                        if (p.isOwner || store.isAdmin) ...[
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: deleting
                                      ? null
                                      : () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  PropertyFormPage(property: p),
                                            ),
                                          );
                                          if (mounted) await load();
                                        },
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Засах'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: deleting ? null : remove,
                                  icon: const Icon(Icons.delete_outline),
                                  label: Text(
                                    deleting ? 'Устгаж байна' : 'Устгах',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: p == null || loading || error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: FilledButton.icon(
                  icon: const Icon(Icons.call_outlined),
                  label: Text(
                    p.phone.isEmpty
                        ? 'Утасны мэдээлэл алга'
                        : '${p.phone} • Холбогдох',
                  ),
                  onPressed: p.phone.isEmpty
                      ? null
                      : () async {
                          try {
                            final launched = await launchUrl(
                              Uri(scheme: 'tel', path: p.phone),
                            );
                            if (!launched && context.mounted) {
                              showMessage(
                                context,
                                'Дуудлага нээж чадсангүй. Дугаарыг хуулж авна уу.',
                              );
                            }
                          } catch (_) {
                            if (context.mounted) {
                              showMessage(
                                context,
                                'Дуудлага нээж чадсангүй. Дугаарыг хуулж авна уу.',
                              );
                            }
                          }
                        },
                ),
              ),
            ),
    );
  }
}

extension on Property {
  String get updatedKey => '$id:${imageUrls.join(',')}';
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _Fact({required this.icon, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: const Color(0xFF2563EB)),
      const SizedBox(height: 8),
      Text(
        value,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ],
  );
}

class PhotoGallery extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const PhotoGallery({
    super.key,
    required this.urls,
    required this.initialIndex,
  });
  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  late final PageController controller;
  late int index;
  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
    controller = PageController(initialPage: index);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text('${index + 1} / ${widget.urls.length}'),
    ),
    body: PageView.builder(
      controller: controller,
      itemCount: widget.urls.length,
      onPageChanged: (i) => setState(() => index = i),
      itemBuilder: (_, i) => InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: Image.network(
            widget.urls[i],
            fit: BoxFit.contain,
            errorBuilder: (_, error, stack) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white,
              size: 60,
            ),
          ),
        ),
      ),
    ),
  );
}
