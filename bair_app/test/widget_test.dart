import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bair_app/main.dart';
import 'package:bair_app/services/api_client.dart';
import 'package:bair_app/services/app_store.dart';
import 'package:bair_app/screens/login_page.dart';

const user = {
  'id': 1,
  'email': 'bat@test.mn',
  'first_name': 'Бат',
  'last_name': 'Дорж',
};
final sample = <String, dynamic>{
  'id': 1,
  'title': 'Зайсанд саруул 3 өрөө байр',
  'description': 'Өмнө зүг рүү харсан цонхтой, дулаан байр.',
  'district': 'Хан-Уул',
  'complex_name': 'Өргөө хотхон',
  'location': 'Зайсан, Өргөө хотхон',
  'listing_type': 'sale',
  'property_type': 'apartment',
  'price': '350000000.00',
  'area': '70.00',
  'rooms': 3,
  'floor': 4,
  'total_floors': 12,
  'contact_phone': '99112233',
  'images': [],
  'image': null,
  'owner': user,
  'is_favorite': false,
  'is_owner': true,
};
http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

AppStore testStore(
  List<http.Request> requests, {
  bool authenticated = false,
  Future<http.Response> Function(http.Request)? handler,
}) {
  bool isSaved = false;
  final client = SessionClient(
    MockClient((request) async {
      requests.add(request);
      if (handler != null) {
        final r = await handler(request);
        if (r.statusCode != 418) return r;
      }
      if (request.url.path == '/api/properties/') {
        return jsonResponse({
          'count': 1,
          'next': null,
          'results': [
            {...sample, 'is_favorite': isSaved},
          ],
        });
      }
      if (request.url.path == '/api/complexes/') {
        return jsonResponse({'count': 0, 'next': null, 'results': []});
      }
      if (request.url.path == '/api/properties/1/') {
        return jsonResponse({...sample, 'is_favorite': isSaved});
      }
      if (request.url.path.endsWith('/favorite/')) {
        isSaved = request.method == 'POST';
        return jsonResponse({'is_favorite': request.method == 'POST'});
      }
      if (request.url.path == '/api/login/') {
        return jsonResponse({
          'success': true,
          'token': 'test-token',
          'user': user,
        });
      }
      return jsonResponse(user);
    }),
  );
  final store = AppStore(
    api: ApiClient(client: client, baseUrl: 'http://localhost:8000'),
  )..restoring = false;
  if (authenticated) {
    store.user = Map.of(user);
    client.token = 'test-token';
  }
  return store;
}

