import 'dart:convert';

import 'package:bair_app/screens/password_page.dart';
import 'package:bair_app/services/api_client.dart';
import 'package:bair_app/services/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'widget_test.dart' as fixtures;

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final forgot in [false, true]) {
    testWidgets(
      forgot
          ? 'reset switches email immediately and clears authentication'
          : 'password change stores rotated token',
      (tester) async {
        await fixtures.mobileSize(tester);
        final requests = <http.Request>[];
        final api = ApiClient(
          baseUrl: 'http://localhost:8000',
          client: SessionClient(
            MockClient((request) async {
              requests.add(request);
              return http.Response(
                jsonEncode({
                  'reset_token': 'reset-${requests.length}',
                  'token': 'rotated-token',
                  'message': 'Амжилттай',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          )..token = 'old-token',
        );
        final store = AppStore(api: api)
          ..restoring = false
          ..user = Map.of(fixtures.user);
        await tester.pumpWidget(
          AppScope(
            store: store,
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PasswordPage(forgot: forgot),
                      ),
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
        Future<void> enter(String label, String value) async {
          final field = find.widgetWithText(TextFormField, label);
          await tester.ensureVisible(field);
          await tester.enterText(field, value);
        }

        if (forgot) {
          await enter('И-мэйл', 'first@example.com');
          await tester.tap(find.text('Код авах'));
          await tester.pumpAndSettle();
          expect(find.text('Дахин код авах • 60 сек'), findsOneWidget);
          await tester.tap(find.text('Өөр и-мэйл ашиглах'));
          await tester.pumpAndSettle();
          await enter('И-мэйл', 'second@example.com');
          await tester.tap(find.text('Код авах'));
          await tester.pumpAndSettle();
          expect(requests.length, 2);
          expect(jsonDecode(requests.last.body)['email'], 'second@example.com');
          await enter('6 оронтой код', '123456');
        } else {
          await enter('Хуучин нууц үг', 'oldpass123');
        }
        await enter('Шинэ нууц үг', 'newpass123');
        await enter('Шинэ нууц үг давтах', 'newpass123');
        tester.testTextInput.hide();
        await tester.ensureVisible(find.text('Нууц үг хадгалах'));
        await tester.tap(find.text('Нууц үг хадгалах'));
        await tester.pumpAndSettle();
        expect(
          requests.last.url.path,
          forgot ? '/api/password/reset/' : '/api/password/change/',
        );
        final body = jsonDecode(requests.last.body);
        expect(body['new_password'], 'newpass123');
        expect(body['password_confirm'], 'newpass123');
        if (forgot) {
          expect(body['reset_token'], 'reset-2');
          expect(body['code'], '123456');
          expect(store.loggedIn, isFalse);
          expect(api.client.token, isNull);
        } else {
          expect(body['old_password'], 'oldpass123');
          expect(store.loggedIn, isTrue);
          expect(api.client.token, 'rotated-token');
        }
        expect(
          await store.storage.read(key: 'auth_token'),
          forgot ? null : 'rotated-token',
        );
        expect(find.byType(PasswordPage), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        store.dispose();
        api.client.close();
      },
    );
  }
}
