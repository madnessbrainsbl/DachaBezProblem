import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import '../logger.dart';
import 'api_client.dart';
import 'api_exceptions.dart';
import '../../models/plant_info.dart';
import '../../config/api_config.dart';
import '../plant_events.dart';

class ScanService {
  final ApiClient _apiClient = ApiClient();
  
  // Базовый URL берется из конфигурации
  static String get baseUrl => ApiConfig.baseUrl;
  
  // Timeout для сканирования растений (из-за работы нейросети)
  static Duration get scanTimeout => ApiConfig.scanTimeout;

  // Метод для сканирования растения
  Future<Map<String, dynamic>> scanPlant({
    required File imageFile,
    File? cropFile, // НОВОЕ: кроп изображения
    required String token,
    String? deviceInfo,
  }) async {
    print('🚀 ===== НАЧАЛО ПРОЦЕССА СКАНИРОВАНИЯ РАСТЕНИЯ =====');
    print('📸 Файл изображения: ${imageFile.path}');
    print('🔐 Токен: ${token.isEmpty ? "ПУСТОЙ!" : "Длина ${token.length}"}');
    print('📱 Информация об устройстве: ${deviceInfo ?? "не указана"}');
    
    AppLogger.api('Сканирование растения. Начинаем отправку изображения...');
    
    try {
      // Проверяем существование файла
      if (!await imageFile.exists()) {
        print('❌ ОШИБКА: Файл изображения не существует!');
        throw Exception('Файл изображения не найден');
      }
      
      // Создаем URL и вспомогательную функцию для отправки запроса
      final uri = Uri.parse('${ScanService.baseUrl}/scan/scan');
      print('🌐 URL сканирования: $uri');

      // Загружаем базовую информацию о файлах один раз
      final fileSize = await imageFile.length();
      print('📏 Размер файла: ${(fileSize / 1024).toStringAsFixed(2)} KB');
      AppLogger.api('Размер файла: ${(fileSize / 1024).toStringAsFixed(2)} KB');
      final fileName = imageFile.path.split('/').last;
      print('📄 Имя файла: $fileName');
      AppLogger.api('Имя файла: $fileName');
      String contentType = 'image/jpeg';
      if (fileName.toLowerCase().endsWith('.png')) {
        contentType = 'image/png';
      } else if (fileName.toLowerCase().endsWith('.gif')) {
        contentType = 'image/gif';
      }
      print('🎨 MIME-тип: $contentType');
      final fileBytes = await imageFile.readAsBytes();
      print('✅ Файл прочитан: ${fileBytes.length} байт');

      Future<http.Response> sendAttempt({
        required String imageField,
        String? cropField,
        required bool includeCrop,
        required int attempt,
      }) async {
        print('🚀 Попытка #$attempt: imageField=$imageField, cropField=${cropField ?? "<none>"}, includeCrop=$includeCrop');
        final request = http.MultipartRequest('POST', uri);
        // Робастный заголовок авторизации (учитываем, что токен может already иметь префикс)
        request.headers['Authorization'] = token.startsWith('Bearer ') ? token : 'Bearer $token';

        // Файлы
        request.files.add(http.MultipartFile.fromBytes(
          imageField,
          fileBytes,
          filename: fileName,
          contentType: MediaType.parse(contentType),
        ));

        if (includeCrop && cropFile != null && await cropFile.exists()) {
          final cropFileBytes = await cropFile.readAsBytes();
          final cropFileName = cropFile.path.split('/').last;
          request.files.add(http.MultipartFile.fromBytes(
            cropField ?? 'crop',
            cropFileBytes,
            filename: cropFileName,
            contentType: MediaType.parse('image/jpeg'),
          ));
        }

        // Поля — отправляем минимально необходимое; добавляем device_info только если передан
        

        // Логи запроса
        print('=== DEBUG: Attempt #$attempt Multipart details ===');
        print('Файлы:');
        for (var f in request.files) {
          print('  field=${f.field}, filename=${f.filename}, length=${f.length}');
        }
        print('Поля:');
        request.fields.forEach((k, v) => print('  $k=$v'));
        print('Заголовки:');
        request.headers.forEach((k, v) => print('  $k: $v'));
        print('=== END DEBUG (Attempt #$attempt) ===');

        final streamedResponse = await request.send().timeout(ScanService.scanTimeout);
        final response = await http.Response.fromStream(streamedResponse);
        print('📊 Статус ответа (attempt #$attempt): ${response.statusCode}');
        return response;
      }

      // Список стратегий отправки
      final attempts = <Map<String, dynamic>>[
        // 1) Минимальный классический вариант — только "image"
        {'imageField': 'image', 'cropField': 'crop', 'includeCrop': false},
        // 2) Классический с кропом
        {'imageField': 'image', 'cropField': 'crop', 'includeCrop': true},
        // 3) Альтернативные имена полей
        {'imageField': 'photo', 'cropField': 'crop_image', 'includeCrop': true},
        {'imageField': 'file', 'cropField': 'crop', 'includeCrop': true},
      ];

      http.Response? response;
      Map<String, dynamic>? lastErrorJson;
      for (int i = 0; i < attempts.length; i++) {
        final cfg = attempts[i];
        response = await sendAttempt(
          imageField: cfg['imageField'],
          cropField: cfg['cropField'],
          includeCrop: cfg['includeCrop'],
          attempt: i + 1,
        );
        if (response.statusCode == 200) break;
        // Сохраняем последнее тело ошибки для диагностики
        try {
          lastErrorJson = json.decode(response.body);
        } catch (_) {}
      }

      if (response == null) {
        throw ServerException('Не удалось отправить запрос на сервер.');
      }

      // Логируем получение данных
      print('📥 Получаем данные из ответа...');
      
      // Логируем код ответа
      print('📊 Статус ответа: ${response.statusCode}');
      AppLogger.api('Получен ответ. Статус: ${response.statusCode}');
      
      // Проверяем и обрабатываем ответ
      if (response.statusCode == 200) {
        print('✅ Успешный ответ от сервера!');
        
        // Логируем размер ответа
        print('📏 Размер ответа: ${response.body.length} символов');
        
        final jsonResponse = json.decode(response.body);
        
        // Безопасно логируем успешный ответ
        print('✅ JSON успешно декодирован');
        print('🎯 Success flag: ${jsonResponse['success']}');
        AppLogger.api('Получен успешный ответ: ${jsonResponse['success']}');
        
        // Проверяем структуру ответа для логирования
        String plantName = 'Неизвестно';
        bool isHealthy = true;
        String? scanId;
        Map<String, dynamic>? images;
        
        // НОВЕЙШАЯ структура: данные в корне под plant (после обновления бэкенда)
        if (jsonResponse.containsKey('plant') && jsonResponse['plant'] != null) {
          print('📦 Найдена новая структура plant в корне');
          final plant = jsonResponse['plant'];
          plantName = plant['plantName'] ?? 'Неизвестно';
          // В новой структуре пока нет is_healthy, предполагаем здоровое
          isHealthy = true;
          
          // Создаем images map из новых полей
          images = <String, dynamic>{};
          if (plant['image_url'] != null) {
            images['main_image'] = plant['image_url'];
            images['original'] = plant['image_url']; // для совместимости
          }
          if (plant['crop_url'] != null) {
            images['thumbnail'] = plant['crop_url'];
            images['crop'] = plant['crop_url']; // для совместимости
          }
          
          // Scan ID из _id
          scanId = plant['_id'];
        }
        // Новая структура: данные в корне под plant_info
        else if (jsonResponse.containsKey('plant_info') && jsonResponse['plant_info'] != null) {
          print('📦 Найдена структура plant_info в корне');
          final plantInfo = jsonResponse['plant_info'];
          plantName = plantInfo['name'] ?? 'Неизвестно';
          isHealthy = plantInfo['is_healthy'] ?? true;
          images = plantInfo['images'];
          
          // Ищем scan_id в разных местах
          scanId = jsonResponse['scan_id'] ?? plantInfo['scan_id'];
        }
        // Старая структура: данные в data.plant_info (для совместимости)
        else if (jsonResponse.containsKey('data') && 
                 jsonResponse['data'] != null && 
                 jsonResponse['data'].containsKey('plant_info') && 
                 jsonResponse['data']['plant_info'] != null) {
          print('📦 Найдена структура data.plant_info');
          final plantInfo = jsonResponse['data']['plant_info'];
          plantName = plantInfo['name'] ?? 'Неизвестно';
          isHealthy = plantInfo['is_healthy'] ?? true;
          images = plantInfo['images'];
          
          // Ищем scan_id в разных местах
          scanId = jsonResponse['data']['scan_id'] ?? jsonResponse['scan_id'] ?? plantInfo['scan_id'];
        }
        
        print('🌱 Обнаружено растение: $plantName');
        print('💚 Состояние: ${isHealthy ? 'Здоровое' : 'Больное'}');
        print('🆔 Scan ID: ${scanId ?? "НЕ НАЙДЕН!"}');
        AppLogger.api('Обнаружено растение: $plantName');
        AppLogger.api('Состояние: ${isHealthy ? 'Здоровое' : 'Больное'}');
        
        // Логируем информацию об изображениях
        if (images != null && images.isNotEmpty) {
          print('🖼️ ===== ИЗОБРАЖЕНИЯ В ОТВЕТЕ API =====');
          images.forEach((key, value) {
            if (value != null && value.toString().isNotEmpty) {
              print('  $key: $value');
              
              // Проверяем доступность изображения сразу после получения ответа
              if (value.toString().startsWith('http')) {
                print('  🔍 Проверяем доступность $key...');
                _checkImageImmediately(value.toString(), key);
              }
            } else {
              print('  $key: ПУСТОЕ');
            }
          });
          print('🖼️ ===== КОНЕЦ СПИСКА ИЗОБРАЖЕНИЙ =====');
        } else {
          print('⚠️ Изображения отсутствуют в ответе!');
        }
        
        // Для отладки логируем полный ответ JSON
        print('==== ПОЛНЫЙ ОТВЕТ API СКАНИРОВАНИЯ ====');
        print(response.body);
        print('==== КОНЕЦ ПОЛНОГО ОТВЕТА ====');
        
        // Проверяем наличие scan_id в ответе
        print('==== ПОИСК SCAN_ID В ОТВЕТЕ API ====');
        print('scan_id в корне: ${jsonResponse.containsKey('scan_id')} = ${jsonResponse['scan_id']}');
        print('scan_id в data: ${jsonResponse['data']?.containsKey('scan_id')} = ${jsonResponse['data']?['scan_id']}');
        print('_id в корне: ${jsonResponse.containsKey('_id')} = ${jsonResponse['_id']}');
        print('_id в data: ${jsonResponse['data']?.containsKey('_id')} = ${jsonResponse['data']?['_id']}');
        print('_id в plant: ${jsonResponse['plant']?.containsKey('_id')} = ${jsonResponse['plant']?['_id']}');
        print('id в корне: ${jsonResponse.containsKey('id')} = ${jsonResponse['id']}');
        print('id в data: ${jsonResponse['data']?.containsKey('id')} = ${jsonResponse['data']?['id']}');
        print('has_crop в plant: ${jsonResponse['plant']?.containsKey('has_crop')} = ${jsonResponse['plant']?['has_crop']}');
        print('==== КОНЕЦ ПОИСКА SCAN_ID ====');
        
        print('🎉 ===== СКАНИРОВАНИЕ ЗАВЕРШЕНО УСПЕШНО =====');
        return jsonResponse;
      } else {
        print('❌ Ошибочный статус ответа: ${response.statusCode}');
        print('📄 Тело ответа: ${response.body}');
        
        // Обрабатываем ошибки
        try {
          final jsonResponse = json.decode(response.body);
          final errorMessage = jsonResponse['message'] ?? 'Неизвестная ошибка';
          final errorDetails = jsonResponse['error'] ?? jsonResponse['details'];
          
          print('❌ Сообщение об ошибке: $errorMessage');
          print('📋 Детали ошибки: $errorDetails');
          AppLogger.error('Ошибка API: $errorMessage (${response.statusCode})');
          
          // Логируем полную ошибку для диагностики
          print('🔍 Полная структура ошибки:');
          print('  success: ${jsonResponse['success']}');
          print('  message: $errorMessage');
          print('  error: $errorDetails');
          
          // Обработка по статус-коду
          switch (response.statusCode) {
            case 400:
              throw BadRequestException(errorMessage);
            case 401:
            case 403:
              throw UnauthorizedException(errorMessage);
            case 404:
              throw NotFoundException(errorMessage);
            case 413:
              throw BadRequestException('Файл слишком большой. Выберите изображение меньшего размера.');
            case 500:
              // Для 500 ошибок проверяем, это проблема распознавания или сервера
              if (errorMessage.contains('Ошибка при анализе растения') || 
                  errorMessage.contains('Plant identification failed') ||
                  errorMessage.contains('API key') ||
                  errorMessage.contains('quota')) {
                print('⚠️ Проблема с API распознавания растений на сервере');
                throw ServerException('Не удалось распознать растение. Попробуйте:\n• Сфотографировать растение крупнее\n• Улучшить освещение\n• Выбрать другое фото');
              }
              throw ServerException(errorMessage);
            default:
              throw ServerException(errorMessage);
          }
        } catch (e) {
          if (e is ApiException) rethrow;
          print('❌ Не удалось разобрать ответ об ошибке: $e');
          throw ServerException('Сервер вернул ошибку (${response.statusCode}). Попробуйте позже.');
        }
      }
    } on SocketException catch (e) {
      print('❌ Ошибка сети: $e');
      AppLogger.error('Нет соединения с интернетом');
      throw NoInternetException('Нет соединения с интернетом. Проверьте подключение и попробуйте снова.');
    } on TimeoutException catch (e) {
      print('⏰ Тайм-аут: $e');
      AppLogger.error('Тайм-аут запроса сканирования');
      throw ApiTimeoutException('Время обработки истекло. Нейросеть может быть перегружена. Попробуйте позже.');
    } catch (e) {
      // Если это уже ApiException, просто пробрасываем дальше
      if (e is ApiException) {
        print('💥 ApiException перехвачен: ${e.message}');
        rethrow;
      }
      
      print('💥 Критическая ошибка: $e');
      print('💥 Тип ошибки: ${e.runtimeType}');
      AppLogger.error('Неизвестная ошибка сканирования', e);
      
      // Более детальная обработка различных типов ошибок
      if (e.toString().contains('FormatException') || e.toString().contains('JSON')) {
        throw ServerException('Сервер вернул некорректный ответ. Попробуйте позже.');
      }
      
      throw UnknownApiException('Произошла ошибка при сканировании: $e');
    }
  }
  
