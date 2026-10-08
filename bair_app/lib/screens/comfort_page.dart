import 'package:flutter/material.dart';

import '../services/app_store.dart';
import '../widgets/property_card.dart';

class ComfortPage extends StatefulWidget {
  final int complexId;
  final String name;
  const ComfortPage({super.key, required this.complexId, required this.name});
  @override
  State<ComfortPage> createState() => _ComfortPageState();
}

class _ComfortPageState extends State<ComfortPage> {
  Map<String, dynamic>? summary;
  final comments = <Map<String, dynamic>>[];
  final comment = TextEditingController();
  bool started = false, loading = true, busy = false, loadingMore = false;
  bool hasNext = false;
  int page = 1;
  String? error;
  String get path => 'complexes/${widget.complexId}/';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      load();
    }
  }

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final api = AppScope.read(context).api;
    try {
      final results = await Future.wait([
        api.request('GET', '${path}comfort/'),
        api.request('GET', '${path}comments/'),
      ]);
      if (!mounted) return;
      final result = results[1] as Map<String, dynamic>;
      setState(() {
        summary = results[0] as Map<String, dynamic>;
        comments
          ..clear()
          ..addAll((result['results'] as List).cast<Map<String, dynamic>>());
        page = 1;
        hasNext = result['next'] != null;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> moreComments() async {
    if (loadingMore) return;
    setState(() => loadingMore = true);
    try {
      final result = await AppScope.read(context).api.request(
        'GET',
        '${path}comments/',
        query: {'page': '${page + 1}'},
      ) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        comments.addAll(
          (result['results'] as List).cast<Map<String, dynamic>>(),
        );
        page++;
        hasNext = result['next'] != null;
      });
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  Future<void> editRating({bool weights = false}) async {
    if (!await requireLogin(context) || !mounted) return;
    // Reload personalized weights and own scores after guest login.
    await load();
    if (!mounted || error != null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ComfortEditPage(
          complexId: widget.complexId,
          data: summary!,
          weights: weights,
        ),
      ),
    );
    if (saved == true && mounted) await load();
  }

  Future<void> saveComment([Map<String, dynamic>? existing]) async {
    if (!await requireLogin(context) || !mounted) return;
    String text = comment.text.trim();
    if (existing != null) {
      final controller = TextEditingController(
        text: existing['text'] as String,
      );
      final route = DialogRoute<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Сэтгэгдэл засах'),
          content: TextField(
            controller: controller,
            maxLength: 2000,
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Болих'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(c, controller.text.trim());
                }
              },
              child: const Text('Хадгалах'),
            ),
          ],
        ),
      );
      final result = await Navigator.of(context).push(route);
      await route.completed;
      controller.dispose();
      if (result == null || !mounted) return;
      text = result;
    }
    if (text.isEmpty || text.length > 2000) {
      showMessage(context, '1–2000 тэмдэгттэй сэтгэгдэл бичнэ үү.');
      return;
    }
    setState(() => busy = true);
    try {
      await AppScope.read(context).api.request(
        existing == null ? 'POST' : 'PATCH',
        '${path}comments/${existing == null ? '' : '${existing['id']}/'}',
        body: {'text': text},
      );
      if (!mounted) return;
      if (existing == null) comment.clear();
      await load();
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteComment(Map<String, dynamic> item) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Сэтгэгдлээ устгах уу?'),
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
    setState(() => busy = true);
    try {
      await AppScope.read(context).api
          .request('DELETE', '${path}comments/${item['id']}/');
      if (mounted) await load();
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = summary;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.name} • Тав тух')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? EmptyState(
              title: 'Үнэлгээ ачаалж чадсангүй',
              message: error!,
              onRetry: load,
            )
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Тав тухын үнэлгээ',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(data!['score'] as num).toStringAsFixed(1)} / 100',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                avatar: const Icon(Icons.people_outline),
                                label: Text(
                                  '${data['rating_count']} хүн үнэлсэн',
                                ),
                              ),
                              Chip(
                                avatar: const Icon(Icons.fact_check_outlined),
                                label: Text(
                                  '${data['rated_criteria_count'] ?? (data['criteria'] as List).where((r) => (r['count'] as num) > 0).length}/${data['total_criteria_count'] ?? (data['criteria'] as List).length} шалгуур үнэлэгдсэн',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Мэдээллийн хамрагдалт: ${(data['coverage'] as num).toStringAsFixed(1)}%',
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value:
                                (data['coverage'] as num).toDouble().clamp(
                                  0,
                                  100,
                                ) /
                                100,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Хамрагдалт нь таны сонгосон жингийн хэдэн хувьд бодит хэрэглэгчийн үнэлгээ байгааг харуулна. Олон хүн үнэлсэн гэсэн утга биш.',
                          ),
                          if ((data['rating_count'] as num) == 0)
                            const Text(
                              'Үнэлгээ хараахан алга. 50 нь түр анхдагч утга.',
                              style: TextStyle(color: Colors.deepOrange),
                            )
                          else if ((data['rating_count'] as num) < 5)
                            const Text(
                              'Цөөн хүний үнэлгээтэй. Оноо шинэ үнэлгээ нэмэгдэхэд мэдэгдэхүйц өөрчлөгдөж болно.',
                              style: TextStyle(color: Colors.deepOrange),
                            ),
                          if (data['latest_rating_at'] != null)
                            Text(
                              'Сүүлд үнэлсэн: ${'${data['latest_rating_at']}'.split('T').first}',
                            ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    data['is_default'] == true
                        ? 'Анхдагч 50 оноо • Таны жинтэй шалгуурт мэдээлэл хараахан алга.'
                        : '${data['rating_count']} хэрэглэгчийн үнэлгээ',
                  ),
                  if (data['rankable'] != true)
                    const Text(
                      'Мэдээлэл хангалтгүй • Эцсийн эрэмбэд ашиглахгүй.',
                      style: TextStyle(color: Colors.deepOrange),
                    ),
                  const SizedBox(height: 8),
                  Text('${data['quality_note']}'),
                  const SizedBox(height: 8),
                  const Text(
                    'Жин нь судалгаагаар батлагдсан үр дүн биш, эхний загвар. 100 нь хамгийн таатай, 0 нь хамгийн таагүй. Оноо нь нэг зарын үнэлгээ биш, хотхоны нийтлэг нөхцөлийн үнэлгээ.',
                  ),
                  const SizedBox(height: 16),
                  ...((data['criteria'] as List).cast<Map<String, dynamic>>()).map(
                    (row) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${row['label']} • ${row['weight']}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              row['origin'] == 'default'
                                  ? 'Үнэлгээ алга • Түр анхдагч 50'
                                  : '${(row['score'] as num).toStringAsFixed(1)} / 100 • ${row['count']} хүн үнэлсэн',
                            ),
                            LinearProgressIndicator(
                              value: row['origin'] == 'default'
                                  ? 0
                                  : (row['score'] as num).toDouble() / 100,
                            ),
                            const SizedBox(height: 6),
                            Text('${row['hint']}'),
                            if (row['origin'] != 'default')
                              Text(
                                (row['score'] as num) >= 70
                                    ? 'Давуу тал'
                                    : (row['score'] as num) <= 40
                                    ? 'Сайжруулах шаардлагатай'
                                    : 'Дундаж үнэлгээ',
                              ),
                            Text('Эх сурвалж: ${row['source']}'),
                            Text(
                              'Огноо: ${row['collected_at'] == null ? 'Мэдээлэлгүй' : '${row['collected_at']}'.split('T').first} • Баталгаажаагүй',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: busy ? null : editRating,
                    child: Text(
                      (data['my_scores'] as Map).isEmpty
                          ? 'Үнэлгээ өгөх'
                          : 'Миний үнэлгээг засах',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : () => editRating(weights: true),
                    child: const Text('Миний шалгуурын жин'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Сэтгэгдэл • ${data['comment_count']}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Text(''),
                  const SizedBox(height: 12),
                  TextField(
                    controller: comment,
                    enabled: !busy,
                    maxLength: 2000,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Сэтгэгдэл бичих',
                      hintText: 'Хотхоны талаарх туршлагаа хуваалцаарай.',
                    ),
                  ),
                  FilledButton(
                    onPressed: busy ? null : () => saveComment(),
                    child: const Text('Сэтгэгдэл нийтлэх'),
                  ),
                  if (comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Сэтгэгдэл хараахан алга.'),
                    ),
                  ...comments.map(
                    (item) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item['username']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('${item['created_at']}'.split('T').first),
                            const SizedBox(height: 8),
                            Text('${item['text']}'),
                            Row(
                              children: [
                                if (item['can_edit'] == true)
                                  TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => saveComment(item),
                                    child: const Text('Засах'),
                                  ),
                                if (item['can_delete'] == true)
                                  TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => deleteComment(item),
                                    child: const Text('Устгах'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (hasNext)
                    OutlinedButton(
                      onPressed: loadingMore || busy ? null : moreComments,
                      child: const Text('Өмнөх сэтгэгдлүүд'),
                    ),
                ],
              ),
            ),
    );
  }
}

