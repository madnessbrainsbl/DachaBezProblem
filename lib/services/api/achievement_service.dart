import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/achievement.dart';
import '../logger.dart';
import '../../config/api_config.dart';

class AchievementService {
  static String get baseUrl => ApiConfig.baseUrl;

  // Получение достижений пользователя
  static Future<List<Achievement>> getUserAchievements(String token) async {
    try {
      AppLogger.api('Запрос достижений пользователя');
      
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/achievements'),
        headers: headers,
      ).timeout(Duration(seconds: 15));

      print('📥 Получен ответ GET /api/achievements: ${response.statusCode}');
      print('📄 Тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔍 Структура ответа getUserAchievements: ${data.keys}');
        print('🔍 Success статус: ${data['success']}');
        
        if (data['success'] == true) {
          if (data['data'] != null && data['data']['achievements'] != null) {
            final achievementsData = data['data']['achievements'] as List;
            print('📊 Количество достижений в ответе: ${achievementsData.length}');
            
            // Логируем первые несколько достижений для анализа
            for (int i = 0; i < achievementsData.length && i < 3; i++) {
              print('📝 Достижение #$i: ${achievementsData[i]}');
            }
            
            final achievements = achievementsData
                .map((item) => Achievement.fromJson(item))
                .toList();
            
            AppLogger.api('✅ Получено ${achievements.length} достижений');
            return achievements;
          } else {
            print('❌ data или achievements поле пустое в ответе');
            return [];
          }
        } else {
          print('❌ Success = false. Сообщение: ${data['message']}');
          AppLogger.error('Ошибка в ответе API: ${data['message']}');
          return [];
        }
      } else {
        print('❌ HTTP ошибка ${response.statusCode}');
        print('❌ Содержимое ошибки: ${response.body}');
        AppLogger.error('Ошибка HTTP: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      AppLogger.error('Ошибка получения достижений: $e');
      return [];
    }
  }

