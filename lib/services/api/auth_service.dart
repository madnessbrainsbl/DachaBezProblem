import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';

import 'api_client.dart';
import 'api_exceptions.dart';
import '../logger.dart';
import '../social_auth_service.dart';
import '../user_preferences_service.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();
  final SocialAuthService _socialAuth = SocialAuthService();

  // Синглтон
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Хранение данных о текущем процессе аутентификации
  String? _userId;
  String? _authMethod;

  // Геттеры для доступа к текущим данным аутентификации
  String? get userId => _userId;
  String? get authMethod => _authMethod;

  // Отправка кода подтверждения на телефон или email
  Future<bool> sendAuthCode({String? phone, String? email}) async {
    try {
      // Проверка наличия хотя бы одного параметра
      if (phone == null && email == null) {
        throw BadRequestException('Необходимо указать телефон или email');
      }

      final data = phone != null ? {'phone': phone} : {'email': email};

      // Вывод в лог для отладки
      AppLogger.auth('Отправка запроса на код для: ${phone ?? email}');

      final response = await _apiClient.post('/auth/send-code', data);

      // Сохраняем ID пользователя и метод аутентификации для последующих запросов
      _userId = response['data']['userId'];
      _authMethod = response['data']['authMethod'];

      AppLogger.auth('Получен userId: $_userId, метод: $_authMethod');

      return response['success'] == true;
    } on ApiException catch (e) {
      AppLogger.error('Ошибка при отправке кода', e);
      rethrow;
    } catch (e) {
      AppLogger.error('Непредвиденная ошибка при отправке кода', e);
      throw UnknownApiException('Произошла ошибка при отправке кода: $e');
    }
  }

  // Проверка кода подтверждения
  Future<Map<String, dynamic>> verifyAuthCode({required String code}) async {
    try {
      // Проверка, что у нас есть ID пользователя
      if (_userId == null) {
        throw BadRequestException('Сначала отправьте код на телефон или email');
      }

      final data = {'userId': _userId, 'code': code};

      AppLogger.auth('Проверка кода: $code для userId: $_userId');

      final response = await _apiClient.post('/auth/verify-code', data);

      if (response['success'] == true) {
        // Извлекаем информацию о профиле пользователя
        var result = {
          'success': true,
          'userId': _userId,
          'authMethod': _authMethod,
          'name': response['data']['name'],
          'city': response['data']['city'],
          'isProfileComplete': response['data']['isProfileComplete'] ?? false,
        };

        // Сохраняем данные авторизации
        await UserPreferencesService.saveAuthState(
          userId: _userId!,
          authMethod: _authMethod!,
          userName: response['data']['name'],
          userCity: response['data']['city'],
          isProfileComplete: response['data']['isProfileComplete'] ?? false,
        );

        AppLogger.auth('Профиль пользователя: $result');
        return result;
      }

      return {'success': false};
    } on ApiException catch (e) {
      AppLogger.error('Ошибка при проверке кода', e);
      rethrow;
    } catch (e) {
      AppLogger.error('Непредвиденная ошибка при проверке кода', e);
      throw UnknownApiException('Произошла ошибка при проверке кода: $e');
    }
  }

  // Обновление профиля пользователя (имя и город) - НОВАЯ РЕАЛИЗАЦИЯ
  Future<bool> updateProfile({required String name, required String city}) async {
    try {
      // Проверка, что аутентификация была выполнена (наличие токена)
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        AppLogger.error('Токен авторизации не найден');
        throw UnauthorizedException('Необходимо выполнить вход заново');
      }

      // Валидация входных данных
      if (name.isEmpty) {
        throw BadRequestException('Необходимо указать имя');
      }

      if (city.isEmpty) {
        throw BadRequestException('Необходимо указать город');
      }

      // Формируем тело запроса
      final Map<String, dynamic> requestData = {
        'name': name,
        'city': city,
      };

      // Заголовки с токеном
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
        'Content-Type': 'application/json',
      };

      AppLogger.auth('Отправка запроса обновления профиля (PUT /users/profile)');
      AppLogger.auth('Данные: $requestData');

      final response = await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}/users/profile'),
            headers: headers,
            body: json.encode(requestData),
          )
          .timeout(Duration(seconds: 10));

      AppLogger.auth('Код ответа: ${response.statusCode}');
      AppLogger.auth('Тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          // Сохраняем/обновляем локальное состояние авторизации
          await UserPreferencesService.saveAuthState(
            userId: _userId ?? jsonResponse['data']['id'] ?? '',
            authMethod: _authMethod ?? 'email',
            userName: name,
            userCity: city,
            isProfileComplete: true,
          );

          AppLogger.auth('Профиль успешно обновлен');
          return true;
        } else {
          final message = jsonResponse['message'] ?? 'Не удалось обновить профиль';
          AppLogger.error('Ошибка API при обновлении профиля: $message');
          throw ServerException(message);
        }
      } else if (response.statusCode == 401) {
        throw UnauthorizedException('Сессия истекла. Войдите заново.');
      } else {
        final jsonResponse = json.decode(response.body);
        final message = jsonResponse['message'] ?? 'Неизвестная ошибка';
        throw ServerException(message);
      }
    } on ApiException catch (e) {
      AppLogger.error('Ошибка при обновлении профиля', e);
      rethrow;
    } on UnauthorizedException catch (e) {
      AppLogger.error('Ошибка авторизации при обновлении профиля', e);
      rethrow;
    } catch (e) {
      AppLogger.error('Непредвиденная ошибка при обновлении профиля', e);
      throw UnknownApiException('Произошла ошибка при обновлении профиля: $e');
    }
  }

  // Очистка данных аутентификации (например при выходе из приложения)
  Future<void> clearAuthData() async {
    _userId = null;
    _authMethod = null;
    // Очищаем данные в хранилище
    await UserPreferencesService.clearAuthState();
    AppLogger.auth('Данные аутентификации очищены');
  }

  // Общий метод для OAuth авторизации
  Future<Map<String, dynamic>> oauthSignIn({
    required String email,
    required String provider,
    String? name,
  }) async {
    try {
      AppLogger.auth('Начало процесса OAuth входа через $provider');

      final data = {
        'email': email,
        'provider': provider,
      };

      // Добавляем имя пользователя, если оно предоставлено
      if (name != null && name.isNotEmpty) {
        data['name'] = name;
      }

      final response = await _apiClient.post('/auth/oauth', data);

      if (response['success'] == true) {
        _userId = response['data']['userId'];
        _authMethod = 'email'; // OAuth всегда использует email

        // Если сервер вернул код верификации (для одноразового входа)
        final verificationCode = response['data']['verificationCode'];

        if (verificationCode != null) {
          // Автоматически проверяем одноразовый код
          return await verifyAuthCode(code: verificationCode);
        }

        // Сохраняем данные авторизации
        await UserPreferencesService.saveAuthState(
          userId: _userId!,
          authMethod: _authMethod!,
          userName: response['data']['name'],
          userCity: response['data']['city'],
          isProfileComplete: response['data']['isProfileComplete'] ?? false,
        );

        return {
          'success': true,
          'userId': _userId,
          'authMethod': _authMethod,
          'name': response['data']['name'],
          'city': response['data']['city'],
          'isProfileComplete': response['data']['isProfileComplete'] ?? false,
        };
      }

      return {'success': false, 'message': 'Ошибка авторизации'};
    } on ApiException catch (e) {
      AppLogger.error('Ошибка при OAuth входе', e);
      rethrow;
    } catch (e) {
      AppLogger.error('Непредвиденная ошибка при OAuth входе', e);
      throw UnknownApiException('Произошла ошибка при OAuth входе: $e');
    }
  }

  // Вход через Google
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      AppLogger.auth('Начало процесса входа через Google');

      // Проверяем доступность Google Sign-In на текущей платформе
      if (!_socialAuth.isGoogleSignInAvailable) {
        return {
          'success': false,
          'message': 'Вход через Google недоступен на этой платформе'
        };
      }

      // Получаем данные от сервиса Google авторизации
      final result = await _socialAuth.signInWithGoogle();

      // Проверяем наличие ошибок
      if (result.containsKey('error')) {
        return {'success': false, 'message': result['error']};
      }

      // Проверяем наличие email
      if (result['email'] == null) {
        return {'success': false, 'message': 'Не удалось получить email'};
      }

      // Выполняем OAuth авторизацию
      return await oauthSignIn(
        email: result['email']!,
        provider: 'google',
        name: result['name'],
      );
    } catch (e) {
      AppLogger.error('Ошибка при входе через Google', e);
      return {'success': false, 'message': e.toString()};
    }
  }

  // Вход через Apple
  Future<Map<String, dynamic>> signInWithApple() async {
    try {
      AppLogger.auth('Начало процесса входа через Apple');

      // Проверяем доступность Apple Sign-In на текущей платформе
      if (!_socialAuth.isAppleSignInAvailable) {
        return {
          'success': false,
          'message': 'Вход через Apple недоступен на этой платформе'
        };
      }

      // Получаем данные от сервиса Apple авторизации
      final result = await _socialAuth.signInWithApple();

      // Проверяем наличие ошибок
      if (result.containsKey('error')) {
        // Проверяем, связана ли ошибка с симулятором
        if (result['error'].toString().contains('симулятор') ||
            result['error'].toString().contains('Apple ID')) {
          AppLogger.auth('Ошибка аутентификации Apple в симуляторе');
          return {
            'success': false,
            'simulator_error': true,
            'message': 'Вход через Apple может не работать в симуляторе. '
                'Попробуйте другой способ входа или запустите приложение на реальном устройстве.'
          };
        }
        return {'success': false, 'message': result['error']};
      }

      // Проверяем наличие email
      if (result['email'] == null) {
        // Для Apple это нормально при повторном входе
        // TODO: Здесь можно реализовать сохранение/получение email из локального хранилища
        return {'success': false, 'message': 'Не удалось получить email'};
      }

      // Выполняем OAuth авторизацию
      return await oauthSignIn(
        email: result['email']!,
        provider: 'apple',
        name: result['name'],
      );
    } catch (e) {
      AppLogger.error('Ошибка при входе через Apple', e);
      return {'success': false, 'message': e.toString()};
    }
  }

  // Вход через Яндекс (упрощенная версия)
  Future<Map<String, dynamic>> signInWithYandex() async {
    try {
      AppLogger.auth('Начало процесса входа через Яндекс');

      // Проверяем доступность
      if (!_socialAuth.isYandexSignInAvailable) {
        return {
          'success': false,
          'message': 'Вход через Яндекс недоступен на этой платформе'
        };
      }

      // Получаем результат от сервиса Яндекс авторизации
      final result = await _socialAuth.signInWithYandex();

      // Проверяем наличие ошибок
      if (result.containsKey('error')) {
        return {'success': false, 'message': result['error']};
      }

      // Если получен флаг ручного ввода, возвращаем специальный результат
      if (result.containsKey('manual_entry') &&
          result['manual_entry'] == 'true') {
        return {
          'success': true,
          'manual_entry': true,
          'provider': 'yandex',
          'message':
              'Пожалуйста, введите адрес электронной почты, который вы использовали для входа в Яндекс'
        };
      }

      // Для обычного потока с email
      if (result['email'] != null) {
        // Отправляем данные на наш бэкенд
        final response = await _apiClient.post('/auth/oauth', {
          'email': result['email'],
          'provider': 'yandex',
          'name': result['name'],
        });

        if (response['success'] == true) {
          _userId = response['data']['userId'];
          _authMethod = 'email'; // OAuth всегда использует email

          // Если сервер вернул код верификации (для одноразового входа)
          final verificationCode = response['data']['verificationCode'];

          if (verificationCode != null) {
            // Автоматически проверяем одноразовый код
            return await verifyAuthCode(code: verificationCode);
          }

          return {
            'success': true,
            'userId': _userId,
            'authMethod': _authMethod,
            'name': response['data']['name'],
            'city': response['data']['city'],
            'isProfileComplete': response['data']['isProfileComplete'] ?? false,
          };
        }
      }

      return {'success': false, 'message': 'Ошибка авторизации через Яндекс'};
    } on ApiException catch (e) {
      AppLogger.error('Ошибка при входе через Яндекс', e);
      rethrow;
    } catch (e) {
      AppLogger.error('Непредвиденная ошибка при входе через Яндекс', e);
      return {'success': false, 'message': e.toString()};
    }
  }

  // Выход из аккаунта (включая социальные сети)
  Future<void> signOut() async {
    // Очищаем данные авторизации в нашем сервисе
    await clearAuthData();

    // Выходим из Firebase и социальных сетей
    await _socialAuth.signOut();
  }
}
