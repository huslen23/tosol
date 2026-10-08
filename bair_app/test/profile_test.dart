import 'dart:convert';

import 'package:bair_app/screens/profile_page.dart';
import 'package:bair_app/services/api_client.dart';
import 'package:bair_app/services/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'widget_test.dart' as fixtures;

void main() {
  testWidgets(
    'profile saves surname, first name and username and retains form on duplicate',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await fixtures.mobileSize(tester);
      final requests = <http.Request>[];
      final api = ApiClient(
        baseUrl: 'http://localhost:8000',
        client: SessionClient(
          MockClient((request) async {
            requests.add(request);
            return http.Response(
              jsonEncode(
                requests.length == 1
                    ? {
                        'username': ['Энэ хэрэглэгчийн нэр бүртгэлтэй байна.'],
                      }
                    : {
                        ...fixtures.user,
                        ...jsonDecode(request.body) as Map<String, dynamic>,
                      },
              ),
              requests.length == 1 ? 400 : 200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
      final store = AppStore(api: api)
        ..restoring = false
        ..user = {...fixtures.user, 'username': 'original'};
      await tester.pumpWidget(
        AppScope(
          store: store,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileEditPage()),
                  ),
                  child: const Text('Нээх'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Нээх'));
      await tester.pumpAndSettle();
      expect(find.text('original'), findsOneWidget);
      for (final entry in {
        'Овог': 'Дорж',
        'Нэр': 'Бат',
        'Хэрэглэгчийн нэр': 'taken',
      }.entries) {
        await tester.enterText(
          find.widgetWithText(TextFormField, entry.key),
          entry.value,
        );
      }
      tester.testTextInput.hide();
      await tester.ensureVisible(find.text('Хадгалах'));
      await tester.tap(find.text('Хадгалах'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileEditPage), findsOneWidget);
      expect(store.user!['username'], 'original');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Хэрэглэгчийн нэр'),
        'newname',
      );
      tester.testTextInput.hide();
      await tester.ensureVisible(find.text('Хадгалах'));
      await tester.tap(find.text('Хадгалах'));
      await tester.pumpAndSettle();
      expect(requests.last.method, 'PATCH');
      expect(requests.last.url.path, '/api/profile/');
      expect(jsonDecode(requests.last.body), {
        'first_name': 'Бат',
        'last_name': 'Дорж',
        'username': 'newname',
      });
      expect(store.user!['username'], 'newname');
      expect(find.byType(ProfileEditPage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      api.client.close();
    },
  );
}
