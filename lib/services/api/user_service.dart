import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_profile.dart';
import '../logger.dart';
import '../../config/api_config.dart';
import 'api_exceptions.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  static String get baseUrl => ApiConfig.baseUrl;

  /// Получение профиля текущего пользователя
  Future<UserProfile?> getUserProfile() async {
    try {
      AppLogger.api('Запрос профиля пользователя');
      
      // Получаем токен авторизации
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        AppLogger.error('Токен авторизации не найден');
        throw UnauthorizedException('Необходимо войти в аккаунт');
      }

      // Формируем заголовки
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
        'Content-Type': 'application/json',
      };

      AppLogger.api('Отправка запроса: GET $baseUrl/users/profile');
      
      // Отправляем запрос
      final response = await http.get(
        Uri.parse('$baseUrl/users/profile'),
        headers: headers,
      ).timeout(Duration(seconds: 10));

      AppLogger.api('Получен ответ: ${response.statusCode}');
      
      // Логируем тело ответа для отладки
      print('==== ОТВЕТ API ПРОФИЛЯ ====');
      print('Статус: ${response.statusCode}');
      print('Тело: ${response.body}');
      print('==== КОНЕЦ ОТВЕТА ====');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final userProfile = UserProfile.fromJson(jsonResponse['data']);
          AppLogger.api('Профиль пользователя загружен: ${userProfile.displayName}');
          return userProfile;
        } else {
          final errorMessage = jsonResponse['message'] ?? 'Не удалось получить профиль';
          AppLogger.error('Ошибка API: $errorMessage');
          throw ServerException(errorMessage);
        }
      } else if (response.statusCode == 401) {
        AppLogger.error('Ошибка авторизации: токен недействителен');
        throw UnauthorizedException('Необходимо войти в аккаунт заново');
      } else {
        try {
          final jsonResponse = json.decode(response.body);
          final errorMessage = jsonResponse['message'] ?? 'Неизвестная ошибка';
          AppLogger.error('Ошибка сервера: $errorMessage (${response.statusCode})');
          throw ServerException(errorMessage);
        } catch (e) {
          AppLogger.error('Ошибка при разборе ответа сервера: $e');
          throw ServerException('Не удалось получить профиль пользователя');
        }
      }
    } on UnauthorizedException {
      rethrow; // Пробрасываем ошибку авторизации
    } on ServerException {
      rethrow; // Пробрасываем ошибки сервера
    } catch (e) {
      AppLogger.error('Ошибка при получении профиля пользователя', e);
      
      if (e.toString().contains('TimeoutException')) {
        throw NoInternetException('Превышено время ожидания. Проверьте подключение к интернету');
      } else if (e.toString().contains('SocketException')) {
        throw NoInternetException('Проблемы с подключением к интернету');
      } else {
        throw UnknownApiException('Произошла ошибка при получении профиля: $e');
      }
    }
  }

  /// Обновление профиля пользователя
  Future<bool> updateUserProfile({
    String? name,
    String? email,
    String? phone,
    String? city,
  }) async {
    try {
      AppLogger.api('Обновление профиля пользователя');
      
      // Получаем токен авторизации
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        AppLogger.error('Токен авторизации не найден');
        throw UnauthorizedException('Необходимо войти в аккаунт');
      }

      // Формируем тело запроса
      final Map<String, dynamic> requestData = {};
      if (name != null && name.isNotEmpty) requestData['name'] = name;
      if (email != null && email.isNotEmpty) requestData['email'] = email;
      if (phone != null && phone.isNotEmpty) requestData['phone'] = phone;
      if (city != null && city.isNotEmpty) requestData['city'] = city;

      if (requestData.isEmpty) {
        AppLogger.error('Нет данных для обновления');
        return false;
      }

      // Формируем заголовки
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
        'Content-Type': 'application/json',
      };

      AppLogger.api('Отправка запроса: PUT $baseUrl/users/profile');
      AppLogger.api('Данные для обновления: $requestData');
      
      final requestBody = json.encode(requestData);
      print('📤 === ОТПРАВКА ОБНОВЛЕНИЯ ПРОФИЛЯ ===');
      print('🔗 URL: $baseUrl/users/profile');
      print('📦 Тело запроса: $requestBody');
      print('🔑 Заголовки: $headers');
      
      // Пробуем сначала PUT, если не работает - попробуем PATCH
      var response = await http.put(
        Uri.parse('$baseUrl/users/profile'),
        headers: headers,
        body: requestBody,
      ).timeout(Duration(seconds: 10));
      
      // Если PUT вернул 405 (Method Not Allowed), пробуем PATCH
      if (response.statusCode == 405) {
        print('⚠️ PUT не поддерживается, пробуем PATCH');
        response = await http.patch(
          Uri.parse('$baseUrl/users/profile'),
          headers: headers,
          body: requestBody,
        ).timeout(Duration(seconds: 10));
      }

      print('📥 === ОТВЕТ СЕРВЕРА ===');
      print('📊 Статус: ${response.statusCode}');
      print('📄 Тело ответа: ${response.body}');
      AppLogger.api('Получен ответ: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        
        if (jsonResponse['success'] == true) {
          AppLogger.api('Профиль пользователя успешно обновлен');
          
          // Очищаем кэш, чтобы при следующем запросе получить свежие данные
          await clearCachedProfile();
          
          return true;
        } else {
          final errorMessage = jsonResponse['message'] ?? 'Не удалось обновить профиль';
          final errorDetails = jsonResponse['error'] ?? jsonResponse['details'];
          print('❌ Ошибка от сервера: $errorMessage');
          if (errorDetails != null) {
            print('📋 Детали ошибки: $errorDetails');
          }
          AppLogger.error('Ошибка API: $errorMessage');
          throw ServerException(errorMessage);
        }
      } else if (response.statusCode == 401) {
        AppLogger.error('Ошибка авторизации: токен недействителен');
        throw UnauthorizedException('Необходимо войти в аккаунт заново');
      } else if (response.statusCode == 400) {
        // Обработка ошибок валидации
        try {
          final jsonResponse = json.decode(response.body);
          final errorMessage = jsonResponse['message'] ?? 'Неверные данные';
          final errorDetails = jsonResponse['error'] ?? jsonResponse['details'];
          print('❌ Ошибка валидации (400): $errorMessage');
          if (errorDetails != null) {
            print('📋 Детали: $errorDetails');
          }
          AppLogger.error('Ошибка валидации: $errorMessage');
          throw ServerException('Ошибка валидации: $errorMessage');
        } catch (e) {
          if (e is ServerException) rethrow;
          AppLogger.error('Ошибка при разборе ответа 400: $e');
          throw ServerException('Неверные данные для обновления профиля');
        }
      } else {
        try {
          final jsonResponse = json.decode(response.body);
          final errorMessage = jsonResponse['message'] ?? 'Неизвестная ошибка';
          final errorDetails = jsonResponse['error'] ?? jsonResponse['details'];
          print('❌ Ошибка сервера (${response.statusCode}): $errorMessage');
          if (errorDetails != null) {
            print('📋 Детали: $errorDetails');
          }
          AppLogger.error('Ошибка сервера: $errorMessage (${response.statusCode})');
          throw ServerException(errorMessage);
        } catch (e) {
          if (e is ServerException) rethrow;
          AppLogger.error('Ошибка при разборе ответа сервера: $e');
          throw ServerException('Не удалось обновить профиль пользователя (код: ${response.statusCode})');
        }
      }
    } on UnauthorizedException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      AppLogger.error('Ошибка при обновлении профиля пользователя', e);
      
      if (e.toString().contains('TimeoutException')) {
        throw NoInternetException('Превышено время ожидания. Проверьте подключение к интернету');
      } else if (e.toString().contains('SocketException')) {
        throw NoInternetException('Проблемы с подключением к интернету');
      } else {
        throw UnknownApiException('Произошла ошибка при обновлении профиля: $e');
      }
    }
  }

  /// Получение профиля из локального кэша
  Future<UserProfile?> getCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_user_profile');
      
      if (cachedData != null) {
        final jsonData = json.decode(cachedData);
        return UserProfile.fromJson(jsonData);
      }
    } catch (e) {
      AppLogger.error('Ошибка при получении кэшированного профиля', e);
    }
    return null;
  }

  /// Сохранение профиля в локальный кэш
  Future<void> cacheProfile(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_profile', json.encode(profile.toJson()));
      AppLogger.api('Профиль пользователя сохранен в кэш');
    } catch (e) {
      AppLogger.error('Ошибка при сохранении профиля в кэш', e);
    }
  }

  /// Очистка кэшированного профиля
  Future<void> clearCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_user_profile');
      AppLogger.api('Кэш профиля пользователя очищен');
    } catch (e) {
      AppLogger.error('Ошибка при очистке кэша профиля', e);
    }
  }
} 