import 'package:flutter/material.dart';

import '../services/app_store.dart';
import '../widgets/property_card.dart';
import 'property_page.dart';

Future<List<Map<String, dynamic>>> adminChoices(
  BuildContext context,
  String path,
) async {
  final api = AppScope.read(context).api;
  final entries = <Map<String, dynamic>>[];
  var page = 1;
  while (true) {
    final result = await api.request(
      'GET',
      path,
      query: {'page_size': '100', 'page': '$page'},
    ) as Map<String, dynamic>;
    entries.addAll((result['results'] as List).cast<Map<String, dynamic>>());
    if (result['next'] == null) return entries;
    page++;
  }
}

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  String kind = 'complexes';
  List<Map<String, dynamic>> entries = [];
  bool started = false, loading = true;
  String? error;
  int requestId = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      load();
    }
  }

  Future<void> load() async {
    final id = ++requestId;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await adminChoices(context, '$kind/');
      if (mounted && id == requestId) setState(() => entries = result);
    } catch (e) {
      if (mounted && id == requestId) setState(() => error = '$e');
    } finally {
      if (mounted && id == requestId) setState(() => loading = false);
    }
  }

  Future<void> edit([Map<String, dynamic>? entry]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChoiceEditPage(kind: kind, entry: entry),
      ),
    );
    if (saved == true && mounted) {
      AppScope.read(context).changed();
      await load();
    }
  }

  Future<void> remove(Map<String, dynamic> entry) async {
    final api = AppScope.read(context).api;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${entry['name']} устгах уу?'),
        content: Text(
          kind == 'complexes'
              ? 'Үнэлгээ, сэтгэгдэлтэй хотхоныг устгах боломжгүй. Бусад хотхоныг хасахад зарууд хадгалагдаж, хотхоны холбоос сална.'
              : 'Зар, хотхонтой холбоогүй дүүргийг устгана.',
        ),
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
    if (accepted != true || !mounted) return;
    setState(() => loading = true);
    try {
      await api.request('DELETE', '$kind/${entry['id']}/');
      if (!mounted) return;
      AppScope.read(context).changed();
      await load();
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        showMessage(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppScope.of(context).isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Админ удирдлага')),
        body: const Center(child: Text('Админ эрх шаардлагатай.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Админ удирдлага'),
        actions: [
          IconButton(
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading ? null : () => edit(),
        icon: const Icon(Icons.add),
        label: Text(kind == 'complexes' ? 'Хотхон нэмэх' : 'Дүүрэг нэмэх'),
      ),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.home_work),
            title: const Text('Бүх зар удирдах'),
            subtitle: const Text('Бүх хэрэглэгчийн зарыг засах, устгах'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PropertyPage(standalone: true),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'complexes', label: Text('Хотхонууд')),
                ButtonSegment(value: 'districts', label: Text('Дүүргүүд')),
              ],
              selected: {kind},
              onSelectionChanged: (s) {
                setState(() => kind = s.first);
                load();
              },
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? EmptyState(
                    title: 'Ачаалж чадсангүй',
                    message: error!,
                    onRetry: load,
                  )
                : entries.isEmpty
                ? const Center(child: Text('Сонголт нэмээрэй.'))
                : RefreshIndicator(
                    onRefresh: load,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return ListTile(
                          title: Text('${entry['name']}'),
                          subtitle: kind == 'complexes'
                              ? Text(
                                  '${entry['district_name']} • ${entry['address'] ?? ''}',
                                )
                              : null,
                          onTap: () => edit(entry),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Засах',
                                onPressed: () => edit(entry),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Устгах',
                                onPressed: () => remove(entry),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class ChoiceEditPage extends StatefulWidget {
  final String kind;
  final Map<String, dynamic>? entry;
  const ChoiceEditPage({super.key, required this.kind, this.entry});
  @override
  State<ChoiceEditPage> createState() => _ChoiceEditPageState();
}

class _ChoiceEditPageState extends State<ChoiceEditPage> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, address, description;
  List<Map<String, dynamic>> districts = [];
  int? districtId;
  bool initialized = false, loading = false, saving = false;
  String? error;
  bool get isComplex => widget.kind == 'complexes';
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.entry?['name'] as String?);
    address = TextEditingController(text: widget.entry?['address'] as String?);
    description = TextEditingController(
      text: widget.entry?['description'] as String?,
    );
    districtId = widget.entry?['district'] as int?;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      if (isComplex) loadDistricts();
    }
  }

  Future<void> loadDistricts() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await adminChoices(context, 'districts/');
      if (mounted) setState(() => districts = result);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    address.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final api = AppScope.read(context).api;
    setState(() => saving = true);
    try {
      await api.request(
        widget.entry == null ? 'POST' : 'PATCH',
        '${widget.kind}/${widget.entry == null ? '' : '${widget.entry!['id']}/'}',
        body: {
          'name': name.text.trim(),
          'description': description.text.trim(),
          if (isComplex) 'address': address.text.trim(),
          if (isComplex) 'district': districtId,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        '${isComplex ? 'Хотхон' : 'Дүүрэг'} ${widget.entry == null ? 'нэмэх' : 'засах'}',
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: name,
              enabled: !saving,
              maxLength: isComplex ? 160 : 80,
              decoration: const InputDecoration(labelText: 'Нэр'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Нэр оруулна уу.' : null,
            ),
            const SizedBox(height: 16),
            if (isComplex) ...[
              if (loading) const LinearProgressIndicator(),
              if (error != null)
                TextButton(
                  onPressed: loadDistricts,
                  child: Text('Дахин ачаалах: $error'),
                ),
              DropdownButtonFormField<int>(
                key: ValueKey(districts.length),
                initialValue: districts.any((d) => d['id'] == districtId)
                    ? districtId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Дүүрэг'),
                items: districts
                    .map(
                      (d) => DropdownMenuItem(
                        value: d['id'] as int,
                        child: Text('${d['name']}'),
                      ),
                    )
                    .toList(),
                onChanged: saving
                    ? null
                    : (v) => setState(() => districtId = v),
                validator: (v) => v == null ? 'Дүүрэг сонгоно уу.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: address,
                enabled: !saving,
                maxLength: 255,
                decoration: const InputDecoration(labelText: 'Хаяг'),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: description,
              enabled: !saving,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Тайлбар'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: saving || loading || error != null ? null : save,
              child: Text(saving ? 'Хадгалж байна...' : 'Хадгалах'),
            ),
          ],
        ),
      ),
    ),
  );
}