class ComfortEditPage extends StatefulWidget {
  final int complexId;
  final Map<String, dynamic> data;
  final bool weights;
  const ComfortEditPage({
    super.key,
    required this.complexId,
    required this.data,
    this.weights = false,
  });
  @override
  State<ComfortEditPage> createState() => _ComfortEditPageState();
}

class _ComfortEditPageState extends State<ComfortEditPage> {
  final values = <String, double>{};
  final controllers = <String, TextEditingController>{};
  late final TextEditingController explanation;
  bool busy = false;
  late final List<Map<String, dynamic>> rows;
  @override
  void initState() {
    super.initState();
    explanation = TextEditingController(
      text: widget.data['my_explanation'] as String? ?? '',
    );
    rows = (widget.data['criteria'] as List).cast<Map<String, dynamic>>();
    final initial =
        widget.data[widget.weights ? 'weights' : 'my_scores'] as Map;
    for (final row in rows) {
      final key = row['key'] as String;
      if (initial[key] != null) values[key] = (initial[key] as num).toDouble();
      if (widget.weights) {
        controllers[key] = TextEditingController(text: '${initial[key]}');
      }
    }
  }

  @override
  void dispose() {
    explanation.dispose();
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save({bool remove = false}) async {
    if (widget.weights) {
      values.clear();
      for (final entry in controllers.entries) {
        final value = double.tryParse(entry.value.text.trim());
        if (value == null || !value.isFinite || value < 0 || value > 100) {
          showMessage(context, 'Жин 0–100 хооронд байна.');
          return;
        }
        values[entry.key] = value;
      }
      if ((values.values.fold(0.0, (a, b) => a + b) - 100).abs() > 0.000001) {
        showMessage(context, 'Нийт жин 100% байна.');
        return;
      }
    } else if (!remove && values.isEmpty) {
      showMessage(context, 'Мэдэх нэг шалгуураа сонгож үнэлнэ үү.');
      return;
    }
    if (remove) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Үнэлгээгээ хасах уу?'),
          content: const Text('Үнэлгээтэй хамт бичсэн тайлбар мөн хасагдана.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Болих'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Хасах'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }
    setState(() => busy = true);
    try {
      await AppScope.read(context).api.request(
        remove ? 'DELETE' : 'PUT',
        widget.weights
            ? 'complexes/weights/'
            : 'complexes/${widget.complexId}/my-rating/',
        body: remove
            ? null
            : {
                widget.weights ? 'weights' : 'scores': values,
                if (!widget.weights) 'explanation': explanation.text.trim(),
              },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.weights ? 'Шалгуурын жин' : 'Миний хотхоны үнэлгээ'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.weights
              ? 'Нийт жин 100% байна. Энэ тохиргоо бүх хотхоны зөвхөн танд харагдах нийлбэр оноонд үйлчилнэ; бусдын үнэлгээг өөрчлөхгүй.'
              : 'Өөрийн мэдэх шалгуурыг сонгоод 0–100 оноогоор үнэлнэ үү. Мэдэхгүйг орхино. Хэрэглэгч бүр хотхонд нэг үнэлгээтэй; хадгалах нь өмнөхийг шинэчилнэ.',
        ),
        if (widget.weights)
          Text(
            'Нийт: ${controllers.values.fold<double>(0, (sum, c) => sum + (double.tryParse(c.text) ?? 0)).toStringAsFixed(1)}%',
          ),
        const SizedBox(height: 16),
        ...rows.map((row) {
          final key = row['key'] as String;
          if (widget.weights) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: controllers[key],
                enabled: !busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: '${row['label']} • %'),
                onChanged: (_) => setState(() {}),
              ),
            );
          }
          return Card(
            child: Column(
              children: [
                CheckboxListTile(
                  value: values.containsKey(key),
                  onChanged: busy
                      ? null
                      : (selected) => setState(() {
                          if (selected == true) {
                            values[key] = 50;
                          } else {
                            values.remove(key);
                          }
                        }),
                  title: Text('${row['label']}'),
                  subtitle: Text('${row['hint']}'),
                ),
                if (values.containsKey(key)) ...[
                  Text('${values[key]!.toStringAsFixed(0)} / 100'),
                  Slider(
                    value: values[key]!,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: values[key]!.toStringAsFixed(0),
                    onChanged: busy
                        ? null
                        : (v) => setState(() => values[key] = v),
                  ),
                ],
              ],
            ),
          );
        }),
        if (widget.weights)
          TextButton(
            onPressed: busy
                ? null
                : () => setState(() {
                    final defaults = widget.data['default_weights'] as Map;
                    for (final entry in controllers.entries) {
                      entry.value.text = '${defaults[entry.key]}';
                    }
                  }),
            child: const Text('Анхдагч жинг сэргээх'),
          ),
        if (!widget.weights) ...[
          const SizedBox(height: 16),
          TextField(
            controller: explanation,
            enabled: !busy,
            maxLength: 2000,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Үнэлгээний тайлбар (заавал биш)',
              hintText: 'Хоосон орхиж болно.',
              helperText:
                  'Бичсэн тайлбар сэтгэгдлийн хэсэгт бүх хүнд харагдана.',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Хадгалж байна...' : 'Хадгалах'),
        ),
        if (!widget.weights && (widget.data['my_scores'] as Map).isNotEmpty)
          TextButton(
            onPressed: busy ? null : () => save(remove: true),
            child: const Text('Миний үнэлгээг хасах'),
          ),
      ],
    ),
  );
}