  // Вспомогательный метод для немедленной проверки доступности изображения
  void _checkImageImmediately(String imageUrl, String imageKey) async {
    try {
      print('    🔍 Проверяем $imageKey: $imageUrl');
      final response = await http.head(Uri.parse(imageUrl)).timeout(Duration(seconds: 3));
      if (response.statusCode == 200) {
        print('    ✅ $imageKey ДОСТУПНО сразу (${response.statusCode})');
      } else {
        print('    ⚠️ $imageKey НЕДОСТУПНО сразу (${response.statusCode})');
      }
    } catch (e) {
      print('    ❌ Ошибка проверки $imageKey: $e');
    }
  }
  
  // Метод для получения истории сканирований
  Future<List<dynamic>> getScanHistory(String token) async {
    try {
      AppLogger.api('Запрос истории сканирований');
      AppLogger.api('Токен авторизации: ${token.isEmpty ? "ПУСТОЙ!" : "Длина ${token.length}"}');
      
      // Строим URL запроса
      final apiUrl = '${ScanService.baseUrl}/scan/history';
      AppLogger.api('URL запроса: $apiUrl');
      
      // Создаем заголовки с токеном авторизации
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token'
      };
      AppLogger.api('Заголовки запроса: ${headers.toString().replaceAll(token, "токен длиной ${token.length}")}');
      
      // Отправляем запрос напрямую, без использования _apiClient
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: headers,
      ).timeout(Duration(seconds: 20));
      
