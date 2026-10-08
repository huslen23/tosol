import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/property.dart';
import '../services/app_store.dart';
import '../widgets/property_card.dart';
import '../widgets/location_map.dart';

class PropertyFormPage extends StatefulWidget {
  final Property? property;
  final ImagePicker? imagePicker;
  const PropertyFormPage({super.key, this.property, this.imagePicker});
  @override
  State<PropertyFormPage> createState() => _PropertyFormPageState();
}

class _PropertyFormPageState extends State<PropertyFormPage> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;
  late String listingType, propertyType, district;
  late List<PropertyPhoto> existing;
  final removed = <int>[];
  final selected = <XFile>[];
  final photoBytes = <XFile, Uint8List>{};
  bool removeCover = false, saving = false, picking = false;
  int? propertyId;
  String? cover;
  int? complexId;
  MapPoint? mapPoint;
  List<Map<String, dynamic>> complexes = [];
  bool discoveryStarted = false, loadingComplexes = false;
  String? complexError;
  int complexRequest = 0;
  List<String> districtChoices = List.of(districts);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!discoveryStarted) {
      discoveryStarted = true;
      loadDistricts();
      loadComplexes();
    }
  }

  Future<void> loadDistricts() async {
    try {
      final api = AppScope.read(context).api;
      final names = <String>[];
      var page = 1;
      while (true) {
        final result = await api.request(
          'GET',
          'districts/',
          query: {'page_size': '100', 'page': '$page'},
        ) as Map<String, dynamic>;
        names.addAll(
          (result['results'] as List).map((d) => d['name'] as String),
        );
        if (result['next'] == null) break;
        page++;
      }
      if (mounted && names.isNotEmpty) {
        setState(() => districtChoices = {district, ...names}.toList());
      }
    } catch (_) {
      // Keep known district choices usable during a temporary network error.
    }
  }

  Future<void> loadComplexes() async {
    final id = ++complexRequest;
    setState(() {
      loadingComplexes = true;
      complexError = null;
    });
    try {
      final api = AppScope.read(context).api;
      final values = <Map<String, dynamic>>[];
      var page = 1;
      while (true) {
        final result = await api.request(
          'GET',
          'complexes/',
          query: {'district': district, 'page_size': '100', 'page': '$page'},
        ) as Map<String, dynamic>;
        if (!mounted || id != complexRequest) return;
        values.addAll((result['results'] as List).cast<Map<String, dynamic>>());
        if (result['next'] == null) break;
        page++;
      }
      setState(() => complexes = values);
    } catch (e) {
      if (mounted && id == complexRequest) setState(() => complexError = '$e');
    } finally {
      if (mounted && id == complexRequest) {
        setState(() => loadingComplexes = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final p = widget.property;
    propertyId = p?.id;
    complexId = p?.complexId;
    if (p?.latitude != null && p?.longitude != null) {
      mapPoint = MapPoint(p!.latitude!, p.longitude!);
    }
    listingType = p?.listingType ?? 'sale';
    propertyType = p?.propertyType ?? 'apartment';
    district = p != null && p.district.isNotEmpty
        ? p.district
        : districts.first;
    if (!districtChoices.contains(district)) districtChoices.add(district);
    cover = p?.image;
    existing = List.of(p?.photos ?? []);
    final values = {
      'title': p?.title ?? '',
      'location': p?.location ?? '',
      'description': p?.description ?? '',
      'price': p == null ? '' : '${p.price}',
      'area': p == null ? '' : '${p.area}',
      'rooms': '${p?.rooms ?? 2}',
      'floor': '${p?.floor ?? 1}',
      'total_floors': '${p?.totalFloors ?? 1}',
      'contact_phone': p?.phone ?? '',
    };
    fields = {
      for (final e in values.entries)
        e.key: TextEditingController(text: e.value),
    };
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get photoCount =>
      selected.length +
      existing.length +
      (cover != null && !removeCover ? 1 : 0);
  Future<void> pickPhotos() async {
    setState(() => picking = true);
    try {
      final photos = await (widget.imagePicker ?? ImagePicker()).pickMultiImage(
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (photoCount + photos.length > 12) {
        showMessage(context, 'Хамгийн ихдээ 12 зураг оруулна.');
        return;
      }
      final previews = <XFile, Uint8List>{};
      for (final photo in photos) {
        final bytes = await photo.readAsBytes();
        if (bytes.length > 10 * 1024 * 1024) {
          if (mounted) showMessage(context, 'Зураг бүр 10 MB-аас бага байна.');
          return;
        }
        previews[photo] = bytes;
      }
      if (mounted) {
        setState(() {
          selected.addAll(photos);
          photoBytes.addAll(previews);
        });
      }
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Зургийн сан нээж чадсангүй. Төхөөрөмжийн зөвшөөрлөө шалгана уу.',
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final store = AppScope.read(context);
    setState(() => saving = true);
    bool saved = false;
    try {
      final body = <String, dynamic>{
        for (final e in fields.entries) e.key: e.value.text.trim(),
        'listing_type': listingType,
        'property_type': propertyType,
        'district': district,
        'complex': complexId,
        'latitude': mapPoint?.latitude,
        'longitude': mapPoint?.longitude,
        if (removeCover) 'image': null,
      };
      final p = await store.api.saveProperty(body, id: propertyId);
      propertyId = p.id;
      saved = true;
      if (removeCover) {
        cover = null;
        removeCover = false;
      }
      for (final id in List<int>.of(removed)) {
        await store.api.request(
          'DELETE',
          'properties/$propertyId/photos/',
          body: {'image_id': id},
        );
        removed.remove(id);
      }
      if (selected.isNotEmpty) {
        await store.api.uploadPhotos(propertyId!, selected);
        selected.clear();
        photoBytes.clear();
      }
      store.changed();
      if (mounted) {
        showMessage(context, 'Зар амжилттай хадгалагдлаа.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (saved) store.changed();
      if (mounted) {
        showMessage(
          context,
          saved
              ? 'Зарын мэдээлэл хадгалагдсан. Зураг хадгалахад алдаа гарлаа: $e. Дахин хадгалж болно.'
              : e,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String? validate(String key, String? input) {
    final value = input?.trim() ?? '';
    if (key == 'description') return null;
    if (value.isEmpty) return 'Энэ талбарыг бөглөнө үү.';
    if (key == 'title' && value.length > 200) {
      return '200 тэмдэгтээс бага байна.';
    }
    if (key == 'location' && value.length > 255) {
      return '255 тэмдэгтээс бага байна.';
    }
    if (key == 'contact_phone') {
      return RegExp(r'^\+?[0-9]{8,15}$').hasMatch(value)
          ? null
          : '8–15 оронтой утас оруулна уу.';
    }
    if (['price', 'area'].contains(key)) {
      final n = double.tryParse(value);
      if (n == null || !n.isFinite || n <= 0) {
        return 'Тэгээс их тоо оруулна уу.';
      }
      if (key == 'price' && n >= 10000000000) {
        return 'Үнэ 10 тэрбумаас бага байна.';
      }
      if (key == 'area' && n >= 100000000) return 'Талбай хэт их байна.';
    }
    if (['rooms', 'floor', 'total_floors'].contains(key)) {
      final n = int.tryParse(value);
      if (n == null ||
          n < (key == 'floor' ? 0 : 1) ||
          n > (key == 'rooms' ? 100 : 200)) {
        return 'Зөв бүхэл тоо оруулна уу.';
      }
      if (key == 'floor' &&
          n > (int.tryParse(fields['total_floors']!.text) ?? 0)) {
        return 'Нийт давхраас их байна.';
      }
    }
    return null;
  }

  Widget field(
    String key,
    String label, {
    bool numeric = false,
    int lines = 1,
  }) => TextFormField(
    controller: fields[key],
    enabled: !saving,
    maxLines: lines,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : key == 'contact_phone'
        ? TextInputType.phone
        : lines > 1
        ? TextInputType.multiline
        : TextInputType.text,
    decoration: InputDecoration(labelText: label),
    validator: (v) => validate(key, v),
  );
  Widget photo(Widget image, VoidCallback remove) => SizedBox(
    width: 104,
    height: 100,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: image),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton.filled(
            tooltip: 'Зураг хасах',
            style: IconButton.styleFrom(
              backgroundColor: Colors.black54,
              minimumSize: const Size(28, 28),
              padding: const EdgeInsets.all(4),
            ),
            onPressed: saving ? null : remove,
            icon: const Icon(Icons.close, size: 16),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.property == null ? 'Шинэ зар нэмэх' : 'Зараа засах'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Орон зайгаа танилцуулаарай',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text('Байрны бодит мэдээлэл, тод зургууд оруулаарай.'),
                const SizedBox(height: 24),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'sale',
                      label: Text('Худалдах'),
                      icon: Icon(Icons.sell_outlined),
                    ),
                    ButtonSegment(
                      value: 'rent',
                      label: Text('Түрээслэх'),
                      icon: Icon(Icons.key_outlined),
                    ),
                  ],
                  selected: {listingType},
                  onSelectionChanged: saving
                      ? null
                      : (s) => setState(() => listingType = s.first),
                ),
                const SizedBox(height: 20),
                field('title', 'Зарын гарчиг'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: propertyType,
                  decoration: const InputDecoration(
                    labelText: 'Үл хөдлөхийн төрөл',
                  ),
                  items: propertyTypes.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: saving
                      ? null
                      : (v) => setState(() => propertyType = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: district,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Дүүрэг'),
                  items: districtChoices
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: saving
                      ? null
                      : (v) {
                          setState(() {
                            district = v!;
                            complexId = null;
                            complexes = [];
                          });
                          loadComplexes();
                        },
                ),
                const SizedBox(height: 16),
                if (loadingComplexes) const LinearProgressIndicator(),
                if (complexError != null)
                  TextButton(
                    onPressed: loadComplexes,
                    child: Text(
                      'Хотхон ачаалж чадсангүй. Дахин оролдох: $complexError',
                    ),
                  ),
                DropdownButtonFormField<int>(
                  key: ValueKey('$district-$complexId-${complexes.length}'),
                  initialValue: complexId,
                  isExpanded: true,
                  menuMaxHeight: 320,
                  decoration: InputDecoration(
                    labelText: 'Хотхон (сонголтоор)',
                    helperText:
                        '${complexes.length} хотхон • Сонгосон дүүргээр шүүнэ',
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: 0,
                      child: Text('Хотхон сонгохгүй'),
                    ),
                    if (complexId != null &&
                        !complexes.any((c) => c['id'] == complexId))
                      DropdownMenuItem(
                        value: complexId,
                        child: Text('Сонгосон хотхон #$complexId'),
                      ),
                    ...complexes.map(
                      (c) => DropdownMenuItem(
                        value: c['id'] as int,
                        child: Text(
                          '${c['name']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: saving || loadingComplexes
                      ? null
                      : (v) => setState(() => complexId = v == 0 ? null : v),
                ),
                const SizedBox(height: 16),
                field('location', 'Хотхон, хаяг'),
                const SizedBox(height: 8),
                const Text(
                  'Хотхон, гудамж, байрны дугаарыг бичнэ үү. Газрын зургийн цэгийг тусад нь сонгоно.',
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.location_on_outlined),
                  label: Text(
                    mapPoint == null
                        ? 'Газрын зураг дээр цэг сонгох'
                        : 'Байршлын цэгийг өөрчлөх',
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          final point = await Navigator.push<MapPoint>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  LocationPickerPage(initialPoint: mapPoint),
                            ),
                          );
                          if (point != null && mounted) {
                            setState(() => mapPoint = point);
                          }
                        },
                ),
                if (mapPoint != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Байршил сонгосон: ${mapPoint!.latitude.toStringAsFixed(5)}, ${mapPoint!.longitude.toStringAsFixed(5)}',
                        ),
                      ),
                      TextButton(
                        onPressed: saving
                            ? null
                            : () => setState(() => mapPoint = null),
                        child: const Text('Цэг арилгах'),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                field(
                  'price',
                  listingType == 'rent'
                      ? 'Сарын түрээс • ₮'
                      : 'Худалдах үнэ • ₮',
                  numeric: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: field('area', 'Талбай • м²', numeric: true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: field('rooms', 'Өрөө', numeric: true)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: field('floor', 'Давхар', numeric: true)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: field(
                        'total_floors',
                        'Нийт давхар',
                        numeric: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                field('contact_phone', 'Холбогдох утас'),
                const SizedBox(height: 16),
                field('description', 'Дэлгэрэнгүй тайлбар', lines: 5),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Байрны зураг • $photoCount/12',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: saving || picking || photoCount >= 12
                          ? null
                          : pickPhotos,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(picking ? 'Нээж байна...' : 'Зураг нэмэх'),
                    ),
                  ],
                ),
                const Text(
                  'Хамгийн ихдээ 12 зураг, зураг бүр 10 MB хүртэл.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (photoCount == 0)
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 40,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (cover != null && !removeCover)
                        photo(
                          PropertyImageView(url: cover),
                          () => setState(() => removeCover = true),
                        ),
                      ...existing.map(
                        (p) => photo(
                          PropertyImageView(url: p.url),
                          () => setState(() {
                            existing.remove(p);
                            removed.add(p.id);
                          }),
                        ),
                      ),
                      ...selected.map(
                        (p) => photo(
                          Image.memory(photoBytes[p]!, fit: BoxFit.cover),
                          () => setState(() {
                            selected.remove(p);
                            photoBytes.remove(p);
                          }),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 30),
                FilledButton.icon(
                  onPressed: saving || picking ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(saving ? 'Хадгалж байна...' : 'Зараа хадгалах'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
