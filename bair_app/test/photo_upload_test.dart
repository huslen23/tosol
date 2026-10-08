import 'dart:convert';
import 'dart:typed_data';

import 'package:bair_app/models/property.dart';
import 'package:bair_app/screens/property_form_page.dart';
import 'package:bair_app/services/api_client.dart';
import 'package:bair_app/services/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'widget_test.dart' as fixtures;

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

// Native XFile derives its name from a disk path; mimic the browser's name.
class BlobPhoto extends XFile {
  BlobPhoto()
    : super.fromData(
        png,
        path: 'blob:http://localhost/photo',
        mimeType: 'image/png',
      );
  @override
  String get name => 'room.png';
}

class TestPicker extends ImagePicker {
  final List<XFile> photos;
  TestPicker(this.photos);

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async => photos;
}

class UploadClient extends http.BaseClient {
  final uploads = <Uint8List>[];
  final filenames = <String>[];
  int creates = 0, edits = 0;
  bool failUpload = true;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    Object body = {'count': 0, 'next': null, 'results': []};
    var status = 200;
    if (request is http.MultipartRequest) {
      expect(request.headers['Authorization'], 'Token test-token');
      expect(request.url.path, '/api/properties/1/photos/');
      final file = request.files.single;
      expect(file.field, 'images');
      filenames.add(file.filename!);
      uploads.add(await file.finalize().toBytes());
      status = failUpload ? 503 : 201;
      body = failUpload ? {'detail': 'Дахин оролдоно уу.'} : [];
      failUpload = false;
    } else if (request.method == 'POST' || request.method == 'PATCH') {
      request.method == 'POST' ? creates++ : edits++;
      body = fixtures.sample;
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'blob photo previews, uploads and retries without duplicate listing',
    (tester) async {
      await fixtures.mobileSize(tester);
      final transport = UploadClient();
      final client = SessionClient(transport)..token = 'test-token';
      final store =
          AppStore(
              api: ApiClient(client: client, baseUrl: 'http://localhost:8000'),
            )
            ..restoring = false
            ..user = Map.of(fixtures.user);
      final picker = TestPicker([BlobPhoto()]);
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
                      builder: (_) => PropertyFormPage(imagePicker: picker),
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
      for (final entry in {
        'Зарын гарчиг': 'Зурагтай шинэ байр',
        'Хотхон, хаяг': 'Зайсан',
        'Худалдах үнэ • ₮': '350000000',
        'Талбай • м²': '70',
        'Холбогдох утас': '99112233',
      }.entries) {
        final field = find.widgetWithText(TextFormField, entry.key);
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Зураг нэмэх'));
      await tester.tap(find.text('Зураг нэмэх'));
      await tester.pumpAndSettle();
      expect(find.text('Байрны зураг • 1/12'), findsOneWidget);
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        isA<MemoryImage>(),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Зараа хадгалах'));
      await tester.tap(find.text('Зараа хадгалах'));
      await tester.pumpAndSettle();
      expect(transport.creates, 1);
      expect(find.byType(PropertyFormPage), findsOneWidget);
      expect(transport.uploads.single, png);
      expect(transport.filenames.single, 'room.png');
      ScaffoldMessenger.of(tester.element(find.byType(PropertyFormPage)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Зараа хадгалах'));
      await tester.pumpAndSettle();
      expect(transport.creates, 1);
      expect(transport.edits, 1);
      expect(transport.uploads.length, 2);
      expect(find.byType(PropertyFormPage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      client.close();
    },
  );

  testWidgets('selected blob photo can be removed before saving', (
    tester,
  ) async {
    await fixtures.mobileSize(tester);
    final store = fixtures.testStore([], authenticated: true);
    await tester.pumpWidget(
      AppScope(
        store: store,
        child: MaterialApp(
          home: PropertyFormPage(
            property: Property.fromJson(fixtures.sample),
            imagePicker: TestPicker([
              XFile.fromData(png, path: 'blob:photo', name: 'room.png'),
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Зураг нэмэх'));
    await tester.tap(find.text('Зураг нэмэх'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Зураг хасах'));
    await tester.tap(find.byTooltip('Зураг хасах'));
    await tester.pumpAndSettle();
    expect(find.text('Байрны зураг • 0/12'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
