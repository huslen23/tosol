import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'map_tile.dart';

class MapPoint {
  final double latitude, longitude;
  const MapPoint(this.latitude, this.longitude);
}

class MapPin {
  final MapPoint point;
  final String label;
  final VoidCallback? onTap;
  const MapPin(this.point, this.label, {this.onTap});
}

/// Web Mercator map. Coordinates are stored separately from the written address.
class LocationMap extends StatefulWidget {
  final MapPoint initialCenter;
  final List<MapPin> pins;
  final ValueChanged<MapPoint>? onSelect;
  final ValueChanged<String>? onBoundsChanged;
  final Widget Function(String url)? tileBuilder;
  const LocationMap({
    super.key,
    this.initialCenter = const MapPoint(47.9185, 106.9177),
    this.pins = const [],
    this.onSelect,
    this.onBoundsChanged,
    this.tileBuilder,
  });
  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
  late MapPoint center;
  int zoom = 13;
  Size size = Size.zero;
  bool tileError = false;
  int tileRevision = 0;
  void reportTileError() {
    if (!tileError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !tileError) setState(() => tileError = true);
      });
    }
  }

  double get world => 256.0 * math.pow(2, zoom);
  @override
  void initState() {
    super.initState();
    center = widget.initialCenter;
  }

  Offset project(MapPoint p) {
    final latitude =
        p.latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180;
    return Offset(
      (p.longitude + 180) / 360 * world,
      (1 - math.log(math.tan(latitude) + 1 / math.cos(latitude)) / math.pi) /
          2 *
          world,
    );
  }

  MapPoint unproject(Offset p) {
    final y = (math.pi * (1 - 2 * p.dy.clamp(0, world) / world));
    return MapPoint(
      math.atan((math.exp(y) - math.exp(-y)) / 2) * 180 / math.pi,
      (p.dx / world * 360 - 180).clamp(-180, 180).toDouble(),
    );
  }

  void notifyBounds() {
    final c = project(center);
    final nw = unproject(c - Offset(size.width / 2, size.height / 2));
    final se = unproject(c + Offset(size.width / 2, size.height / 2));
    widget.onBoundsChanged?.call(
      '${nw.longitude},${se.latitude},${se.longitude},${nw.latitude}',
    );
  }

  void changeZoom(int delta) {
    setState(() {
      zoom = (zoom + delta).clamp(2, 18);
      tileError = false;
    });
    notifyBounds();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final nextSize = Size(constraints.maxWidth, constraints.maxHeight);
      if (size != nextSize) {
        size = nextSize;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) notifyBounds();
        });
      }
      final origin = project(center) - Offset(size.width / 2, size.height / 2);
      final tiles = <Widget>[];
      final count = math.pow(2, zoom).toInt();
      for (
        var x = (origin.dx / 256).floor();
        x <= ((origin.dx + size.width) / 256).floor();
        x++
      ) {
        for (
          var y = (origin.dy / 256).floor();
          y <= ((origin.dy + size.height) / 256).floor();
          y++
        ) {
          if (x < 0 || y < 0 || x >= count || y >= count) {
            continue;
          }
          tiles.add(
            Positioned(
              key: ValueKey('$zoom/$x/$y/$tileRevision'),
              left: x * 256 - origin.dx,
              top: y * 256 - origin.dy,
              width: 256,
              height: 256,
              child:
                  widget.tileBuilder?.call(
                    'https://tile.openstreetmap.org/$zoom/$x/$y.png',
                  ) ??
                  mapTile(
                    'https://tile.openstreetmap.org/$zoom/$x/$y.png',
                    reportTileError,
                  ),
            ),
          );
        }
      }
      return ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) => setState(
                  () => center = unproject(project(center) - details.delta),
                ),
                onPanEnd: (_) => notifyBounds(),
                onTapUp: widget.onSelect == null
                    ? null
                    : (details) => widget.onSelect!(
                        unproject(origin + details.localPosition),
                      ),
                child: ColoredBox(
                  color: const Color(0xFFF1F5F9),
                  child: Stack(children: tiles),
                ),
              ),
            ),
            for (final pin in widget.pins)
              Positioned(
                left: project(pin.point).dx - origin.dx - 55,
                top: project(pin.point).dy - origin.dy - 36,
                width: 110,
                height: 36,
                child: Tooltip(
                  message: pin.label,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed: pin.onTap ?? () {},
                    child: Text(
                      pin.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 8,
              top: 8,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: null,
                    tooltip: 'Томруулах',
                    onPressed: zoom < 18 ? () => changeZoom(1) : null,
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: null,
                    tooltip: 'Жижигрүүлэх',
                    onPressed: zoom > 2 ? () => changeZoom(-1) : null,
                    child: const Icon(Icons.remove),
                  ),
                ],
              ),
            ),
            if (tileError)
              Positioned(
                left: 8,
                right: 64,
                top: 8,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        const Text(
                          'Газрын зураг ачаалж чадсангүй. Интернэтээ шалгана уу.',
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            tileError = false;
                            tileRevision++;
                          }),
                          child: const Text('Дахин ачаалах'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                color: Colors.white,
                child: InkWell(
                  onTap: () => launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class LocationPickerPage extends StatefulWidget {
  final MapPoint? initialPoint;
  const LocationPickerPage({super.key, this.initialPoint});
  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  MapPoint? point;
  @override
  void initState() {
    super.initState();
    point = widget.initialPoint;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Байрны байршил сонгох')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Газрын зургийг хөдөлгөж, байрныхаа цэгийг дарж сонгоно уу.',
          ),
        ),
        Expanded(
          child: LocationMap(
            initialCenter: point ?? const MapPoint(47.9185, 106.9177),
            onSelect: (p) => setState(() => point = p),
            pins: [if (point != null) MapPin(point!, 'Сонгосон цэг')],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: point == null
                  ? null
                  : () => Navigator.pop(context, point),
              child: const Text('Энэ байршлыг сонгох'),
            ),
          ),
        ),
      ],
    ),
  );
}
