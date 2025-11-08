import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Сервис для управления пользовательскими настройками и хранения состояния авторизации
class UserPreferencesService {
  static const String _keyIsLoggedIn = 'isLoggedIn';
  static const String _keyUserId = 'userId';
  static const String _keyAuthMethod = 'authMethod';
  static const String _keyUserName = 'userName';
  static const String _keyUserCity = 'userCity';
  static const String _keyIsProfileComplete = 'isProfileComplete';
  static const String _keyAuthToken = 'auth_token';

  /// Сохраняет информацию о успешной авторизации пользователя
  static Future<bool> saveAuthState({
    required String userId,
    required String authMethod,
    String? userName,
    String? userCity,
    bool isProfileComplete = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUserId, userId);
      await prefs.setString(_keyAuthMethod, authMethod);

      if (userName != null) {
        await prefs.setString(_keyUserName, userName);
      }

      if (userCity != null) {
        await prefs.setString(_keyUserCity, userCity);
      }

      await prefs.setBool(_keyIsProfileComplete, isProfileComplete);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Ошибка при сохранении данных авторизации: $e');
      }
      return false;
    }
  }

  /// Получает информацию о состоянии авторизации пользователя
  static Future<Map<String, dynamic>> getAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      final authToken = prefs.getString(_keyAuthToken);

      if (!isLoggedIn || authToken == null || authToken.isEmpty) {
        if (isLoggedIn && (authToken == null || authToken.isEmpty)) {
          if (kDebugMode) {
            print('⚠️ Обнаружено некорректное состояние: isLoggedIn=true, но токен отсутствует. Очищаем...');
          }
          await clearAuthState();
        }
        return {'isLoggedIn': false};
      }

      return {
        'isLoggedIn': true,
        'userId': prefs.getString(_keyUserId) ?? '',
        'authMethod': prefs.getString(_keyAuthMethod) ?? '',
        'userName': prefs.getString(_keyUserName) ?? '',
        'userCity': prefs.getString(_keyUserCity) ?? '',
        'isProfileComplete': prefs.getBool(_keyIsProfileComplete) ?? false,
        'authToken': authToken,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Ошибка при получении данных авторизации: $e');
      }
      return {'isLoggedIn': false};
    }
  }

  /// Очищает информацию об авторизации пользователя при выходе
  static Future<bool> clearAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_keyIsLoggedIn, false);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyAuthMethod);
      await prefs.remove(_keyUserName);
      await prefs.remove(_keyUserCity);
      await prefs.remove(_keyIsProfileComplete);
      await prefs.remove(_keyAuthToken);
      // УЛУЧШЕНИЕ: Удаляем также временную метку токена
      await prefs.remove('auth_token_timestamp');

      if (kDebugMode) {
        print('✅ Данные авторизации и токен полностью очищены');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Ошибка при очистке данных авторизации: $e');
      }
      return false;
    }
  }

  /// Проверяет наличие валидного токена авторизации
  static Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      final authToken = prefs.getString(_keyAuthToken);

      if (!isLoggedIn) {
        if (kDebugMode) {
          print('⚠️ Пользователь не авторизован');
        }
        return null;
      }

      if (authToken == null || authToken.isEmpty) {
        if (kDebugMode) {
          print('⚠️ Токен авторизации отсутствует, очищаем некорректное состояние');
        }
        await clearAuthState();
        return null;
      }

      return authToken;
    } catch (e) {
      if (kDebugMode) {
        print('Ошибка при получении токена авторизации: $e');
      }
      return null;
    }
  }
}