  // Получение шаблонов достижений
  static Future<List<AchievementTemplate>> getAchievementTemplates(String token) async {
    try {
      AppLogger.api('Запрос шаблонов достижений');
      print('🔑 Используемый токен для шаблонов: ${token.substring(0, 20)}...');
      
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
        'Content-Type': 'application/json',
      };
      
      print('📡 Отправляем запрос GET $baseUrl/achievements/templates');
      print('📋 Заголовки: $headers');

      final response = await http.get(
        Uri.parse('$baseUrl/achievements/templates'),
        headers: headers,
      ).timeout(Duration(seconds: 15));

      print('📥 Получен ответ GET /api/achievements/templates: ${response.statusCode}');
      print('📄 Полное тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔍 Структура ответа: ${data.keys}');
        print('🔍 Success статус: ${data['success']}');
        
        if (data['success'] == true) {
          if (data['data'] != null && data['data']['templates'] != null) {
            final templatesData = data['data']['templates'] as List;
            print('📊 Количество шаблонов в ответе: ${templatesData.length}');
            
            // Логируем первые несколько шаблонов для анализа
            for (int i = 0; i < templatesData.length && i < 3; i++) {
              print('📝 Шаблон #$i: ${templatesData[i]}');
            }
            
            final templates = templatesData
                .map((item) => AchievementTemplate.fromJson(item))
                .toList();
            
            AppLogger.api('✅ Получено ${templates.length} шаблонов достижений');
            return templates;
          } else {
            print('❌ data или templates поле пустое в ответе');
            return [];
          }
        } else {
          print('❌ Success = false. Сообщение: ${data['message']}');
          AppLogger.error('Ошибка в ответе API: ${data['message']}');
          return [];
        }
      } else {
        print('❌ HTTP ошибка ${response.statusCode}');
        print('❌ Содержимое ошибки: ${response.body}');
        AppLogger.error('Ошибка HTTP: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Исключение при получении шаблонов: $e');
      AppLogger.error('Ошибка получения шаблонов достижений: $e');
      return [];
    }
  }

  // Получение статистики достижений
  static Future<AchievementStats?> getAchievementStats(String token) async {
    try {
      AppLogger.api('Запрос статистики достижений');
      
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/achievements/stats'),
        headers: headers,
      ).timeout(Duration(seconds: 15));

      print('📥 Получен ответ GET /api/achievements/stats: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final stats = AchievementStats.fromJson(data['data']);
          AppLogger.api('Получена статистика: ${stats.totalAchievements} достижений, ${stats.totalPoints} баллов');
          return stats;
        } else {
          AppLogger.error('Ошибка в ответе API: ${data['message']}');
          return null;
        }
      } else {
        AppLogger.error('Ошибка HTTP: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      AppLogger.error('Ошибка получения статистики достижений: $e');
      return null;
    }
  }

  // НОВЫЙ МЕТОД: Получение прогресса пользователя
  static Future<Map<String, dynamic>?> getUserProgress(String token) async {
    try {
      AppLogger.api('Запрос прогресса пользователя');
      
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/achievements/progress'),
        headers: headers,
      ).timeout(Duration(seconds: 15));

      print('📥 Получен ответ GET /api/achievements/progress: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          AppLogger.api('Получен прогресс пользователя');
          return data['data'];
        } else {
          AppLogger.error('Ошибка в ответе API: ${data['message']}');
          return null;
        }
      } else {
        AppLogger.error('Ошибка HTTP: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      AppLogger.error('Ошибка получения прогресса: $e');
      return null;
    }
  }

  // НОВЫЙ МЕТОД: Проверка достижений после действий
  static Future<List<Achievement>> checkAchievements(
    String token, 
    String action, 
    {Map<String, dynamic>? metadata}
  ) async {
    try {
      AppLogger.api('Проверка достижений для действия: $action');
      
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final requestBody = {
        'action': action,
        if (metadata != null) 'metadata': metadata,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/achievements/check'),
        headers: headers,
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: 15));

      print('📥 Получен ответ POST /api/achievements/check: ${response.statusCode}');
      print('📄 Тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final newAchievements = (data['data']['newAchievements'] as List)
              .map((item) => Achievement.fromJson(item))
              .toList();
          
          AppLogger.api('Получено ${newAchievements.length} новых достижений');
          return newAchievements;
        } else {
          AppLogger.error('Ошибка в ответе API: ${data['message']}');
          return [];
        }
      } else {
        AppLogger.error('Ошибка HTTP: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      AppLogger.error('Ошибка проверки достижений: $e');
      return [];
    }
  }

  // Создание достижения (для ручного начисления)
  static Future<Achievement?> createAchievement(
    String token, 
    String templateId, 
    Map<String, dynamic>? metadata
  ) async {
    try {
      AppLogger.api('Создание достижения с шаблоном: $templateId');
      
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final requestBody = {
        'templateId': templateId,
        if (metadata != null) 'metadata': metadata,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/achievements'),
        headers: headers,
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: 15));

      print('📥 Получен ответ POST /api/achievements: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final achievement = Achievement.fromJson(data['data']);
          AppLogger.api('Создано достижение: ${achievement.name}');
          return achievement;
        } else {
          AppLogger.error('Ошибка в ответе API: ${data['message']}');
          return null;
        }
      } else {
        AppLogger.error('Ошибка HTTP: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      AppLogger.error('Ошибка создания достижения: $e');
      return null;
    }
  }

  // УПРОЩЕННЫЕ МЕТОДЫ для быстрого вызова

  // Проверка достижений за сканирование
  static Future<List<Achievement>> checkScanAchievements(
    String token, 
    {String? plantName, double? confidence, String? scanType}
  ) async {
    final metadata = <String, dynamic>{};
    if (plantName != null) metadata['plantName'] = plantName;
    if (confidence != null) metadata['confidence'] = confidence;
    if (scanType != null) metadata['scanType'] = scanType;
    
    return checkAchievements(token, 'scan', metadata: metadata.isNotEmpty ? metadata : null);
  }

  // Проверка достижений за напоминания
  static Future<List<Achievement>> checkReminderAchievements(
    String token,
    {String? reminderType, String? plantId}
  ) async {
    final metadata = <String, dynamic>{};
    if (reminderType != null) metadata['reminderType'] = reminderType;
    if (plantId != null) metadata['plantId'] = plantId;
    
    return checkAchievements(token, 'reminder', metadata: metadata.isNotEmpty ? metadata : null);
  }

  // Проверка достижений за активность (при входе в приложение)
  static Future<List<Achievement>> checkLoginAchievements(String token) async {
    return checkAchievements(token, 'login');
  }

  // Проверка достижений за чат с ИИ
  static Future<List<Achievement>> checkChatAchievements(
    String token,
    {String? messageType, String? topic}
  ) async {
    final metadata = <String, dynamic>{};
    if (messageType != null) metadata['messageType'] = messageType;
    if (topic != null) metadata['topic'] = topic;
    
    return checkAchievements(token, 'chat', metadata: metadata.isNotEmpty ? metadata : null);
  }

  // Проверка достижений за избранное
  static Future<List<Achievement>> checkFavoriteAchievements(
    String token,
    {String? itemType, String? itemId}
  ) async {
    final metadata = <String, dynamic>{};
    if (itemType != null) metadata['itemType'] = itemType;
    if (itemId != null) metadata['itemId'] = itemId;
    
    return checkAchievements(token, 'favorite', metadata: metadata.isNotEmpty ? metadata : null);
  }
} 