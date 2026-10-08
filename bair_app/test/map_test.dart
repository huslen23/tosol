import 'package:bair_app/widgets/location_map.dart';
import 'package:bair_app/screens/property_map_page.dart';
import 'package:bair_app/services/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'widget_test.dart' as fixtures;

void main() {
  testWidgets('map search preserves filters and opens the selected listing', (
    tester,
  ) async {
    await fixtures.mobileSize(tester);
    final requests = <http.Request>[];
    final store = fixtures.testStore(
      requests,
      handler: (request) async {
        if (request.url.path == '/api/properties/') {
          return fixtures.jsonResponse({
            'count': 1,
            'next': null,
            'results': [
              {...fixtures.sample, 'latitude': 47.9185, 'longitude': 106.9177},
            ],
          });
        }
        return http.Response('', 418);
      },
    );
    await tester.pumpWidget(
      AppScope(
        store: store,
        child: MaterialApp(
          home: PropertyMapPage(
            query: const {
              'district': 'Хан-Уул',
              'max_price': '400000000',
              'saved': 'true',
            },
            tileBuilder: (_) => const ColoredBox(color: Colors.grey),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = requests.last.url.queryParameters;
    expect(first['district'], 'Хан-Уул');
    expect(first['max_price'], '400000000');
    expect(first['saved'], 'true');
    expect(first['located'], 'true');
    expect(first['bbox']!.split(',').length, 4);
    await tester.tap(find.text('350,000,000 ₮'));
    await tester.pumpAndSettle();
    expect(find.text(fixtures.sample['title'] as String), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    store.api.client.close();
  });
  testWidgets(
    'map picks coordinates, updates bounds after pan and zoom, and opens pins',
    (tester) async {
      MapPoint? selected;
      String? bounds;
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: LocationMap(
                initialCenter: const MapPoint(47.9185, 106.9177),
                tileBuilder: (_) => const ColoredBox(color: Colors.grey),
                onSelect: (p) => selected = p,
                onBoundsChanged: (b) => bounds = b,
                pins: [
                  MapPin(
                    const MapPoint(47.9185, 106.9177),
                    '350 сая',
                    onTap: () => opened = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initialBounds = bounds!;
      final values = initialBounds.split(',').map(double.parse).toList();
      expect(values[0], lessThan(106.9177));
      expect(values[2], greaterThan(106.9177));
      expect(values[1], lessThan(47.9185));
      expect(values[3], greaterThan(47.9185));
      await tester.tap(find.text('350 сая'));
      expect(opened, isTrue);
      await tester.tapAt(const Offset(300, 200));
      expect(selected!.latitude, closeTo(47.9185, 0.00001));
      expect(selected!.longitude, closeTo(106.9177, 0.00001));
      await tester.dragFrom(const Offset(150, 200), const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(bounds, isNot(initialBounds));
      final beforeZoom = bounds!;
      await tester.tap(find.byTooltip('Томруулах'));
      await tester.pumpAndSettle();
      final before = beforeZoom.split(',').map(double.parse).toList();
      final after = bounds!.split(',').map(double.parse).toList();
      expect(
        after[2] - after[0],
        closeTo((before[2] - before[0]) / 2, 0.000001),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
