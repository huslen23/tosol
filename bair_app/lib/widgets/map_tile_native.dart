import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

Widget mapTile(String url, VoidCallback onError) =>
    _CachedMapTile(url, onError);

class _CachedMapTile extends StatefulWidget {
  final String url;
  final VoidCallback onError;
  const _CachedMapTile(this.url, this.onError);
  @override
  State<_CachedMapTile> createState() => _CachedMapTileState();
}

class _CachedMapTileState extends State<_CachedMapTile> {
  late Future<Uint8List> bytes;
  @override
  void initState() {
    super.initState();
    bytes = load();
  }

  @override
  void didUpdateWidget(covariant _CachedMapTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) bytes = load();
  }

  Future<Uint8List> load() async {
    final file = File(
      '${Directory.systemTemp.path}/urgoo-map-tiles/${Uri.parse(widget.url).pathSegments.join('-')}',
    );
    try {
      if (await file.exists() &&
          DateTime.now().difference(await file.lastModified()) <
              const Duration(days: 7)) {
        return await file.readAsBytes();
      }
    } on FileSystemException {
      /* A missing cache must not prevent map display. */
    }
    final response = await http
        .get(
          Uri.parse(widget.url),
          headers: const {'User-Agent': 'UrgooBair/1.0'},
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw HttpException('Tile ${response.statusCode}');
    }
    try {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes, flush: true);
    } on FileSystemException {
      /* Read-only devices can still display downloaded tiles. */
    }
    return response.bodyBytes;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: bytes,
    builder: (_, snapshot) {
      if (snapshot.hasError) {
        widget.onError();
        return const ColoredBox(color: Color(0xFFF1F5F9));
      }
      if (!snapshot.hasData) return const ColoredBox(color: Color(0xFFF1F5F9));
      return Image.memory(
        snapshot.data!,
        fit: BoxFit.fill,
        gaplessPlayback: true,
        errorBuilder: (_, error, stack) {
          widget.onError();
          return const ColoredBox(color: Color(0xFFF1F5F9));
        },
      );
    },
  );
}
