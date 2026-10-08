import 'dart:convert';

import 'package:bair_app/screens/comfort_page.dart';
import 'package:bair_app/services/api_client.dart';
import 'package:bair_app/services/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'widget_test.dart' as fixtures;

const labels = {
  'location': 'Байршил, хүртээмж',
  'transport': 'Нийтийн тээвэр',
  'environment': 'Хүрээлэн буй орчин',
  'safety': 'Аюулгүй байдлын нөхцөл',
  'infrastructure': 'Дэд бүтэц',
  'building': 'Барилгын тав тух',
  'services': 'Нийтийн үйлчилгээ',
  'cost': 'Үнэ, ашиглалтын зардал',
};
const weights = {
  'location': 20,
  'transport': 15,
  'environment': 15,
  'safety': 10,
  'infrastructure': 10,
  'building': 10,
  'services': 10,
  'cost': 10,
};

class ComfortFixture {
  final requests = <http.Request>[];
  final scores = <String, dynamic>{};
  String explanation = '';
  final comments = <Map<String, dynamic>>[
    {
      'id': 1,
      'username': 'neighbor',
      'text': 'Тээвэр ойрхон',
      'created_at': '2026-10-08T10:00:00Z',
      'can_edit': false,
      'can_delete': false,
    },
  ];
  Map<String, dynamic> savedWeights = Map.of(weights);
  late final api = ApiClient(
    baseUrl: 'http://localhost:8000',
    client: SessionClient(
      MockClient((request) async {
        requests.add(request);
        Object body = {};
        if (request.url.path.endsWith('/comfort/') ||
            request.url.path.endsWith('/my-rating/')) {
          if (request.method == 'PUT') {
            scores
              ..clear()
              ..addAll(
                jsonDecode(request.body)['scores'] as Map<String, dynamic>,
              );
            explanation =
                jsonDecode(request.body)['explanation'] as String? ??
                explanation;
            comments.removeWhere((c) => c['id'] == 3);
            if (explanation.isNotEmpty) {
              comments.insert(0, {
                'id': 3,
                'username': 'me',
                'text': explanation,
                'created_at': '2026-10-08T10:00:00Z',
                'can_edit': true,
                'can_delete': true,
              });
            }
          }
          if (request.method == 'DELETE') scores.clear();
          body = summary;
        } else if (request.url.path == '/api/complexes/weights/') {
          savedWeights =
              jsonDecode(request.body)['weights'] as Map<String, dynamic>;
          body = {'weights': savedWeights};
        } else if (request.url.path.endsWith('/comments/')) {
          if (request.method == 'POST') {
            comments.insert(0, {
              'id': 2,
              'username': 'me',
              'text': jsonDecode(request.body)['text'],
              'created_at': '2026-10-08T11:00:00Z',
              'can_edit': true,
              'can_delete': true,
            });
            body = comments.first;
          } else {
            body = {
              'count': comments.length,
              'next': null,
              'results': comments,
            };
          }
        }
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    ),
  );

  Map<String, dynamic> get summary => {
    'score': scores.isEmpty ? 50 : scores.values.first,
    'coverage': scores.isEmpty ? 0 : 20,
    'rankable': false,
    'is_default': scores.isEmpty,
    'rating_count': scores.isEmpty ? 0 : 1,
    'comment_count': comments.length,
    'weights': savedWeights,
    'default_weights': weights,
    'my_scores': Map.of(scores),
    'my_explanation': explanation,
    'quality_note': 'Хэрэглэгчдийн үнэлгээ; баталгаажаагүй.',
    'criteria': labels.entries
        .map(
          (entry) => {
            'key': entry.key,
            'label': entry.value,
            'hint': 'Шалгуурын тайлбар',
            'score': scores[entry.key] ?? 50,
            'weight': savedWeights[entry.key],
            'count': scores.containsKey(entry.key) ? 1 : 0,
            'source': scores.containsKey(entry.key)
                ? 'Хэрэглэгчдийн үнэлгээ'
                : 'Системийн түр анхдагч утга',
            'origin': scores.containsKey(entry.key) ? 'community' : 'default',
            'collected_at': scores.containsKey(entry.key)
                ? '2026-10-08T10:00:00Z'
                : null,
          },
        )
        .toList(),
  };
}

Future<AppStore> open(
  WidgetTester tester,
  ComfortFixture fixture, {
  bool authenticated = false,
}) async {
  await fixtures.mobileSize(tester);
  final store = AppStore(api: fixture.api)..restoring = false;
  if (authenticated) store.user = Map.of(fixtures.user);
  await tester.pumpWidget(
    AppScope(
      store: store,
      child: const MaterialApp(
        home: ComfortPage(complexId: 1, name: 'Тест хотхон'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    finder,
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'guest sees default, insufficient coverage and public comments without edit controls',
    (tester) async {
      final fixture = ComfortFixture();
      final store = await open(tester, fixture);
      expect(find.text('50.0 / 100'), findsWidgets);
      expect(find.text('Мэдээллийн хамрагдалт: 0.0%'), findsOneWidget);
      expect(find.text('0 хүн үнэлсэн'), findsOneWidget);
      expect(find.text('0/8 шалгуур үнэлэгдсэн'), findsOneWidget);
      expect(find.textContaining('Үнэлгээ хараахан алга.'), findsOneWidget);
      expect(find.textContaining('Мэдээлэл хангалтгүй'), findsOneWidget);
      await scrollTo(tester, find.text('Тээвэр ойрхон'));
      expect(find.text('neighbor'), findsOneWidget);
      expect(find.text('Засах'), findsNothing);
      expect(find.text('Устгах'), findsNothing);
      expect(fixture.requests.every((r) => r.method == 'GET'), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      fixture.api.client.close();
    },
  );

  for (final explanationText in ['', 'Автобус ойрхон.']) {
    testWidgets('rating saves with optional explanation: $explanationText', (
      tester,
    ) async {
      final fixture = ComfortFixture();
      final store = await open(tester, fixture, authenticated: true);
      await scrollTo(tester, find.text('Үнэлгээ өгөх'));
      await tester.tap(find.text('Үнэлгээ өгөх'));
      await tester.pumpAndSettle();
      final choice = find.widgetWithText(CheckboxListTile, 'Байршил, хүртээмж');
      await tester.tap(choice);
      await tester.pumpAndSettle();
      tester.widget<Slider>(find.byType(Slider).first).onChanged!(80);
      await tester.pump();
      final explanationField = find.widgetWithText(
        TextField,
        'Үнэлгээний тайлбар (заавал биш)',
      );
      await scrollTo(tester, explanationField);
      if (explanationText.isNotEmpty) {
        await tester.enterText(explanationField, explanationText);
        tester.testTextInput.hide();
      }
      await scrollTo(tester, find.text('Хадгалах'));
      await tester.tap(find.text('Хадгалах'));
      await tester.pumpAndSettle();
      final writes = fixture.requests.where((r) => r.method == 'PUT').toList();
      expect(writes.length, 1);
      expect(writes.single.url.path, '/api/complexes/1/my-rating/');
      expect(jsonDecode(writes.single.body), {
        'scores': {'location': 80.0},
        'explanation': explanationText,
      });
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('80.0 / 100'), findsWidgets);
      expect(find.text('Мэдээллийн хамрагдалт: 20.0%'), findsOneWidget);
      expect(find.text('1 хүн үнэлсэн'), findsOneWidget);
      expect(find.text('1/8 шалгуур үнэлэгдсэн'), findsOneWidget);
      expect(find.textContaining('Цөөн хүний үнэлгээтэй.'), findsOneWidget);
      expect(find.byType(ComfortEditPage), findsNothing);
      if (explanationText.isNotEmpty) {
        await scrollTo(tester, find.text(explanationText));
        expect(find.text(explanationText), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      fixture.api.client.close();
    });
  }

  testWidgets('weights must total 100 before saving personal settings', (
    tester,
  ) async {
    final fixture = ComfortFixture();
    final store = await open(tester, fixture, authenticated: true);
    await scrollTo(tester, find.text('Миний шалгуурын жин'));
    await tester.tap(find.text('Миний шалгуурын жин'));
    await tester.pumpAndSettle();
    final field = find.widgetWithText(TextField, 'Байршил, хүртээмж • %');
    await tester.enterText(field, '21');
    tester.testTextInput.hide();
    await scrollTo(tester, find.text('Хадгалах'));
    await tester.tap(find.text('Хадгалах'));
    await tester.pumpAndSettle();
    expect(fixture.requests.where((r) => r.method == 'PUT'), isEmpty);
    expect(find.text('Нийт жин 100% байна.'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(ComfortEditPage)))
        .removeCurrentSnackBar();
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await scrollTo(tester, field);
    await tester.enterText(field, '20');
    tester.testTextInput.hide();
    await scrollTo(tester, find.text('Хадгалах'));
    await tester.tap(find.text('Хадгалах'));
    await tester.pumpAndSettle();
    final write = fixture.requests.singleWhere((r) => r.method == 'PUT');
    expect(write.url.path, '/api/complexes/weights/');
    expect(jsonDecode(write.body)['weights'], weights);
    expect(find.byType(ComfortEditPage), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    fixture.api.client.close();
  });

  testWidgets('posted comment is public and only own comment has actions', (
    tester,
  ) async {
    final fixture = ComfortFixture();
    final store = await open(tester, fixture, authenticated: true);
    final field = find.widgetWithText(TextField, 'Сэтгэгдэл бичих');
    await scrollTo(tester, field);
    await tester.enterText(field, '  Миний туршлага  ');
    tester.testTextInput.hide();
    await scrollTo(tester, find.text('Сэтгэгдэл нийтлэх'));
    await tester.tap(find.text('Сэтгэгдэл нийтлэх'));
    await tester.pumpAndSettle();
    final write = fixture.requests.singleWhere((r) => r.method == 'POST');
    expect(write.url.path, '/api/complexes/1/comments/');
    expect(jsonDecode(write.body)['text'], 'Миний туршлага');
    await scrollTo(tester, find.text('Миний туршлага'));
    expect(find.text('Засах'), findsOneWidget);
    expect(find.text('Устгах'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    fixture.api.client.close();
  });
}
