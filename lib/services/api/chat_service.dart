import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

import '../logger.dart';
import 'api_client.dart';
import 'api_exceptions.dart';
import '../../models/chat_message.dart';
import '../../config/api_config.dart';

class ChatService {
  final ApiClient _apiClient = ApiClient();
  
  // Базовый URL и таймауты берутся из конфигурации
  static String get baseUrl => ApiConfig.baseUrl;
  
  // Timeout для запросов чата
  static Duration get chatTimeout => ApiConfig.chatTimeout;

  /// Получение токена авторизации
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      AppLogger.error('Ошибка получения токена', e);
      return null;
    }
  }

  /// Получение истории чата
  Future<Map<String, dynamic>> getChatHistory({int page = 1, int limit = 20}) async {
    print('📖 === ЗАГРУЗКА ИСТОРИИ ЧАТА ===');
    print('📊 Параметры: page=$page, limit=$limit');
    
    try {
      final token = await _getAuthToken();
      if (token == null) {
        print('❌ Токен не найден');
        throw Exception('Токен авторизации не найден');
      }

      final url = '${baseUrl}/chat/history';
      print('🌐 URL запроса: $url');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
      };
      print('📤 Заголовки: ${headers.toString()}');

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      print('🔍 Параметры запроса: ${queryParams.toString()}');

      final uri = Uri.parse(url).replace(queryParameters: queryParams);
      print('🔗 Полный URI: $uri');

      print('⏳ Отправка GET запроса...');
      final response = await http.get(uri, headers: headers);
      
      print('📨 Получен ответ:');
      print('📊 Статус код: ${response.statusCode}');
      print('📦 Размер ответа: ${response.body.length} символов');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ JSON успешно распарсен');
        print('📊 Структура ответа: ${data.keys.toList()}');
        
        // Проверяем правильную структуру: {success: true, data: {history: [...]}}
        if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
          final dataSection = data['data'] as Map<String, dynamic>;
          print('📊 Структура data секции: ${dataSection.keys.toList()}');
          
          if (dataSection.containsKey('history')) {
            final history = dataSection['history'] as List;
            print('📚 История содержит ${history.length} сообщений');
            
            if (history.isNotEmpty) {
              print('📝 Первое сообщение: ${history.first.toString()}');
              if (history.length > 1) {
                print('📝 Последнее сообщение: ${history.last.toString()}');
              }
            } else {
              print('📭 История сообщений пуста');
            }
          } else {
            print('⚠️ Поле "history" отсутствует в data секции');
          }
        } else {
          print('⚠️ Поле "data" отсутствует в ответе или имеет неправильный тип');
        }
        
        print('🏁 === ЗАВЕРШЕНИЕ ЗАГРУЗКИ ИСТОРИИ ===');
        return data;
      } else {
        print('❌ Ошибка HTTP: ${response.statusCode}');
        print('📄 Тело ошибки: ${response.body}');
        throw Exception('Ошибка получения истории чата: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Критическая ошибка загрузки истории: $e');
      AppLogger.error('Ошибка получения истории чата', e);
      rethrow;
    }
  }

  /// Отправка текстового сообщения
  Future<Map<String, dynamic>> sendTextMessage(String text) async {
    print('✉️ === ОТПРАВКА ТЕКСТОВОГО СООБЩЕНИЯ ===');
    print('📝 Текст: "$text"');
    
    try {
      final token = await _getAuthToken();
      if (token == null) {
        print('❌ Токен не найден');
        throw Exception('Токен авторизации не найден');
      }

      final url = '${baseUrl}/chat/send';
      print('🌐 URL: $url');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
      };

      final body = jsonEncode({
        'text': text,
      });
      print('📤 Тело запроса: $body');

      print('⏳ Отправка POST запроса...');
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      print('📨 Получен ответ: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Текстовое сообщение отправлено успешно');
        print('📦 Ответ: ${data.toString()}');
        return data;
      } else {
        print('❌ Ошибка отправки: ${response.statusCode}');
        print('📄 Тело ошибки: ${response.body}');
        throw Exception('Ошибка отправки сообщения: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Критическая ошибка отправки текста: $e');
      AppLogger.error('Ошибка отправки текстового сообщения', e);
      rethrow;
    }
  }

  /// Отправка сообщения с изображением
  Future<Map<String, dynamic>> sendImageMessage({
    required File imageFile,
    String? text,
  }) async {
    print('🖼️ === ОТПРАВКА СООБЩЕНИЯ С ИЗОБРАЖЕНИЕМ ===');
    print('📷 Файл изображения: ${imageFile.path}');
    print('📝 Текст: "${text ?? 'нет'}"');
    
    // Проверяем, не blob ли это URL (веб-версия)
    if (imageFile.path.startsWith('blob:') || imageFile.path.startsWith('http://localhost')) {
      print('⚠️ Обнаружен blob URL - веб-версия не поддерживает отправку изображений');
      throw Exception('Отправка изображений доступна только в мобильном приложении. Пожалуйста, установите APK версию.');
    }
    
    try {
      final token = await _getAuthToken();
      if (token == null) {
        print('❌ Токен не найден');
        throw Exception('Токен авторизации не найден');
      }

      final url = '${baseUrl}/chat/send';
      print('🌐 URL: $url');

      final request = http.MultipartRequest('POST', Uri.parse(url));
      
      request.headers['Authorization'] = token.startsWith('Bearer ') ? token : 'Bearer $token';
      print('🔐 Заголовки авторизации установлены');

      // Добавляем изображение
      List<int> imageBytes;
      try {
        imageBytes = await imageFile.readAsBytes();
        print('📏 Размер изображения: ${imageBytes.length} байт');
      } catch (e) {
        print('❌ Ошибка чтения файла: $e');
        print('📄 Путь к файлу: ${imageFile.path}');
        
        // Проверяем, не blob ли это URL (для веб-версии)
        if (imageFile.path.startsWith('blob:')) {
          throw Exception('Blob URL не поддерживается. Используйте нативное приложение для отправки изображений.');
        }
        
        throw Exception('Не удалось прочитать файл изображения: $e');
      }
      
      // Определяем MIME-тип и имя файла
      String fileName;
      try {
        // Пробуем использовать path.basename
        fileName = path.basename(imageFile.path);
        print('📄 Имя файла (path.basename): $fileName');
      } catch (e) {
        // Если path.basename не работает, используем альтернативный метод
        print('⚠️ Ошибка path.basename: $e');
        final pathParts = imageFile.path.split(Platform.pathSeparator);
        fileName = pathParts.isNotEmpty ? pathParts.last : 'image.jpg';
        print('📄 Имя файла (альтернативный метод): $fileName');
      }
      
      final fileNameLower = fileName.toLowerCase();
      MediaType contentType;
      
      if (fileNameLower.endsWith('.jpg') || fileNameLower.endsWith('.jpeg')) {
        contentType = MediaType('image', 'jpeg');
      } else if (fileNameLower.endsWith('.png')) {
        contentType = MediaType('image', 'png');
      } else if (fileNameLower.endsWith('.gif')) {
        contentType = MediaType('image', 'gif');
      } else if (fileNameLower.endsWith('.webp')) {
        contentType = MediaType('image', 'webp');
      } else {
        // По умолчанию считаем JPEG
        contentType = MediaType('image', 'jpeg');
        print('⚠️ Неизвестное расширение, используем image/jpeg');
      }
      
      print('📄 MIME-тип: ${contentType.mimeType}');
      
      try {
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: fileName,
          contentType: contentType,
        ));
        print('📎 Изображение добавлено к запросу');
      } catch (e) {
        print('❌ Ошибка добавления файла: $e');
        throw Exception('Не удалось добавить изображение к запросу: $e');
      }

      // Добавляем текст если есть
      if (text != null && text.isNotEmpty) {
        request.fields['text'] = text;
        print('📝 Текст добавлен к запросу');
      }

      print('⏳ Отправка multipart запроса...');
      
      http.StreamedResponse streamedResponse;
      try {
        streamedResponse = await request.send().timeout(
          Duration(seconds: 60),
          onTimeout: () {
            throw TimeoutException('Превышено время ожидания отправки изображения');
          },
        );
      } catch (e) {
        print('❌ Ошибка отправки запроса: $e');
        throw Exception('Не удалось отправить запрос: $e');
      }
      
      http.Response response;
      try {
        response = await http.Response.fromStream(streamedResponse);
      } catch (e) {
        print('❌ Ошибка чтения ответа: $e');
        throw Exception('Не удалось прочитать ответ сервера: $e');
      }

      print('📨 Получен ответ: ${response.statusCode}');
      print('📄 Тело ответа: ${response.body.length > 500 ? response.body.substring(0, 500) + "..." : response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = jsonDecode(response.body);
          print('✅ Изображение отправлено успешно');
          print('📦 Ответ распарсен успешно');
          return data;
        } catch (e) {
          print('❌ Ошибка парсинга JSON: $e');
          throw Exception('Не удалось распарсить ответ сервера: $e');
        }
      } else {
        print('❌ Ошибка отправки изображения: ${response.statusCode}');
        print('📄 Тело ошибки: ${response.body}');
        throw Exception('Ошибка сервера (${response.statusCode}): ${response.body}');
      }
    } on TimeoutException catch (e) {
      print('⏰ Таймаут отправки изображения: $e');
      AppLogger.error('Таймаут отправки изображения', e);
      throw Exception('Превышено время ожидания. Попробуйте еще раз.');
    } catch (e) {
      print('💥 Критическая ошибка отправки изображения: $e');
      print('💥 Тип ошибки: ${e.runtimeType}');
      AppLogger.error('Ошибка отправки сообщения с изображением', e);
      rethrow;
    }
  }

  /// Запрос оператора
  Future<Map<String, dynamic>> requestOperator({String? message}) async {
    try {
      final token = await _getAuthToken();
      if (token == null || token.isEmpty) {
        throw UnauthorizedException('Токен авторизации не найден');
      }

      print('Запрос оператора');
      
      final requestData = <String, dynamic>{};
      if (message != null && message.trim().isNotEmpty) {
        requestData['message'] = message.trim();
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/chat/request-operator'),
        headers: {
          'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestData),
      ).timeout(chatTimeout);
      
      print('Получен ответ запроса оператора: ${response.statusCode}');
      
      return _processResponse(response);
    } catch (e) {
      AppLogger.error('Ошибка при запросе оператора', e);
      rethrow;
    }
  }

  /// Обработка ответа сервера
  Map<String, dynamic> _processResponse(http.Response response) {
    print('Обработка ответа чата (${response.statusCode})');
    print('==== ChatService._processResponse ====');
    print('Статус код: ${response.statusCode}');
    print('Тело ответа: ${response.body}');

    final responseJson = jsonDecode(response.body);

    switch (response.statusCode) {
      case 200:
      case 201:
        print('Успешный ответ чата. Возвращаем JSON.');
        return responseJson;
      case 400:
        print('Ошибка 400: BadRequestException');
        throw BadRequestException(responseJson['message'] ?? 'Неверный запрос');
      case 401:
      case 403:
        print('Ошибка 401/403: UnauthorizedException');
        throw UnauthorizedException(responseJson['message'] ?? 'Доступ запрещен');
      case 404:
        print('Ошибка 404: NotFoundException');
        throw NotFoundException(responseJson['message'] ?? 'Ресурс не найден');
      case 413:
        print('Ошибка 413: Файл слишком большой');
        throw BadRequestException('Файл слишком большой. Максимальный размер: 10MB');
      case 429:
        print('Ошибка 429: Слишком много запросов');
        throw ApiTimeoutException('Слишком много запросов. Попробуйте позже.');
      case 500:
      default:
        print('Ошибка 500/default: ServerException');
        throw ServerException(responseJson['message'] ?? 'Ошибка сервера');
    }
  }
} 