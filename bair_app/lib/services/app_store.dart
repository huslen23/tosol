import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import '../models/property.dart';

class AppStore extends ChangeNotifier {
  final ApiClient api;
  final FlutterSecureStorage storage;
  Map<String, dynamic>? user;
  bool restoring = true;
  int revision = 0;
  final Map<int, bool> favorites = {};
  final Set<int> _saving = {};
  final Set<int> comparison = {};

  void toggleComparison(int id) {
    if (!comparison.remove(id)) {
      if (comparison.length >= 3) {
        throw const ApiException('Хамгийн ихдээ 3 байр харьцуулна.');
      }
      comparison.add(id);
    }
    notifyListeners();
  }

  AppStore({ApiClient? api, FlutterSecureStorage? storage})
    : api = api ?? ApiClient(),
      storage = storage ?? const FlutterSecureStorage();
  bool get loggedIn => user != null;
  bool get isAdmin => user?['is_staff'] == true;
  Future<void> restore() async {
    try {
      api.client.token = await storage.read(key: 'auth_token');
      if (api.client.token != null) {
        user = await api.request('GET', 'profile/') as Map<String, dynamic>;
      }
    } on ApiException catch (e) {
      if (e.status == 401) await storage.delete(key: 'auth_token');
      api.client.token = null;
    } catch (_) {
      api.client.token = null;
    }
    restoring = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final data = await api.request(
      'POST',
      'login/',
      body: {'identifier': email.trim(), 'password': password},
    ) as Map<String, dynamic>;
    api.client.token = data['token'] as String;
    user = data['user'] as Map<String, dynamic>;
    favorites.clear();
    try {
      await storage.write(key: 'auth_token', value: api.client.token);
    } catch (_) {
      /* Session remains usable if the OS keychain is unavailable. */
    }
    changed();
  }

  Future<void> logout() async {
    try {
      await api.request('POST', 'logout/');
    } on ApiException catch (e) {
      if (e.status != 401) rethrow;
    }
    api.client.token = null;
    api.client.sessionCookie = null;
    user = null;
    favorites.clear();
    try {
      await storage.delete(key: 'auth_token');
    } finally {
      changed();
    }
  }

  Future<void> changePassword(
    String oldPassword,
    String password,
    String confirmation,
  ) async {
    final data = await api.request(
      'POST',
      'password/change/',
      body: {
        'old_password': oldPassword,
        'new_password': password,
        'password_confirm': confirmation,
      },
    ) as Map<String, dynamic>;
    api.client.token = data['token'] as String;
    try {
      await storage.write(key: 'auth_token', value: api.client.token);
    } catch (_) {
      // Keep the current session usable if the keychain is unavailable.
    }
    changed();
  }

  Future<void> clearAuthentication() async {
    api.client.token = null;
    api.client.sessionCookie = null;
    user = null;
    favorites.clear();
    try {
      await storage.delete(key: 'auth_token');
    } finally {
      changed();
    }
  }

  void changed() {
    revision++;
    notifyListeners();
  }

  void rememberFavorites(Iterable<Property> properties) {
    for (final property in properties) {
      favorites[property.id] = property.isFavorite;
    }
  }

  Future<void> toggleFavorite(int id, bool current) async {
    if (_saving.contains(id)) return;
    _saving.add(id);
    try {
      final value = favorites[id] ?? current;
      await api.request(value ? 'DELETE' : 'POST', 'properties/$id/favorite/');
      favorites[id] = !value;
      changed();
    } finally {
      _saving.remove(id);
    }
  }
}

class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({super.key, required AppStore store, required super.child})
    : super(notifier: store);
  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
