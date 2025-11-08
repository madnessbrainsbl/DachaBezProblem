import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
// Временно закомментируем некоторые импорты для упрощения сборки
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
import 'logger.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class SocialAuthService {
  FirebaseAuth? _auth;
  GoogleSignIn? _googleSignIn;

  // Синглтон
  static final SocialAuthService _instance = SocialAuthService._internal();
  factory SocialAuthService() => _instance;
  SocialAuthService._internal() {
    // Инициализируем провайдеры, но не падаем, если Firebase не готов (например, на Web)
    try {
      if (Firebase.apps.isNotEmpty) {
        _auth = FirebaseAuth.instance;
      }
    } catch (e) {
      AppLogger.error('SocialAuthService init Firebase error', e);
      _auth = null;
    }
    try {
      _googleSignIn = GoogleSignIn();
    } catch (e) {
      AppLogger.error('SocialAuthService init GoogleSignIn error', e);
      _googleSignIn = null;
    }
  }

  // Проверка, доступен ли вход через Google на текущей платформе
  bool get isGoogleSignInAvailable =>
      (!kIsWeb) && (Platform.isAndroid || Platform.isMacOS);

  // Проверка, доступен ли вход через Apple на текущей платформе
  bool get isAppleSignInAvailable =>
      (!kIsWeb) && (Platform.isIOS || Platform.isMacOS);

  // Проверка, доступен ли вход через Яндекс на текущей платформе
  bool get isYandexSignInAvailable => (!kIsWeb) && Platform.isAndroid;

  // Вход через Google
  Future<Map<String, String?>> signInWithGoogle() async {
    if (!isGoogleSignInAvailable) {
      AppLogger.auth('Google Sign-In не доступен на этой платформе');
      return {'error': 'Google Sign-In не доступен на этой платформе'};
    }

    try {
      AppLogger.auth('Начало процесса входа через Google');

      // Запускаем процесс входа через Google
      final GoogleSignInAccount? googleUser = await _googleSignIn?.signIn();

      if (googleUser == null) {
        AppLogger.auth('Пользователь отменил вход через Google');
        return {'error': 'Пользователь отменил вход'};
      }

      // Получаем email и имя пользователя
      final String? email = googleUser.email;
      final String? name = googleUser.displayName;

      // Получаем данные аутентификации от Google (для Firebase)
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Создаем учетные данные Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Входим в Firebase
      if (_auth != null) {
        await _auth!.signInWithCredential(credential);
      }

      AppLogger.auth('Успешный вход через Google');
      return {
        'email': email,
        'provider': 'google',
        'name': name,
      };
    } catch (e) {
      AppLogger.error('Ошибка при входе через Google', e);
      return {'error': e.toString()};
    }
  }

  // Вход через Apple
  Future<Map<String, String?>> signInWithApple() async {
    if (!isAppleSignInAvailable) {
      AppLogger.auth('Apple Sign-In не доступен на этой платформе');
      return {'error': 'Apple Sign-In не доступен на этой платформе'};
    }

    try {
      AppLogger.auth('Начало процесса входа через Apple');

      // Запрашиваем учетные данные Apple
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Получаем email из данных авторизации
      final String? email = credential.email;
      String? name;

      // Формируем имя пользователя из данных
      if (credential.givenName != null || credential.familyName != null) {
        name = [credential.givenName, credential.familyName]
            .where((name) => name != null && name.isNotEmpty)
            .join(' ');
      }

      // Создаем учетные данные Firebase
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      // Входим в Firebase
      if (_auth != null) {
        await _auth!.signInWithCredential(oauthCredential);
      }

      AppLogger.auth('Успешный вход через Apple');
      return {
        'email': email,
        'provider': 'apple',
        'name': name,
      };
    } catch (e) {
      AppLogger.error('Ошибка при входе через Apple', e);
      
      // Специальная обработка для симулятора iOS
      if (e.toString().contains('AuthenticationServices.AuthorizationError') || 
          e.toString().contains('SignInWithAppleAuthorizationException')) {
        // Ошибка в симуляторе или на устройстве без настроенного Apple ID
        return {
          'error': 'Не удалось выполнить вход через Apple. ' + 
                  'Эта функция может не работать в симуляторе или требует настроенный Apple ID.'
        };
      }
      
      return {'error': e.toString()};
    }
  }

  // Вход через Яндекс (максимально упрощенная версия)
  Future<Map<String, String?>> signInWithYandex() async {
    if (!isYandexSignInAvailable) {
      AppLogger.auth('Яндекс Sign-In не доступен на этой платформе');
      return {'error': 'Яндекс Sign-In не доступен на этой платформе'};
    }

    try {
      AppLogger.auth('Начало процесса входа через Яндекс');

      // ID приложения, зарегистрированного в Яндекс.OAuth
      const clientId = 'afc3d5e12c9a42e6bcd55be723551f16';

      // Создаем URL для авторизации Яндекс
      final authUrl = Uri.parse('https://oauth.yandex.ru/authorize'
          '?response_type=token'
          '&client_id=$clientId');

      // Просто открываем URL в браузере
      if (await url_launcher.canLaunchUrl(authUrl)) {
        await url_launcher.launchUrl(
          authUrl,
          mode: url_launcher.LaunchMode.externalApplication,
        );

        // Для этой версии, мы просто вернем флаг, что пользователю нужно ввести email вручную
        return {
          'provider': 'yandex',
          'manual_entry': 'true',
        };
      } else {
        AppLogger.error('Не удалось открыть браузер для Яндекс авторизации');
        return {'error': 'Не удалось открыть браузер для авторизации'};
      }
    } catch (e) {
      AppLogger.error('Ошибка при входе через Яндекс', e);
      return {'error': e.toString()};
    }
  }

  // Выход
  Future<void> signOut() async {
    try {
      if (_auth != null) {
        await _auth!.signOut();
      }
      if (isGoogleSignInAvailable) {
        await _googleSignIn?.signOut();
      }
      AppLogger.auth('Успешный выход из аккаунта');
    } catch (e) {
      AppLogger.error('Ошибка при выходе из аккаунта', e);
      rethrow;
    }
  }
}
