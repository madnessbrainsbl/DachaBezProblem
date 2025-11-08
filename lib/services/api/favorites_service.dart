import 'dart:convert';
import 'package:http/http.dart' as http;
import '../logger.dart';
import '../plant_events.dart';

class FavoritesService {
  static const String baseUrl = 'http://89.110.92.227:3002/api';
  
  // НОВОЕ: Кэш для статуса избранного
  static final Map<String, Map<String, dynamic>> _favoriteStatusCache = {};
  
  // НОВОЕ: Очистка кэша
  static void clearCache() {
    _favoriteStatusCache.clear();
    AppLogger.api('🗑️ Кэш избранного очищен');
  }
  
  // НОВОЕ: Обновление кэша
  static void updateCache(String plantId, bool isFavorite, String? favoriteId) {
    _favoriteStatusCache[plantId] = {
      'isFavorite': isFavorite,
      'favoriteId': favoriteId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    AppLogger.api('💾 Кэш обновлен для plantId: $plantId, isFavorite: $isFavorite');
  }
  
  // НОВОЕ: Получение из кэша
  static Map<String, dynamic>? getCachedStatus(String plantId) {
    final cached = _favoriteStatusCache[plantId];
    if (cached != null) {
      final timestamp = cached['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      // Кэш действителен 30 секунд
      if (now - timestamp < 30000) {
        AppLogger.api('📦 Используем кэшированный статус для plantId: $plantId');
        return {
          'isFavorite': cached['isFavorite'],
          'favoriteId': cached['favoriteId'],
        };
      } else {
        // Удаляем устаревший кэш
        _favoriteStatusCache.remove(plantId);
        AppLogger.api('🕒 Кэш устарел для plantId: $plantId, удаляем');
      }
    }
    return null;
  }

  /// Получить все избранные растения пользователя
  Future<List<dynamic>> getFavorites(String token) async {
    try {
      AppLogger.api('Запрос избранных растений');
      
      final response = await http.get(
        Uri.parse('$baseUrl/favorites'),
        headers: {
          'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 20));
      
      AppLogger.api('Ответ избранного: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          return jsonResponse['data'] ?? [];
        } else {
          throw Exception(jsonResponse['message'] ?? 'Не удалось получить избранное');
        }
      } else {
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('Ошибка при получении избранного: $e');
      rethrow;
    }
  }
  
  /// Добавить элемент в избранное
  Future<Map<String, dynamic>> addToFavorites(String token, String plantId) async {
    try {
      AppLogger.api('🎯 === FavoritesService.addToFavorites НАЧАЛО ===');
      print('🎯 === FavoritesService.addToFavorites НАЧАЛО ===');
      AppLogger.api('🎯 PlantId: "$plantId"');
      print('🎯 PlantId: "$plantId"');
      AppLogger.api('🎯 PlantId тип: ${plantId.runtimeType}');
      print('🎯 PlantId тип: ${plantId.runtimeType}');
      AppLogger.api('🎯 Token length: ${token.length}');
      print('🎯 Token length: ${token.length}');
      
      final requestBody = {
        'itemType': 'plant',
        'itemId': plantId,
      };
      
      AppLogger.api('🎯 Request body: $requestBody');
      print('🎯 Request body: $requestBody');
      AppLogger.api('🎯 URL: $baseUrl/favorites');
      print('🎯 URL: $baseUrl/favorites');
      
      final response = await http.post(
        Uri.parse('$baseUrl/favorites'),
        headers: {
          'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: 30));
      
      AppLogger.api('🎯 Response status: ${response.statusCode}');
      print('🎯 Response status: ${response.statusCode}');
      AppLogger.api('🎯 Response body: ${response.body}');
      print('🎯 Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('🎯 HTTP статус успешный');
        AppLogger.api('✅ HTTP статус успешный');
        
        final jsonResponse = json.decode(response.body);
        print('🎯 Parsed JSON: $jsonResponse');
        print('🎯 Success field: ${jsonResponse['success']}');
        print('🎯 Data field: ${jsonResponse['data']}');
        
        AppLogger.api('📊 Parsed JSON: $jsonResponse');
        AppLogger.api('🔍 Success field: ${jsonResponse['success']}');
        AppLogger.api('📊 Data field: ${jsonResponse['data']}');
        
        if (jsonResponse['success'] == true) {
          AppLogger.api('🎉 === addToFavorites УСПЕШНО ЗАВЕРШЕН ===');
          
          // Обновляем кэш
          final favoriteId = jsonResponse['data']?['_id']?.toString() ?? jsonResponse['data']?['id']?.toString();
          updateCache(plantId, true, favoriteId);
          
          // Отправляем событие об обновлении коллекции
          PlantEvents().notifyUpdate();
          
          return {
            'success': true,
            'data': jsonResponse['data']
          };
        } else {
          AppLogger.api('❌ Server returned success=false: ${jsonResponse['message']}');
          throw Exception(jsonResponse['message'] ?? 'Не удалось добавить в избранное');
        }
      } else if (response.statusCode == 400) {
        AppLogger.api('⚠️ HTTP 400 - Возможно растение уже в избранном');
        final jsonResponse = json.decode(response.body);
        AppLogger.api('📄 400 response: $jsonResponse');
        
        // Проверяем если это "уже в избранном" - это НЕ ошибка!
        if (jsonResponse['message']?.toString().toLowerCase().contains('уже в избранном') == true) {
          AppLogger.api('✅ Растение уже в избранном - получаем favoriteId из кэша');
          
          // Простое решение: очищаем кэш и проверяем заново
          clearCache();
          final checkResult = await checkIsFavorite(token, plantId);
          
          if (checkResult['isFavorite'] == true && checkResult['favoriteId'] != null) {
            AppLogger.api('✅ Получен favoriteId: ${checkResult['favoriteId']}');
            return {
              'success': true,
              'data': {
                '_id': checkResult['favoriteId'],
                'user': 'current_user',
                'itemType': 'plant',
                'itemId': plantId,
                'message': 'Растение уже в избранном'
              }
            };
          }
        }
        
        // Если это другая ошибка 400, выбрасываем исключение
        throw Exception(jsonResponse['message'] ?? 'Ошибка добавления в избранное');
      } else {
        AppLogger.api('❌ HTTP Error: ${response.statusCode}');
        AppLogger.api('📄 Error body: ${response.body}');
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      AppLogger.error('💥 === ОШИБКА в addToFavorites ===');
      AppLogger.error('❌ Error: $e');
      AppLogger.error('📍 StackTrace: $stackTrace');
      rethrow;
    }
  }
  
  /// Проверить находится ли растение в избранном
  Future<Map<String, dynamic>> checkIsFavorite(String token, String plantId) async {
    try {
      // ОТЛАДКА: Проверяем кэш с логированием
      final cached = getCachedStatus(plantId);
      AppLogger.api('🧠 === ПРОВЕРКА КЭША ===');
      AppLogger.api('🆔 PlantId: $plantId');
      AppLogger.api('💾 Кэш найден: ${cached != null}');
      if (cached != null) {
        AppLogger.api('💾 Данные кэша: $cached');
        AppLogger.api('💾 isFavorite: ${cached['isFavorite']}');
        AppLogger.api('💾 favoriteId: ${cached['favoriteId']}');
        
        // ВРЕМЕННО: Игнорируем кэш если favoriteId отсутствует
        if (cached['isFavorite'] == true && cached['favoriteId'] == null) {
          AppLogger.api('⚠️ В кэше isFavorite=true но favoriteId=null, игнорируем кэш');
        } else {
          AppLogger.api('✅ Возвращаем данные из кэша');
          return cached;
        }
      }
      
      AppLogger.api('🌐 === HTTP ЗАПРОС /favorites/check ===');
      AppLogger.api('🆔 PlantId: $plantId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/favorites/check?itemType=plant&itemId=$plantId'),
        headers: {
          'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 20));
      
      AppLogger.api('📊 HTTP ответ: ${response.statusCode}');
      AppLogger.api('📄 Тело ответа: ${response.body}');
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        AppLogger.api('📊 Parsed JSON: $jsonResponse');
        
        if (jsonResponse['success'] == true) {
          final result = {
            'isFavorite': jsonResponse['isFavorite'] ?? false,
            'favoriteId': jsonResponse['favoriteId'],
          };
          
          AppLogger.api('✅ Итоговый результат: $result');
          
          // Сохраняем в кэш
          updateCache(plantId, result['isFavorite'], result['favoriteId']);
          AppLogger.api('💾 Результат сохранен в кэш');
          
          return result;
        } else {
          throw Exception(jsonResponse['message'] ?? 'Не удалось проверить избранное');
        }
      } else {
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('💥 Ошибка при проверке избранного: $e');
      return {'isFavorite': false, 'favoriteId': null};
    }
  }
  
  /// Удалить из избранного
  Future<bool> removeFromFavorites(String token, String favoriteId) async {
    try {
      print('🗑️ === FavoritesService.removeFromFavorites НАЧАЛО ===');
      print('🗑️ FavoriteId: $favoriteId');
      print('🗑️ Token length: ${token.length}');
      
      AppLogger.api('🗑️ === FavoritesService.removeFromFavorites НАЧАЛО ===');
      AppLogger.api('🗑️ FavoriteId: $favoriteId');
      AppLogger.api('🗑️ Token length: ${token.length}');
      AppLogger.api('🌐 URL: $baseUrl/favorites/$favoriteId');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/favorites/$favoriteId'),
        headers: {
          'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 20));
      
      print('🗑️ Response status: ${response.statusCode}');
      print('🗑️ Response body: ${response.body}');
      
      AppLogger.api('🗑️ Response status: ${response.statusCode}');
      AppLogger.api('🗑️ Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final success = jsonResponse['success'] == true;
        
        print('🗑️ Parsed success: $success');
        AppLogger.api('🗑️ Parsed success: $success');
        
        if (success) {
          print('🗑️ Обновляем кэш...');
          // НОВОЕ: Обновляем кэш - находим plantId по favoriteId и обновляем
          _favoriteStatusCache.forEach((plantId, data) {
            if (data['favoriteId'] == favoriteId) {
              print('🗑️ Найден plantId для обновления кэша: $plantId');
              updateCache(plantId, false, null);
            }
          });
          
          // НЕ отправляем событие - удаление лайка не влияет на коллекцию растений
        }
        
        print('🗑️ === removeFromFavorites ЗАВЕРШЕН УСПЕШНО ===');
        return success;
      } else if (response.statusCode == 404) {
        // Элемент не найден - считаем что успешно удален
        print('🗑️ 404 - элемент не найден, считаем успешно удаленным');
        return true;
      } else {
        print('🗑️ Ошибка HTTP: ${response.statusCode}');
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('🗑️ КРИТИЧЕСКАЯ ОШИБКА: $e');
      print('🗑️ StackTrace: $stackTrace');
      AppLogger.error('💥 === ОШИБКА в removeFromFavorites ===');
      AppLogger.error('❌ Error: $e');
      AppLogger.error('📍 StackTrace: $stackTrace');
      rethrow;
    }
  }
} 