import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/property.dart';
import 'http_client.dart' if (dart.library.js_interop) 'http_client_web.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  const ApiException(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

extension on String {
  String get ifEmptyDefault => isNotEmpty
      ? replaceFirst(RegExp(r'/+$'), '')
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8000'
      : 'http://127.0.0.1:8000';
}

// One client retains Django's registration session across register/verify/resend.
class SessionClient extends http.BaseClient {
  final http.Client _inner;
  String? sessionCookie;
  String? token;
  SessionClient([http.Client? inner]) : _inner = inner ?? createHttpClient();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (sessionCookie != null) request.headers['Cookie'] = sessionCookie!;
    if (token != null) request.headers['Authorization'] = 'Token $token';
    final response = await _inner.send(request);
    final cookies = response.headers['set-cookie'];
    if (cookies != null) {
      final match = RegExp(r'sessionid=([^;,]*)').firstMatch(cookies);
      if (match != null) sessionCookie = 'sessionid=${match[1]}';
    }
    return response;
  }

  @override
  void close() => _inner.close();
}

class ApiClient {
  final SessionClient client;
  final String baseUrl;
  String? _registrationToken;
  ApiClient({SessionClient? client, String? baseUrl})
    : client = client ?? SessionClient(),
      baseUrl =
          baseUrl ??
          const String.fromEnvironment('API_BASE_URL').trim().ifEmptyDefault;
  Uri uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/api/$path').replace(queryParameters: query);
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final request = http.Request(method, uri(path, query));
    request.headers['Content-Type'] = 'application/json';
    if (path == 'register/') _registrationToken = null;
    final registrationRequest = path == 'verify/' || path == 'resend-otp/';
    if (body != null || (registrationRequest && _registrationToken != null)) {
      request.body = jsonEncode({
        ...?body,
        if (registrationRequest && _registrationToken != null)
          'registration_token': _registrationToken,
      });
    }
    try {
      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 25));
      final data = decode(
        await http.Response.fromStream(streamed)
            .timeout(const Duration(seconds: 25)),
      );
      if ((path == 'register/' || path == 'resend-otp/') && data is Map) {
        _registrationToken = data['registration_token'] as String?;
      }
      if (path == 'verify/' || path == 'logout/') _registrationToken = null;
      return data;
    } on TimeoutException {
      throw const ApiException('Холболтын хугацаа дууслаа. Дахин оролдоно уу.');
    } on SocketException {
      throw const ApiException(
        'Сервертэй холбогдож чадсангүй. Интернэтээ шалгана уу.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Сервертэй холбогдож чадсангүй. Дахин оролдоно уу.',
      );
    }
  }

  dynamic decode(http.Response response) {
    if (response.statusCode == 204) return null;
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw ApiException('Серверээс буруу хариу ирлээ.', response.statusCode);
    }
    if (response.statusCode >= 400) {
      String message = 'Хүсэлтийг гүйцэтгэж чадсангүй.';
      if (data is Map) {
        final value =
            data['message'] ??
            data['detail'] ??
            (data.isNotEmpty ? data.values.first : null);
        if (value is List) {
          message = value.join('\n');
        } else if (value != null) {
          message = '$value';
        }
      }
      throw ApiException(message, response.statusCode);
    }
    return data;
  }

  Future<PropertyResults> properties(
    Map<String, String> query, {
    bool recommendations = false,
  }) async {
    final d = await request(
      'GET',
      recommendations ? 'properties/recommendations/' : 'properties/',
      query: query,
    ) as Map<String, dynamic>;
    return PropertyResults(
      (d['results'] as List)
          .map((e) => Property.fromJson(e as Map<String, dynamic>))
          .toList(),
      d['count'] as int,
      d['next'] != null,
    );
  }

  Future<Property> property(int id) async => Property.fromJson(
    await request('GET', 'properties/$id/') as Map<String, dynamic>,
  );
  Future<Property> saveProperty(Map<String, dynamic> body, {int? id}) async =>
      Property.fromJson(
        await request(
          id == null ? 'POST' : 'PATCH',
          id == null ? 'properties/' : 'properties/$id/',
          body: body,
        ) as Map<String, dynamic>,
      );
  Future<void> uploadPhotos(int id, List<XFile> photos) async {
    final request = http.MultipartRequest(
      'POST',
      uri('properties/$id/photos/'),
    );
    for (final photo in photos) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'images',
          await photo.readAsBytes(),
          filename: photo.name,
        ),
      );
    }
    try {
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 90));
      decode(
        await http.Response.fromStream(response)
            .timeout(const Duration(seconds: 90)),
      );
    } on TimeoutException {
      throw const ApiException(
        'Зураг илгээх хугацаа дууслаа. Дахин оролдоно уу.',
      );
    } on SocketException {
      throw const ApiException(
        'Зураг илгээж чадсангүй. Интернэтээ шалгана уу.',
      );
    } on http.ClientException {
      throw const ApiException('Зураг илгээж чадсангүй. Дахин оролдоно уу.');
    }
  }
}
