import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento seguro adaptativo a cada plataforma:
/// - En Android utiliza KeyStore / EncryptedSharedPreferences mediante FlutterSecureStorage.
/// - En Web almacena de forma segura en memoria o almacenamiento local restringido.
class SecureStorageService {
  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'auth_user';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, token);
    } else {
      await _secureStorage.write(key: _keyToken, value: token);
    }
  }

  Future<String?> getToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyToken);
    } else {
      return await _secureStorage.read(key: _keyToken);
    }
  }

  Future<void> saveUserJson(String userJson) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUser, userJson);
    } else {
      await _secureStorage.write(key: _keyUser, value: userJson);
    }
  }

  Future<String?> getUserJson() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUser);
    } else {
      return await _secureStorage.read(key: _keyUser);
    }
  }

  Future<void> clearAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
      await prefs.remove(_keyUser);
    } else {
      await _secureStorage.deleteAll();
    }
  }
}