Future<void> mobileSize(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });
  setUpAll(() async {
    final configFile = File('.dart_tool/package_config.json');
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final flutter = (config['packages'] as List).firstWhere(
      (p) => p['name'] == 'flutter',
    ) as Map<String, dynamic>;
    final sdk = Directory.fromUri(
      configFile.uri.resolve(flutter['rootUri'] as String),
    ).parent.parent;
    final fonts = Directory('${sdk.path}/bin/cache/artifacts/material_fonts');
    for (final entry in {
      'Roboto': ['roboto-regular.ttf', 'roboto-bold.ttf'],
      'MaterialIcons': ['materialicons-regular.otf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final name in entry.value) {
        final file = File('${fonts.path}/$name');
        loader.addFont(
          Future.value(ByteData.sublistView(await file.readAsBytes())),
        );
      }
      await loader.load();
    }
  });

  test(
    'registration session cookie reaches verify and resend on mobile',
    () async {
      final requests = <http.Request>[];
      final client = SessionClient(
        MockClient((r) async {
          requests.add(r);
          return http.Response(
            '{"success":true}',
            200,
            headers: r.url.path.endsWith('register/')
                ? {
                    'set-cookie':
                        'sessionid=registration-cookie; Path=/; HttpOnly',
                  }
                : {},
          );
        }),
      );
      final api = ApiClient(client: client, baseUrl: 'http://localhost:8000');
      await api.request('POST', 'register/', body: {'email': 'bat@test.mn'});
      await api.request('POST', 'verify/', body: {'otp': '123456'});
      await api.request('POST', 'resend-otp/');
      expect(requests[1].headers['Cookie'], 'sessionid=registration-cookie');
      expect(requests[2].headers['Cookie'], 'sessionid=registration-cookie');
      client.close();
    },
  );

  test(
    'API reports Mongolian validation errors and malformed responses',
    () async {
      final api = ApiClient(
        client: SessionClient(
          MockClient(
            (r) async => jsonResponse({
              'price': ['Үнэ оруулна уу.'],
            }, 400),
          ),
        ),
      );
      expect(
        () => api.request('POST', 'properties/'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Үнэ оруулна уу.',
          ),
        ),
      );
      expect(
        () => api.decode(http.Response('<html>Error</html>', 500)),
        throwsA(isA<ApiException>()),
      );
    },
  );

  testWidgets('home and search filters navigate on a mobile viewport', (
    tester,
  ) async {
    await mobileSize(tester);
    final requests = <http.Request>[];
    final store = testStore(requests);
    await tester.pumpWidget(BairApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Өргөө'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../docs/screenshots/home.png'),
    );
    await tester.tap(find.text('Хайх').last);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../docs/screenshots/listings.png'),
    );
    await tester.tap(find.text('Түрээс'));
    await tester.pumpAndSettle();
    expect(requests.last.url.queryParameters['listing_type'], 'rent');
    await tester.enterText(find.byType(TextField).last, 'Зайсан');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(requests.last.url.queryParameters['search'], 'Зайсан');
    await tester.tap(find.byTooltip('Шүүлтүүр'));
    await tester.pumpAndSettle();
    expect(find.text('Хайлтын шүүлтүүр'), findsOneWidget);
    await tester.ensureVisible(find.text('Үр дүнг харах'));
    await tester.tap(find.text('Үр дүнг харах'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('login validates then authenticates with Django', (tester) async {
    await mobileSize(tester);
    final requests = <http.Request>[];
    final store = testStore(requests);
    await tester.pumpWidget(
      AppScope(
        store: store,
        child: MaterialApp(
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  c,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Нэвтрэх'));
    await tester.pumpAndSettle();
    expect(
      find.text('Хэрэглэгчийн нэр эсвэл и-мэйл оруулна уу.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'bat@test.mn');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Нэвтрэх'));
    await tester.pumpAndSettle();
    expect(store.loggedIn, isTrue);
    expect(store.api.client.token, 'test-token');
    expect(jsonDecode(requests.last.body)['password'], 'password123');
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('save button persists favorite and detail opens', (tester) async {
    await mobileSize(tester);
    final requests = <http.Request>[];
    final store = testStore(requests, authenticated: true);
    await tester.pumpWidget(BairApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Хайх').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Байр хадгалах').last);
    await tester.pumpAndSettle();
    expect(store.favorites[1], isTrue);
    expect(
      requests.any(
        (r) =>
            r.url.path.endsWith('/favorite/') &&
            r.headers['Authorization'] == 'Token test-token',
      ),
      isTrue,
    );
    await tester.tap(find.text(sample['title'] as String).last);
    await tester.pumpAndSettle();
    expect(find.text('Байрны дэлгэрэнгүй'), findsOneWidget);
    expect(find.text('Засах'), findsOneWidget);
    expect(find.text('Устгах'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../docs/screenshots/detail.png'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('create form validates and sends a real property payload', (
    tester,
  ) async {
    await mobileSize(tester);
    final requests = <http.Request>[];
    final store = testStore(
      requests,
      authenticated: true,
      handler: (r) async {
        if (r.url.path == '/api/properties/' && r.method == 'POST') {
          return jsonResponse({
            ...sample,
            ...jsonDecode(r.body) as Map<String, dynamic>,
            'rooms': 2,
            'floor': 1,
            'total_floors': 1,
            'id': 2,
          }, 201);
        }
        return http.Response('', 418);
      },
    );
    await tester.pumpWidget(BairApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Хайх').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Зар нэмэх').last);
    await tester.pumpAndSettle();
    final values = {
      'Зарын гарчиг': 'Миний шинэ байр',
      'Хотхон, хаяг': 'Зайсан',
      'Худалдах үнэ • ₮': '350000000',
      'Талбай • м²': '70',
      'Холбогдох утас': '99112233',
    };
    for (final e in values.entries) {
      final finder = find.widgetWithText(TextFormField, e.key);
      await tester.ensureVisible(finder);
      await tester.enterText(finder, e.value);
    }
    await tester.ensureVisible(find.text('Зараа хадгалах'));
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Зараа хадгалах'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Зараа хадгалах'));
    await tester.pumpAndSettle();
    final created = requests
        .where((r) => r.url.path == '/api/properties/' && r.method == 'POST')
        .single;
    expect(jsonDecode(created.body)['title'], 'Миний шинэ байр');
    expect(jsonDecode(created.body)['listing_type'], 'sale');
    expect(find.text('Шинэ зар нэмэх'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
