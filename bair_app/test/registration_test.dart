import 'dart:convert';

import 'package:bair_app/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'registration handle survives missing cookies and incorrect OTP',
    () async {
      final requests = <http.Request>[];
      var attempt = 0;
      final api = ApiClient(
        client: SessionClient(
          MockClient((r) async {
            requests.add(r);
            var status = 200;
            Object body = {};
            switch (r.url.path) {
              case '/api/register/':
                body = {'registration_token': 'pending-registration'};
              case '/api/verify/':
                if (attempt++ == 0) {
                  status = 400;
                  body = {'message': 'Баталгаажуулах код буруу байна.'};
                } else {
                  status = 201;
                }
              case '/api/resend-otp/':
                body = {'registration_token': 'refreshed-registration'};
            }
            // Browsers do not expose Set-Cookie to application code.
            return http.Response(
              jsonEncode(body),
              status,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
        baseUrl: 'http://localhost:8000',
      );
      await api.request('POST', 'register/', body: {'email': 'test@test.mn'});
      await expectLater(
        api.request(
          'POST',
          'verify/',
          body: {'email': 'test@test.mn', 'otp': '000000'},
        ),
        throwsA(isA<ApiException>()),
      );
      await api.request('POST', 'resend-otp/', body: {'email': 'test@test.mn'});
      await api.request(
        'POST',
        'verify/',
        body: {'email': 'test@test.mn', 'otp': '123456'},
      );
      expect(
        jsonDecode(requests[1].body)['registration_token'],
        'pending-registration',
      );
      expect(
        jsonDecode(requests[2].body)['registration_token'],
        'pending-registration',
      );
      expect(
        jsonDecode(requests[3].body)['registration_token'],
        'refreshed-registration',
      );
      await api.request('POST', 'resend-otp/', body: {'email': 'test@test.mn'});
      expect(
        jsonDecode(requests.last.body).containsKey('registration_token'),
        isFalse,
      );
      api.client.close();
    },
  );
}