      AppLogger.api('Получен ответ от сервера: ${response.statusCode}');
      
      // Печатаем полное тело ответа для отладки
      print('==== ПОЛНЫЙ ОТВЕТ ИСТОРИИ СКАНИРОВАНИЙ ====');
      print(response.body);
      print('==== КОНЕЦ ПОЛНОГО ОТВЕТА ====');
      
      // Проверяем и обрабатываем ответ
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        
        // Печатаем структуру ответа для отладки
        print('Структура ответа:');
        print('success: ${jsonResponse['success']}');
        print('message: ${jsonResponse['message']}');
        print('data present: ${jsonResponse.containsKey('data')}');
        if (jsonResponse.containsKey('data')) {
          print('data null?: ${jsonResponse['data'] == null}');
          if (jsonResponse['data'] != null) {
            print('history present: ${jsonResponse['data'].containsKey('history')}');
            if (jsonResponse['data'].containsKey('history')) {
              print('history null?: ${jsonResponse['data']['history'] == null}');
              print('history length: ${jsonResponse['data']['history'] is List ? jsonResponse['data']['history'].length : 'не список'}');
            }
          }
        }
        
        if (jsonResponse['success'] == true) {
          final history = jsonResponse['data'] != null && jsonResponse['data']['history'] != null 
              ? jsonResponse['data']['history'] 
              : [];
          AppLogger.api('Получена история сканирований: ${history.length} элементов');
          
          // Логируем первый элемент для понимания структуры
          if (history.isNotEmpty) {
            print('Пример элемента истории:');
            print(json.encode(history[0]));
            
            // Проверяем на наличие необходимых полей
            final firstItem = history[0];
            print('plant_info present: ${firstItem.containsKey('plant_info')}');
            if (firstItem.containsKey('plant_info') && firstItem['plant_info'] != null) {
              final plantInfo = firstItem['plant_info'];
              print('plant_info.name: ${plantInfo['name']}');
              print('plant_info.images present: ${plantInfo.containsKey('images')}');
              if (plantInfo.containsKey('images') && plantInfo['images'] != null) {
                print('plant_info.images.thumbnail: ${plantInfo['images']['thumbnail']}');
              }
              print('plant_info.tags present: ${plantInfo.containsKey('tags')}');
              if (plantInfo.containsKey('tags') && plantInfo['tags'] != null) {
                print('plant_info.tags length: ${plantInfo['tags'].length}');
              }
            }
          }
          
          return history;
        } else {
          final errorMessage = jsonResponse['message'] ?? 'Не удалось получить историю сканирований';
          AppLogger.error('Ошибка API: $errorMessage');
          throw ServerException(errorMessage);
        }
      } else {
        // Обрабатываем ошибки
        try {
          final jsonResponse = json.decode(response.body);
          final errorMessage = jsonResponse['message'] ?? 'Неизвестная ошибка';
          AppLogger.error('Ошибка API: $errorMessage (${response.statusCode})');
          throw ServerException(errorMessage);
        } catch (e) {
          AppLogger.error('Ошибка при разборе ответа сервера: $e');
          throw ServerException('Не удалось получить историю сканирований. Код: ${response.statusCode}');
        }
      }
    } catch (e) {
      AppLogger.error('Ошибка при получении истории сканирований', e);
      rethrow;
    }
  }
  
  // Метод для получения коллекции растений пользователя
  Future<List<dynamic>> getUserPlantCollection(String token) async {
    try {
      print('🌿 === API ЗАПРОС КОЛЛЕКЦИИ РАСТЕНИЙ ===');
      AppLogger.api('Запрос коллекции растений пользователя');
      
      final apiUrl = '${ScanService.baseUrl}/plants';
      print('🌐 URL: $apiUrl');
      
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token'
      };
      print('📋 Заголовки: ${headers.toString().replaceAll(token, "токен длиной ${token.length}")}');
      
      print('⏳ Отправляем GET запрос...');
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: headers,
      ).timeout(Duration(seconds: 20));
      
      print('📨 Получен ответ: ${response.statusCode}');
      print('📄 Тело ответа: ${response.body}');
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        print('✅ JSON разобран успешно');
        print('🔍 Success: ${jsonResponse['success']}');
        
        if (jsonResponse['success'] == true) {
          final data = jsonResponse['data'] ?? [];
          print('📦 Данные растений: ${data.length} элементов');
          if (data.isNotEmpty) {
            print('📝 === ПЕРВОЕ РАСТЕНИЕ ПОЛНАЯ СТРУКТУРА ===');
            try {
              final first = data[0] as Map<String, dynamic>;
              print('   🔑 Ключи верхнего уровня: ${first.keys.join(", ")}');
              print('   🆔 id: ${first['id']}');
              print('   🆔 _id: ${first['_id']}');
              print('   🆔 scan_id: ${first['scan_id']}');
              print('   🌱 name: ${first['name']}');
              print('   📝 Полный объект: $first');
            } catch (e) {
              print('   ⚠️ Ошибка парсинга: $e');
            }
            print('📝 === КОНЕЦ СТРУКТУРЫ ===');
          }
          print('🌿 === КОНЕЦ API ЗАПРОСА (УСПЕХ) ===');
          return data;
        } else {
          final errorMsg = jsonResponse['message'] ?? 'Неизвестная ошибка';
          print('❌ API вернул ошибку: $errorMsg');
          AppLogger.error('Ошибка API: $errorMsg');
          print('🌿 === КОНЕЦ API ЗАПРОСА (ОШИБКА API) ===');
          return [];
        }
      } else {
        print('❌ HTTP ошибка: ${response.statusCode}');
        print('📄 Тело ошибки: ${response.body}');
        AppLogger.error('Ошибка получения коллекции: ${response.statusCode}');
        print('🌿 === КОНЕЦ API ЗАПРОСА (HTTP ОШИБКА) ===');
        return [];
      }
    } catch (e) {
      print('💥 ИСКЛЮЧЕНИЕ при запросе коллекции: $e');
      AppLogger.error('Ошибка при получении коллекции растений', e);
      print('🌿 === КОНЕЦ API ЗАПРОСА (ИСКЛЮЧЕНИЕ) ===');
      return [];
    }
  }

  // Метод для проверки есть ли растение в коллекции по scan_id (более точный)
  Future<bool> isPlantInCollectionByScanId(String scanId, String token) async {
    try {
      print('🔍 === ПРОВЕРКА РАСТЕНИЯ В КОЛЛЕКЦИИ ПО SCAN_ID ===');
      print('🆔 Ищем растение с scanId: "$scanId"');
      
      final collection = await getUserPlantCollection(token);
      
      // Ищем растение по scan_id
      for (var plant in collection) {
        final plantScanId = plant['scan_id']?.toString() ?? '';
        if (plantScanId == scanId && scanId.isNotEmpty) {
          print('✅ Растение найдено в коллекции по scan_id: $scanId');
          return true;
        }
      }
      
      print('❌ Растение с scan_id "$scanId" НЕ найдено в коллекции');
      return false;
    } catch (e) {
      print('💥 Ошибка при проверке растения по scan_id: $e');
      AppLogger.error('Ошибка при проверке растения в коллекции по scan_id', e);
      return false; // В случае ошибки считаем что растения нет
    }
  }

  // Метод для проверки есть ли растение в коллекции (обновленная версия)
  Future<bool> isPlantInCollection(String plantName, String token, {String? scanId}) async {
    try {
      print('🔍 === ПРОВЕРКА РАСТЕНИЯ В КОЛЛЕКЦИИ ===');
      print('🌱 Имя растения: "$plantName"');
      print('🆔 ScanId: "${scanId ?? "НЕТ"}"');
      
      final collection = await getUserPlantCollection(token);
      print('📊 Коллекция содержит ${collection.length} растений');
      
      // Показываем все scan_id в коллекции для отладки
      for (int i = 0; i < collection.length; i++) {
        final plant = collection[i];
        final plantScanId = plant['scan_id']?.toString() ?? 'НЕТ_ID';
        final plantName_inCollection = plant['name']?.toString() ?? 'Нет названия';
        print('📋 Растение $i: "$plantName_inCollection" - scan_id: "$plantScanId"');
      }
      
      // ПРИОРИТЕТ 1: Если есть scanId, сначала ищем по нему (точное совпадение)
      if (scanId != null && scanId.isNotEmpty) {
        for (var plant in collection) {
          final plantScanId = plant['scan_id']?.toString() ?? '';
          if (plantScanId == scanId) {
            print('✅ Растение найдено в коллекции по ТОЧНОМУ scan_id: $scanId');
            return true;
          }
        }
      }
      
      // ПРИОРИТЕТ 2: Ищем по имени только если не нашли по scan_id
      for (var plant in collection) {
        if (plant['name'] != null && 
            plant['name'].toString().toLowerCase() == plantName.toLowerCase()) {
          // ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА: если есть scanId и он не совпадает, считаем что это другое растение
          if (scanId != null && scanId.isNotEmpty) {
            final plantScanId = plant['scan_id']?.toString() ?? '';
            if (plantScanId.isNotEmpty && plantScanId != scanId) {
              print('⚠️ Найдено растение с таким же именем, но другим scan_id. Пропускаем.');
              continue;
            }
          }
          print('✅ Растение найдено в коллекции по ИМЕНИ: $plantName');
          return true;
        }
        // Также проверяем латинское название если есть
        if (plant['latin_name'] != null && 
            plant['latin_name'].toString().toLowerCase() == plantName.toLowerCase()) {
          // ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА: если есть scanId и он не совпадает, считаем что это другое растение
          if (scanId != null && scanId.isNotEmpty) {
            final plantScanId = plant['scan_id']?.toString() ?? '';
            if (plantScanId.isNotEmpty && plantScanId != scanId) {
              print('⚠️ Найдено растение с таким же латинским именем, но другим scan_id. Пропускаем.');
              continue;
            }
          }
          print('✅ Растение найдено в коллекции по ЛАТИНСКОМУ ИМЕНИ: $plantName');
          return true;
        }
      }
      
      print('❌ Растение НЕ найдено в коллекции');
      return false;
    } catch (e) {
      print('💥 Ошибка при проверке растения в коллекции: $e');
      AppLogger.error('Ошибка при проверке растения в коллекции', e);
      return false; // В случае ошибки считаем что растения нет
    }
  }

  // Метод для добавления растения в коллекцию пользователя
  Future<Map<String, dynamic>> addPlantToCollection(String scanId, String token, [PlantInfo? plantData]) async {
    try {
      print('==== ScanService.addPlantToCollection ====');
      print('Добавление растения в коллекцию. ScanID: $scanId');
      print('Токен авторизации: ${token.isEmpty ? "ПУСТОЙ!" : "Длина ${token.length}"}');
      
      // Убедимся, что токен имеет правильный формат
      if (!token.startsWith('Bearer ') && token.isNotEmpty) {
        token = 'Bearer $token';
        print('Токен модифицирован: Bearer добавлен');
      }
      
      // НОВАЯ ПРОВЕРКА: Проверяем, есть ли растение уже в коллекции
      if (scanId.isNotEmpty) {
        print('🔍 Проверяем существует ли растение с scan_id: $scanId в коллекции...');
        bool alreadyExists = await isPlantInCollectionByScanId(scanId, token);
        if (alreadyExists) {
          print('⚠️ Растение уже существует в коллекции! Пропускаем добавление.');
          return {
            'success': false,
            'message': 'Растение уже есть в вашей коллекции',
            'already_exists': true
          };
        }
        print('✅ Растение не найдено в коллекции, продолжаем добавление');
      } else if (plantData != null) {
        // Если нет scanId, но есть plantData, проверяем по имени
        print('🔍 Проверяем существует ли растение по имени: ${plantData.name}...');
        bool alreadyExists = await isPlantInCollection(plantData.name, token);
        if (alreadyExists) {
          print('⚠️ Растение уже существует в коллекции! Пропускаем добавление.');
          return {
            'success': false,
            'message': 'Растение уже есть в вашей коллекции',
            'already_exists': true
          };
        }
        print('✅ Растение не найдено в коллекции, продолжаем добавление');
      }
      
      // URL запроса
      final apiUrl = '${ScanService.baseUrl}/plants';
      print('URL запроса: $apiUrl');
      
      // Создаем данные запроса
      Map<String, dynamic> requestData;
      
      if (plantData != null) {
        // Отправляем полные данные растения
        requestData = {
          'name': plantData.name,
          'latin_name': plantData.latinName,
          'description': plantData.description,
          'care_info': plantData.careInfo,
          'pests_and_diseases': plantData.pestsAndDiseases,
          'images': plantData.images,
          'tags': plantData.tags,
          'is_healthy': plantData.isHealthy
        };
        
        // Добавляем scan_id только если он не пустой
        if (scanId.isNotEmpty) {
          requestData['scan_id'] = scanId;
          print('Отправляем полные данные растения с scan_id');
        } else {
          print('Отправляем полные данные растения без scan_id');
        }
      } else {
        // Отправляем только scan_id (старый способ)
        requestData = {
          'scan_id': scanId
        };
        print('Отправляем только scan_id');
      }
      
      print('Данные запроса: $requestData');
      
      // Заголовки запроса
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': token
      };
      print('Заголовки запроса: ${headers.toString().replaceAll(token, token.isNotEmpty ? "токен длиной ${token.length}" : "пустой токен")}');
      
      // Отправляем запрос
      print('Отправка POST запроса...');
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: json.encode(requestData)
      ).timeout(Duration(seconds: 20));
      
      print('Получен ответ от сервера: ${response.statusCode}');
      print('Тело ответа: ${response.body}');
      
      // Проверяем и обрабатываем ответ
      final jsonResponse = json.decode(response.body);
      print('Успех? ${jsonResponse['success']}');
      
      if (jsonResponse['success'] == true) {
        print('Растение успешно добавлено в коллекцию');
        
        // Отправляем событие об обновлении коллекции
        PlantEvents().notifyUpdate();
      } else {
        print('Ошибка: ${jsonResponse['message']}');
      }
      
      print('==== Конец ScanService.addPlantToCollection ====');
      return jsonResponse;
    } catch (e) {
      print('КРИТИЧЕСКАЯ ОШИБКА в ScanService.addPlantToCollection: $e');
      AppLogger.error('Ошибка при добавлении растения в коллекцию', e);
      
      // В случае ошибки возвращаем стандартный ответ с ошибкой
      return {
        'success': false,
        'message': 'Ошибка при добавлении растения: $e'
      };
    }
  }

  // Найти растение в коллекции по имени
  Future<String?> findPlantIdInCollection(String plantName, String token) async {
    try {
      AppLogger.api('🔍 === ПОИСК РАСТЕНИЯ В КОЛЛЕКЦИИ ПО ИМЕНИ ===');
      AppLogger.api('🌱 Ищем растение с именем: "$plantName"');
      
      final url = '${ScanService.baseUrl}/plants';
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      
      AppLogger.api('🌐 URL запроса: $url');
      AppLogger.api('⏳ Отправляем GET запрос...');
      
      final response = await http.get(Uri.parse(url), headers: headers);
      
      AppLogger.api('📨 Получен ответ: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['success'] == true && responseData['data'] != null) {
          final plants = responseData['data'] as List;
          
          AppLogger.api('📦 Найдено растений в коллекции: ${plants.length}');
          
          for (final plant in plants) {
            final name = plant['name']?.toString() ?? '';
            final latinName = plant['latin_name']?.toString() ?? '';
            
            if (name.toLowerCase().trim() == plantName.toLowerCase().trim() ||
                latinName.toLowerCase().trim() == plantName.toLowerCase().trim()) {
              
              final plantId = plant['id']?.toString() ?? plant['_id']?.toString();
              if (plantId != null) {
                AppLogger.api('✅ Найдено растение в коллекции с ID: $plantId');
                AppLogger.api('🔍 === КОНЕЦ ПОИСКА (УСПЕХ) ===');
                return plantId;
              }
            }
          }
          
          AppLogger.api('❌ Растение "$plantName" не найдено в коллекции');
          return null;
        }
      }
      
      AppLogger.api('❌ Ошибка поиска растения: ${response.statusCode}');
      return null;
    } catch (e) {
      AppLogger.error('Ошибка поиска растения в коллекции: $e');
      return null;
    }
  }

  Future<bool> removePlantFromCollection(String plantId, String token, {String? scanId}) async {
    try {
      print('🗑️ === УДАЛЕНИЕ РАСТЕНИЯ ИЗ КОЛЛЕКЦИИ ===');
      print('🆔 ID растения: $plantId');
      
      final apiUrl = '${ScanService.baseUrl}/plants/$plantId';
      print('🌐 URL: $apiUrl');
      
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      print('⏳ Отправляем DELETE запрос...');
      final response = await http.delete(
        Uri.parse(apiUrl),
        headers: headers,
      ).timeout(Duration(seconds: 20));
      
      print('📨 Получен ответ: ${response.statusCode}');
      print('📄 Тело ответа: ${response.body}');
      
      // Считаем успешным любой 2xx ответ (включая 204 No Content)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        bool success = true; // по умолчанию успех при 2xx
        if (response.body.isNotEmpty) {
          try {
            final jsonResponse = json.decode(response.body);
            if (jsonResponse is Map<String, dynamic> && jsonResponse.containsKey('success')) {
              final s = jsonResponse['success'];
              success = (s == true || s == 1 || s == 'true' || s == 'ok' || s == 'success');
            }
          } catch (e) {
            // Тело не JSON — это нормально для 204/обычных delete
            print('⚠️ Тело ответа не JSON. Статус ${response.statusCode}. Считаем удаление успешным.');
            success = true;
          }
        } else {
          print('ℹ️ Пустое тело ответа при статусе ${response.statusCode} — считаем удаление успешным.');
          success = true;
        }
        
        if (success) {
          print('✅ Растение успешно удалено из коллекции (код ${response.statusCode})');
          PlantEvents().notifyUpdate();
          return true;
        }
      }
      
      // Если неуспех, пробуем альтернативные методы и эндпоинты
      if (response.statusCode == 404) {
        print('🔁 404 по основному эндпоинту. Пробуем альтернативные методы...');
        
        // 1) Попробуем другие варианты DELETE URL
        final deleteCandidates = <String>[
          '${ScanService.baseUrl}/user/plants/$plantId',
          '${ScanService.baseUrl}/collection/plants/$plantId',
          '${ScanService.baseUrl}/my-plants/$plantId',
          '${ScanService.baseUrl}/plant/$plantId',
        ];
        
        if (scanId != null && scanId.isNotEmpty) {
          deleteCandidates.addAll([
            '${ScanService.baseUrl}/plants/by-scan/$scanId',
            '${ScanService.baseUrl}/user/plants/by-scan/$scanId',
          ]);
        }
        
        for (final url in deleteCandidates) {
          try {
            print('🔁 DELETE $url');
            final r = await http.delete(Uri.parse(url), headers: headers).timeout(Duration(seconds: 20));
            print('🔁 ↩️ статус: ${r.statusCode}, body: ${r.body}');
            if (r.statusCode >= 200 && r.statusCode < 300) {
              print('✅ Растение удалено по альтернативному DELETE (код ${r.statusCode})');
              PlantEvents().notifyUpdate();
              return true;
            }
          } catch (e) {
            print('⚠️ Ошибка DELETE $url: $e');
          }
        }
        
        // 2) Попробуем PATCH с is_deleted или archived
        final patchCandidates = <Map<String, dynamic>>[
          {'url': '${ScanService.baseUrl}/plants/$plantId', 'body': {'is_deleted': true}},
          {'url': '${ScanService.baseUrl}/plants/$plantId', 'body': {'archived': true}},
          {'url': '${ScanService.baseUrl}/plants/$plantId', 'body': {'status': 'deleted'}},
        ];
        
        for (final attempt in patchCandidates) {
          try {
            final url = attempt['url'] as String;
            final body = attempt['body'] as Map<String, dynamic>;
            print('🔁 PATCH $url with body: $body');
            final r = await http.patch(
              Uri.parse(url),
              headers: headers,
              body: json.encode(body),
            ).timeout(Duration(seconds: 20));
            print('🔁 ↩️ статус: ${r.statusCode}, body: ${r.body}');
            if (r.statusCode >= 200 && r.statusCode < 300) {
              print('✅ Растение помечено как удалённое через PATCH (код ${r.statusCode})');
              PlantEvents().notifyUpdate();
              return true;
            }
          } catch (e) {
            print('⚠️ Ошибка PATCH: $e');
          }
        }
      }

      print('❌ Ошибка удаления растения: ${response.statusCode}');
      return false;
    } catch (e) {
      print('💥 Исключение при удалении растения: $e');
      AppLogger.error('Ошибка при удалении растения из коллекции', e);
      return false;
    }
  }

}
