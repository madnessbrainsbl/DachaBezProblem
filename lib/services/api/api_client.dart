import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_exceptions.dart';
import '../logger.dart';
import '../user_preferences_service.dart';
import '../../config/api_config.dart';

class ApiClient {
  static String get baseUrl => ApiConfig.baseUrl;
  static Duration get timeout => ApiConfig.standardTimeout;

  // Приватный конструктор для синглтона
  ApiClient._internal();

  // Статическая переменная для хранения единственного экземпляра
  static final ApiClient _instance = ApiClient._internal();

  // Фабричный конструктор, возвращающий существующий экземпляр
  factory ApiClient() => _instance;

  // Флаг для предотвращения одновременных попыток обновления токена
  bool _isRefreshingToken = false;

  // Метод для GET запросов
  Future<dynamic> get(String endpoint) async {
    return _processRequest(
        () => http.get(Uri.parse('$baseUrl$endpoint')).timeout(timeout));
  }

  // Метод для POST запросов
  Future<dynamic> post(String endpoint, dynamic data) async {
    return _processRequest(() => http.post(Uri.parse('$baseUrl$endpoint'),
        body: json.encode(data),
        headers: {'Content-Type': 'application/json'}).timeout(timeout));
  }

  // Обработка ответа с проверкой на ошибки
  Future<dynamic> _processRequest(
      Future<http.Response> Function() request) async {
    try {
      // Логируем начало запроса
      AppLogger.api('Отправка запроса...');

      final response = await request();
      return _processResponse(response);
    } on SocketException {
      AppLogger.error('Нет соединения с интернетом');
      throw NoInternetException(
          'Нет соединения с интернетом. Проверьте подключение и попробуйте снова.');
    } on TimeoutException {
      AppLogger.error('Тайм-аут запроса');
      throw ApiTimeoutException('Время запроса истекло. Попробуйте позже.');
    } catch (e) {
      AppLogger.error('Ошибка при выполнении запроса', e);
      throw UnknownApiException('Произошла неизвестная ошибка: $e');
    }
  }

  // Обработка ответа с сервера
  dynamic _processResponse(http.Response response) {
    // Логируем ответ сервера, но не сам JSON для экономии места в логе
    AppLogger.api('Ответ API (${response.statusCode}): получен');
    print('==== ApiClient._processResponse ====');
    print('Статус код: ${response.statusCode}');
    print('Тело ответа: ${response.body}'); // Печатаем все тело ответа для отладки

    final responseJson = json.decode(response.body);

    // Проверяем наличие и сохраняем токен, если он есть
    if (responseJson.containsKey('data') &&
        responseJson['data'] != null &&
        responseJson['data'].containsKey('token') &&
        responseJson['data']['token'] != null) {
      print('Найден токен в ответе: [32m${responseJson['data']['token']}[0m');
      _saveAuthToken(responseJson['data']['token']);
    } else {
      print('Токен в ответе НЕ НАЙДЕН.');
    }

    switch (response.statusCode) {
      case 200:
      case 201:
        print('Успешный ответ. Возвращаем JSON.');
        return responseJson;
      case 400:
        print('Ошибка 400: BadRequestException');
        throw BadRequestException(responseJson['message'] ?? 'Неверный запрос');
      case 401:
      case 403:
        print('Ошибка 401/403: Попытка обновления токена...');
        _handleUnauthorized();
        throw UnauthorizedException(
            responseJson['message'] ?? 'Доступ запрещен');
      case 404:
        print('Ошибка 404: NotFoundException');
        throw NotFoundException(responseJson['message'] ?? 'Ресурс не найден');
      case 500:
      default:
        print('Ошибка 500/default: ServerException');
        throw ServerException(responseJson['message'] ?? 'Ошибка сервера');
    }
  }

  /// Обработка ошибки авторизации с попыткой восстановления
  void _handleUnauthorized() async {
    if (_isRefreshingToken) return; // Предотвращаем множественные попытки

    _isRefreshingToken = true;
    try {
      print('🔄 Обнаружена ошибка авторизации, проверяем состояние...');
      
      // Проверяем текущее состояние пользователя
      final authState = await UserPreferencesService.getAuthState();
      
      if (authState['isLoggedIn'] == true) {
        print('⚠️ Пользователь считается авторизованным, но токен недействителен');
        print('🧹 Очищаем некорректное состояние авторизации');
        
        // Очищаем некорректное состояние
        await UserPreferencesService.clearAuthState();
        
        // Логируем для отладки
        AppLogger.error('Токен недействителен при активной сессии - состояние очищено');
      }
    } catch (e) {
      print('❌ Ошибка при обработке неавторизованного запроса: $e');
    } finally {
      _isRefreshingToken = false;
    }
  }

  /// Сохранение токена авторизации
  Future<void> _saveAuthToken(String token) async {
    try {
      AppLogger.api('Сохранение токена авторизации: ${token.substring(0, 10)}...');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      print('Токен УСПЕШНО сохранен в SharedPreferences под ключом auth_token');
      
      // УЛУЧШЕНИЕ: Логируем время сохранения токена для отладки
      await prefs.setString('auth_token_timestamp', DateTime.now().toIso8601String());
      print('📅 Время сохранения токена: ${DateTime.now()}');
    } catch (e) {
      AppLogger.error('Ошибка при сохранении токена авторизации', e);
      print('КРИТИЧЕСКАЯ ОШИБКА при сохранении токена: $e');
    }
  }

  /// Проверка актуальности токена (вспомогательный метод для отладки)
  static Future<Map<String, dynamic>> getTokenInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final timestamp = prefs.getString('auth_token_timestamp');
      
      if (token == null) {
        return {'hasToken': false, 'message': 'Токен отсутствует'};
      }
      
      final tokenLength = token.length;
      final savedAt = timestamp != null ? DateTime.parse(timestamp) : null;
      final now = DateTime.now();
      final ageInHours = savedAt != null ? now.difference(savedAt).inHours : null;
      
      return {
        'hasToken': true,
        'tokenLength': tokenLength,
        'savedAt': savedAt?.toIso8601String(),
        'ageInHours': ageInHours,
        'isValid': tokenLength > 0, // Простая проверка на наличие
      };
    } catch (e) {
      return {'hasToken': false, 'error': e.toString()};
    }
  }
}
