import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bair_app/main.dart';
import 'package:bair_app/models/property.dart';
import 'package:bair_app/screens/compare_page.dart';
import 'package:bair_app/screens/discovery_page.dart';
import 'package:bair_app/screens/property_form_page.dart';
import 'package:bair_app/services/api_client.dart';
import 'package:bair_app/services/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'widget_test.dart' as fixtures;

Widget screen(AppStore store, Widget page) => AppScope(
  store: store,
  child: MaterialApp(home: page),
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final kind in ['districts', 'complexes']) {
    testWidgets('$kind pagination, detail and related listings navigation', (
      tester,
    ) async {
      await fixtures.mobileSize(tester);
      final requests = <http.Request>[];
      final store = fixtures.testStore(
        requests,
        handler: (r) async {
          final data = {
            'id': 7,
            'name': 'Хан-Уул',
            'property_count': 1,
            'description': 'Бодит мэдээлэл',
            'district_name': 'Хан-Уул',
            'address': 'Зайсан',
            'average_sale_price_per_m2': '5000000.00',
          };
          if (r.url.path == '/api/$kind/') {
            final more = r.url.queryParameters['page'] == '2';
            return fixtures.jsonResponse({
              'count': 2,
              'next': more ? null : 'http://localhost/api/$kind/?page=2',
              'results': [
                {
                  ...data,
                  if (more) 'id': 8,
                  if (more) 'name': 'Дараагийн мэдээлэл',
                },
              ],
            });
          }
          if (r.url.path == '/api/$kind/7/') return fixtures.jsonResponse(data);
          return http.Response('', 418);
        },
      );
      await tester.pumpWidget(
        screen(store, DiscoveryPage(kind: kind, title: 'Судлах')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Цааш үзэх'));
      await tester.pumpAndSettle();
      expect(find.text('Дараагийн мэдээлэл'), findsOneWidget);
      await tester.tap(find.text('Хан-Уул'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Заруудыг үзэх'));
      await tester.pumpAndSettle();
      final request = requests.lastWhere(
        (r) => r.url.path == '/api/properties/',
      );
      final key = kind == 'districts' ? 'district' : 'complex';
      expect(
        request.url.queryParameters[key],
        kind == 'districts' ? 'Хан-Уул' : '7',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }

  testWidgets(
    'comparison preserves available listings when another is deleted',
    (tester) async {
      await fixtures.mobileSize(tester);
      final store = fixtures.testStore(
        [],
        handler: (r) async {
          if (r.url.path == '/api/properties/2/') {
            return fixtures.jsonResponse({'detail': 'Олдсонгүй'}, 404);
          }
          return http.Response('', 418);
        },
      );
      store.toggleComparison(1);
      store.toggleComparison(2);
      await tester.pumpWidget(screen(store, const ComparePage()));
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Зар #2 боломжгүй болсон.'), findsOneWidget);
      await tester.tap(find.byTooltip('Харьцуулалтаас хасах').first);
      await tester.pumpAndSettle();
      expect(store.comparison, {1});
      await tester.tap(find.byTooltip('Зар үзэх'));
      await tester.pumpAndSettle();
      expect(find.text('Байрны дэлгэрэнгүй'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  test('comparison enforces three listings and allows removal', () {
    final store = fixtures.testStore([]);
    for (final id in [1, 2, 3]) {
      store.toggleComparison(id);
    }
    expect(() => store.toggleComparison(4), throwsA(isA<ApiException>()));
    store.toggleComparison(2);
    store.toggleComparison(4);
    expect(store.comparison, {1, 3, 4});
    store.dispose();
  });

  testWidgets(
    'recommendations validate budget and use recommendation endpoint',
    (tester) async {
      await fixtures.mobileSize(tester);
      final requests = <http.Request>[];
      final store = fixtures.testStore(
        requests,
        handler: (r) async {
          if (r.url.path == '/api/properties/recommendations/') {
            return fixtures.jsonResponse({
              'count': 1,
              'next': null,
              'results': [fixtures.sample],
            });
          }
          return http.Response('', 418);
        },
      );
      await tester.pumpWidget(BairApp(store: store));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Танд тохирох байр'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Танд тохирох байр')),
        alignment: 0.3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Танд тохирох байр'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Үр дүнг харах'));
      await tester.tap(find.text('Үр дүнг харах'));
      await tester.pumpAndSettle();
      expect(find.text('Төсвөө оруулна уу.'), findsOneWidget);
      final budget = find.widgetWithText(TextFormField, 'Дээд үнэ • ₮');
      await tester.ensureVisible(budget);
      await tester.enterText(budget, '400000000');
      tester.testTextInput.hide();
      await tester.ensureVisible(find.text('Үр дүнг харах'));
      await tester.tap(find.text('Үр дүнг харах'));
      await tester.pumpAndSettle();
      expect(requests.last.url.path, '/api/properties/recommendations/');
      expect(requests.last.url.queryParameters['max_price'], '400000000');
      expect(requests.last.url.queryParameters['listing_type'], 'sale');
      await tester.tap(find.byTooltip('Шүүлтүүр'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Бүх шүүлтүүр арилгах'));
      await tester.tap(find.text('Бүх шүүлтүүр арилгах'));
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['max_price'], '400000000');
      expect(requests.last.url.queryParameters['listing_type'], 'sale');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets('edit form loads complex selection and saves its API id', (
    tester,
  ) async {
    await fixtures.mobileSize(tester);
    final requests = <http.Request>[];
    final store = fixtures.testStore(
      requests,
      authenticated: true,
      handler: (r) async {
        if (r.url.path == '/api/complexes/') {
          return fixtures.jsonResponse({
            'count': 1,
            'next': null,
            'results': [
              {'id': 9, 'name': 'Өргөө хотхон'},
            ],
          });
        }
        if (r.method == 'PATCH') {
          return fixtures.jsonResponse({
            ...fixtures.sample,
            ...jsonDecode(r.body) as Map<String, dynamic>,
          });
        }
        return http.Response('', 418);
      },
    );
    await tester.pumpWidget(
      screen(
        store,
        PropertyFormPage(property: Property.fromJson(fixtures.sample)),
      ),
    );
    await tester.pumpAndSettle();
    final select = find.byType(DropdownButtonFormField<int>);
    await tester.ensureVisible(select);
    await tester.tap(select);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Өргөө хотхон').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Зараа хадгалах'));
    await tester.tap(find.text('Зараа хадгалах'));
    await tester.pumpAndSettle();
    final saved = requests.singleWhere((r) => r.method == 'PATCH');
    expect(jsonDecode(saved.body)['complex'], 9);
    expect(
      requests
          .firstWhere((r) => r.url.path == '/api/complexes/')
          .url
          .queryParameters['district'],
      'Хан-Уул',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets(
    'complex selection includes later pages and saves the selected id',
    (tester) async {
      await fixtures.mobileSize(tester);
      final requests = <http.Request>[];
      final store = fixtures.testStore(
        requests,
        authenticated: true,
        handler: (r) async {
          if (r.url.path == '/api/complexes/') {
            final second = r.url.queryParameters['page'] == '2';
            return fixtures.jsonResponse({
              'count': 101,
              'next': second
                  ? null
                  : 'http://localhost:8000/api/complexes/?page=2',
              'results': second
                  ? [
                      {'id': 1009, 'name': 'Ривер Гарден'},
                    ]
                  : List.generate(
                      100,
                      (i) => {'id': i + 10, 'name': 'Хотхон $i'},
                    ),
            });
          }
          if (r.method == 'PATCH') {
            return fixtures.jsonResponse({
              ...fixtures.sample,
              ...jsonDecode(r.body) as Map<String, dynamic>,
            });
          }
          return http.Response('', 418);
        },
      );
      await tester.pumpWidget(
        screen(
          store,
          PropertyFormPage(property: Property.fromJson(fixtures.sample)),
        ),
      );
      await tester.pumpAndSettle();
      final select = find.byType(DropdownButtonFormField<int>);
      await tester.ensureVisible(select);
      await tester.tap(select);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ривер Гарден').last,
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Ривер Гарден').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Зараа хадгалах'));
      await tester.tap(find.text('Зараа хадгалах'));
      await tester.pumpAndSettle();
      expect(
        jsonDecode(
          requests.singleWhere((r) => r.method == 'PATCH').body,
        )['complex'],
        1009,
      );
      expect(requests.where((r) => r.url.path == '/api/complexes/').length, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets('complex selection ignores stale district responses', (
    tester,
  ) async {
    await fixtures.mobileSize(tester);
    final delayed = Completer<http.Response>();
    final store = fixtures.testStore(
      [],
      handler: (r) async {
        if (r.url.path == '/api/complexes/') {
          if (r.url.queryParameters['district'] == 'Хан-Уул') {
            return delayed.future;
          }
          return fixtures.jsonResponse({
            'count': 1,
            'next': null,
            'results': [
              {'id': 10, 'name': 'Шинэ дүүргийн хотхон'},
            ],
          });
        }
        return http.Response('', 418);
      },
    );
    await tester.pumpWidget(
      screen(
        store,
        PropertyFormPage(property: Property.fromJson(fixtures.sample)),
      ),
    );
    await tester.pump();
    final district = find.byWidgetPredicate(
      (w) =>
          w is DropdownButtonFormField<String> &&
          w.decoration.labelText == 'Дүүрэг',
    );
    await tester.ensureVisible(district);
    await tester.tap(district);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Сүхбаатар').last);
    await tester.pumpAndSettle();
    delayed.complete(
      fixtures.jsonResponse({
        'count': 1,
        'next': null,
        'results': [
          {'id': 9, 'name': 'Хуучин дүүргийн хотхон'},
        ],
      }),
    );
    await tester.pumpAndSettle();
    final complex = find.byType(DropdownButtonFormField<int>);
    await tester.ensureVisible(complex);
    await tester.tap(complex);
    await tester.pumpAndSettle();
    expect(find.text('Шинэ дүүргийн хотхон'), findsOneWidget);
    expect(find.text('Хуучин дүүргийн хотхон'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  test(
    'photo upload translates transport failures into a usable error',
    () async {
      final store = fixtures.testStore(
        [],
        handler: (_) async {
          throw http.ClientException('transport failed');
        },
      );
      await expectLater(
        store.api.uploadPhotos(1, [
          XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'photo.png'),
        ]),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Зураг илгээж чадсангүй. Дахин оролдоно уу.',
          ),
        ),
      );
      store.dispose();
    },
  );
}
