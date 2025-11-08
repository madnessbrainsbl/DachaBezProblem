import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../models/reminder.dart';
import '../logger.dart';
import '../../config/api_config.dart';

// Исключение для случая когда растение не найдено
class PlantNotFoundError implements Exception {
  final String message;
  PlantNotFoundError(this.message);
  
  @override
  String toString() => 'PlantNotFoundError: $message';
}

class ReminderService {
  static String get baseUrl => ApiConfig.baseUrl;

  // Получение списка напоминаний с фильтрацией
  Future<List<Reminder>> getReminders(String token, {
    String? date,           // YYYY-MM-DD
    String? week,           // YYYY-MM-DD
    String? type,           // watering, spraying, etc.
    String? timeOfDay,      // morning, afternoon, evening
    bool? isActive,         // true/false
    String? plantId,        // конкретное растение
  }) async {
    try {
      AppLogger.api('Запрос списка напоминаний');
      
      final queryParams = <String, String>{};
      if (date != null) queryParams['date'] = date;
      if (week != null) queryParams['week'] = week;
      if (type != null) queryParams['type'] = type;
      if (timeOfDay != null) queryParams['timeOfDay'] = timeOfDay;
      if (isActive != null) queryParams['isActive'] = isActive.toString();
      if (plantId != null) queryParams['plantId'] = plantId;

      final uri = Uri.parse('$baseUrl/reminders').replace(queryParameters: queryParams);
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
      };

      final response = await http.get(uri, headers: headers).timeout(Duration(seconds: 20));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        print('🔍 === СЫРОЙ ОТВЕТ API /reminders ===');
        print('📄 Статус: ${response.statusCode}');
        print('📦 Первые 500 символов ответа: ${response.body.length > 500 ? response.body.substring(0, 500) + "..." : response.body}');
        print('✅ Success: ${jsonResponse['success']}');
        
        if (jsonResponse['success'] == true) {
          // Новый единый формат: {"success": true, "data": {"reminders": [...]}}
          final dataMap = jsonResponse['data'] as Map<String, dynamic>? ?? {};
          final List<dynamic> remindersData = dataMap['reminders'] as List<dynamic>? ?? [];
          
          print('📊 Единый формат данных, элементов: ${remindersData.length}');
          print('📈 Дополнительная информация: total=${dataMap['total']}, page=${dataMap['page']}');
          
          if (remindersData.isNotEmpty) {
            print('🧪 Первый элемент: ${remindersData.first}');
          }
          
          try {
            final reminders = remindersData.map((reminderJson) => Reminder.fromJson(reminderJson)).toList();
            print('✅ Успешно распарсили ${reminders.length} напоминаний');
            return reminders;
          } catch (parseError) {
            print('❌ Ошибка парсинга Reminder.fromJson: $parseError');
            AppLogger.error('Ошибка парсинга напоминаний: $parseError');
            return [];
          }
        } else {
          AppLogger.error('Ошибка получения напоминаний: ${jsonResponse['message']}');
          return [];
        }
      } else {
        AppLogger.error('HTTP ошибка при получении напоминаний: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      AppLogger.error('Исключение при получении напоминаний: $e');
      return [];
    }
  }

  // Получение напоминаний со статусом выполнения
  Future<List<Reminder>> getRemindersWithStatus(String token, {
    String? date,
    String timezone = 'Europe/Moscow'
  }) async {
    try {
      AppLogger.api('Запрос напоминаний со статусом выполнения');
      
      final queryParams = <String, String>{
        'timezone': timezone,
      };
      if (date != null) queryParams['date'] = date;

      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/reminders/with-status').replace(queryParameters: queryParams),
        headers: headers,
      ).timeout(Duration(seconds: 20));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        print('🔍 === СЫРОЙ ОТВЕТ API /reminders/with-status ===');
        print('📄 Полный ответ: ${response.body}');
        
        if (jsonResponse['success'] == true) {
          final dataMap = jsonResponse['data'] as Map<String, dynamic>? ?? {};
          final List<dynamic> remindersData = dataMap['reminders'] as List<dynamic>? ?? [];
          print('📋 Напоминания со статусом: ${remindersData.length}');
          print('🌐 Таймзона: ${dataMap['timezone']}, дата: ${dataMap['date']}');
          
          // Подробный вывод каждого напоминания для отладки исключений
          for (int i = 0; i < remindersData.length; i++) {
            final reminderJson = remindersData[i];
            print('🔍 === НАПОМИНАНИЕ #$i ===');
            print('🆔 ID: ${reminderJson['_id']}');
            print('📅 Дата оригинальная: ${reminderJson['date']}');
            print('⏰ Время дня: ${reminderJson['timeOfDay']}');
            print('🔧 Есть исключения: ${reminderJson['exceptions'] != null}');
            print('📝 Исключения: ${reminderJson['exceptions']}');
            print('🎯 Эффективное время: ${reminderJson['effectiveTime']}');
            print('🎯 Эффективная дата: ${reminderJson['effectiveDate']}');
            print('🔍 === КОНЕЦ НАПОМИНАНИЯ #$i ===\n');
          }
          
          return remindersData.map((reminderJson) => Reminder.fromJson(reminderJson)).toList();
        } else {
          AppLogger.error('Ошибка получения напоминаний со статусом: ${jsonResponse['message']}');
          return [];
        }
      } else {
        AppLogger.error('HTTP ошибка при получении напоминаний со статусом: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      AppLogger.error('Исключение при получении напоминаний со статусом: $e');
      return [];
    }
  }

  // Получение сегодняшних напоминаний
  Future<List<Reminder>> getTodayReminders(String token, {String timezone = 'Europe/Moscow'}) async {
    try {
      AppLogger.api('Запрос сегодняшних напоминаний для таймзоны: $timezone');
      
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/reminders/today?timezone=$timezone'),
        headers: headers,
      ).timeout(Duration(seconds: 20));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        print('🔍 === СЫРОЙ ОТВЕТ API /reminders/today ===');
        
        if (jsonResponse['success'] == true) {
          final dataMap = jsonResponse['data'] as Map<String, dynamic>? ?? {};
          final List<dynamic> remindersData = dataMap['reminders'] as List<dynamic>? ?? [];
          print('📅 Сегодняшние напоминания: ${remindersData.length}');
          print('🌐 Таймзона: ${dataMap['timezone']}, дата: ${dataMap['date']}');
          if (dataMap['searchPeriod'] != null) {
            print('🔍 Период поиска: ${dataMap['searchPeriod']}');
          }
          return remindersData.map((reminderJson) => Reminder.fromJson(reminderJson)).toList();
        } else {
          AppLogger.error('Ошибка получения сегодняшних напоминаний: ${jsonResponse['message']}');
          return [];
        }
      } else {
        AppLogger.error('HTTP ошибка при получении сегодняшних напоминаний: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      AppLogger.error('Исключение при получении сегодняшних напоминаний: $e');
      return [];
    }
  }

  // Получение ближайших напоминаний
  Future<List<Reminder>> getUpcomingReminders(String token, {
    int days = 7, 
    String timezone = 'Europe/Moscow',
    bool includeTodayAfterNow = false
  }) async {
    try {
      AppLogger.api('Запрос ближайших напоминаний на $days дней для таймзоны: $timezone');
      
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/reminders/upcoming?days=$days&timezone=$timezone&includeTodayAfterNow=$includeTodayAfterNow'),
        headers: headers,
      ).timeout(Duration(seconds: 20));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        print('🔍 === СЫРОЙ ОТВЕТ API /reminders/upcoming ===');
        
        if (jsonResponse['success'] == true) {
          final dataMap = jsonResponse['data'] as Map<String, dynamic>? ?? {};
          final List<dynamic> remindersData = dataMap['reminders'] as List<dynamic>? ?? [];
          print('📈 Ближайшие напоминания: ${remindersData.length}');
          print('🌐 Таймзона: ${dataMap['timezone']}, исключает сегодня: ${dataMap['excludesToday']}');
          if (dataMap['period'] != null) {
            print('📅 Период: ${dataMap['period']}');
          }
          
          // 🔍 Специальная отладка для isDeletedForDate
          print('🔍 ========================');
          print('🔍 АНАЛИЗ НАПОМИНАНИЙ НА ПРЕДМЕТ УДАЛЕНИЯ');
          print('🔍 ========================');
          var deletedCount = 0;
          for (int i = 0; i < remindersData.length; i++) {
            final reminder = remindersData[i] as Map<String, dynamic>;
            final isDeleted = reminder['isDeletedForDate'];
            if (isDeleted == true) {
              deletedCount++;
              print('🚫 УДАЛЕНО: ${reminder['_id']} для даты ${reminder['date']}');
              print('   Type: ${reminder['type']}, Plant: ${reminder['plant_name']}');
            }
          }
          print('📊 ИТОГО УДАЛЕННЫХ: $deletedCount из ${remindersData.length}');
          print('🔍 ========================');
          print('🔍 КОНЕЦ АНАЛИЗА');
          print('🔍 ========================');
          
          return remindersData.map((reminderJson) => Reminder.fromJson(reminderJson)).toList();
        } else {
          AppLogger.error('Ошибка получения ближайших напоминаний: ${jsonResponse['message']}');
          return [];
        }
      } else {
        AppLogger.error('HTTP ошибка при получении ближайших напоминаний: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      AppLogger.error('Исключение при получении ближайших напоминаний: $e');
      return [];
    }
  }

  // Получение календарных напоминаний по месяцу
  Future<CalendarReminders?> getCalendarReminders(String token, String month) async {
    try {
      AppLogger.api('Запрос календарных напоминаний на месяц: $month');
      
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/reminders/calendar?month=$month'),
        headers: headers,
      ).timeout(Duration(seconds: 20));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          return CalendarReminders.fromJson(jsonResponse['data']);
        } else {
          AppLogger.error('Ошибка получения календарных напоминаний: ${jsonResponse['message']}');
          return null;
        }
      } else {
        AppLogger.error('HTTP ошибка при получении календарных напоминаний: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppLogger.error('Исключение при получении календарных напоминаний: $e');
      return null;
    }
  }

  // Создание нового напоминания
  Future<Reminder?> createReminder(String token, Reminder reminder) async {
    try {
      AppLogger.api('Создание нового напоминания');
      
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final requestBody = json.encode(reminder.toJson());
      print('📤 Отправляем запрос POST /api/reminders');
      print('📦 Тело запроса: $requestBody');
      print('🔑 Заголовки: $headers');

      final response = await http.post(
        Uri.parse('$baseUrl/reminders'),
        headers: headers,
        body: requestBody,
      ).timeout(Duration(seconds: 20));

      print('📥 Получен ответ с кодом: ${response.statusCode}');
      print('📄 Тело ответа: ${response.body}');
      print('📋 Заголовки ответа: ${response.headers}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final jsonResponse = json.decode(response.body);
          print('✅ JSON успешно декодирован: $jsonResponse');
          
          if (jsonResponse['success'] == true) {
            AppLogger.api('Напоминание успешно создано');
            print('🎉 Напоминание создано, данные: ${jsonResponse['data']}');
            // Новый формат: {"success": true, "data": {"reminder": {...}, "message": "..."}}
            final dataMap = jsonResponse['data'] as Map<String, dynamic>;
            final reminderData = dataMap['reminder'] ?? dataMap; // Fallback для старого формата
            return Reminder.fromJson(reminderData);
          } else {
            final errorMessage = jsonResponse['message'] ?? 'Неизвестная ошибка';
            final errorCode = jsonResponse['error_code'];
            print('❌ Бэкенд вернул success=false: $errorMessage');
            print('🏷️ Error code: $errorCode');
            AppLogger.error('Ошибка создания напоминания: $errorMessage (код: $errorCode)');
            
            // Обрабатываем специфичный error_code для лучшего UX
            if (errorCode == 'PLANT_NOT_FOUND') {
              throw PlantNotFoundError(errorMessage);
            }
            
            return null;
          }
        } catch (jsonError) {
          print('❌ Ошибка парсинга JSON ответа: $jsonError');
          print('📄 Сырой ответ: ${response.body}');
          AppLogger.error('Ошибка парсинга ответа: $jsonError');
          return null;
        }
      } else {
        print('❌ Неуспешный HTTP код: ${response.statusCode}');
        AppLogger.error('HTTP ошибка при создании напоминания: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('💥 Исключение при создании напоминания: $e');
      AppLogger.error('Исключение при создании напоминания: $e');
      return null;
    }
  }

  // Обновление напоминания
  Future<Reminder?> updateReminder(String token, String reminderId, Reminder reminder) async {
    try {
      AppLogger.api('Обновление напоминания: $reminderId');
      
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final response = await http.put(
        Uri.parse('$baseUrl/reminders/$reminderId'),
        headers: headers,
        body: json.encode(reminder.toJson()),
      ).timeout(Duration(seconds: 20));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          AppLogger.api('Напоминание успешно обновлено');
          final dataMap = jsonResponse['data'] as Map<String, dynamic>;
          final reminderData = dataMap['reminder'] ?? dataMap;
          return Reminder.fromJson(reminderData);
        } else {
          AppLogger.error('Ошибка обновления напоминания: ${jsonResponse['message']}');
          return null;
        }
      } else {
        AppLogger.error('HTTP ошибка при обновлении напоминания: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppLogger.error('Исключение при обновлении напоминания: $e');
      return null;
    }
  }

  // Переключение активности напоминания
  Future<bool> toggleReminderActive(String token, String reminderId) async {
    try {
      print('🔄 === API: ПЕРЕКЛЮЧЕНИЕ АКТИВНОСТИ ===');
      print('🆔 ID напоминания: $reminderId');
      print('🔗 URL: $baseUrl/reminders/$reminderId/toggle');
      AppLogger.api('Переключение активности напоминания: $reminderId');
      
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
      };

      final response = await http.patch(
        Uri.parse('$baseUrl/reminders/$reminderId/toggle'),
        headers: headers,
      ).timeout(Duration(seconds: 20));

      print('📥 Статус ответа: ${response.statusCode}');
      print('📄 Тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          AppLogger.api('Активность напоминания успешно переключена');
          final dataMap = jsonResponse['data'] as Map<String, dynamic>? ?? {};
          print('✅ Напоминание переключено: ${dataMap['message']}, isActive=${dataMap['isActive']}');
          return true;
        } else {
          print('❌ Сервер вернул success=false: ${jsonResponse['message']}');
          AppLogger.error('Ошибка переключения активности: ${jsonResponse['message']}');
          return false;
        }
      } else {
        print('❌ HTTP ошибка: ${response.statusCode}');
        AppLogger.error('HTTP ошибка при переключении активности: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Исключение: $e');
      AppLogger.error('Исключение при переключении активности: $e');
      return false;
    }
  }

  // Удаление напоминания
  Future<bool> deleteReminder(String token, String reminderId) async {
    try {
      print('🗑️ === API: УДАЛЕНИЕ НАПОМИНАНИЯ ===');
      print('🆔 ID напоминания: $reminderId');
      print('🔗 URL: $baseUrl/reminders/$reminderId');
      AppLogger.api('Удаление напоминания: $reminderId');
      
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
      };

      final response = await http.delete(
        Uri.parse('$baseUrl/reminders/$reminderId'),
        headers: headers,
      ).timeout(Duration(seconds: 20));

      print('📥 Статус ответа: ${response.statusCode}');
      print('📄 Тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          AppLogger.api('Напоминание успешно удалено');
          final dataMap = jsonResponse['data'] as Map<String, dynamic>? ?? {};
          print('✅ Напоминание удалено: ${dataMap['message']}, ID=${dataMap['reminderId']}');
          return true;
        } else {
          print('❌ Сервер вернул success=false: ${jsonResponse['message']}');
          AppLogger.error('Ошибка удаления напоминания: ${jsonResponse['message']}');
          return false;
        }
      } else {
        print('❌ HTTP ошибка: ${response.statusCode}');
        AppLogger.error('HTTP ошибка при удалении напоминания: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Исключение: $e');
      AppLogger.error('Исключение при удалении напоминания: $e');
      return false;
    }
  }

  // Отметить напоминание как выполненное
  Future<bool> completeReminder(String token, String reminderId, {
    String? note,
    String? completionDate,
    String timezone = 'Europe/Moscow',
    String source = 'mobile'
  }) async {
    try {
      AppLogger.api('Отметка выполнения напоминания: $reminderId');
      
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final body = <String, dynamic>{
        'timezone': timezone,
        'source': source,
      };
      if (note != null) body['note'] = note;
      if (completionDate != null) body['completionDate'] = completionDate;

      final response = await http.post(
        Uri.parse('$baseUrl/reminders/$reminderId/complete'),
        headers: headers,
        body: json.encode(body),
      ).timeout(Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          AppLogger.api('Напоминание отмечено как выполненное');
          final dataMap = jsonResponse['data'] as Map<String, dynamic>;
          print('✅ Напоминание выполнено: ${dataMap['message']}');
          return true;
        } else {
          AppLogger.error('Ошибка отметки выполнения: ${jsonResponse['message']}');
          return false;
        }
      } else {
        AppLogger.error('HTTP ошибка при отметке выполнения: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.error('Исключение при отметке выполнения: $e');
      return false;
    }
  }

  // Отменить выполнение напоминания
  Future<bool> uncompleteReminder(String token, String reminderId, {
    String? completionDate,
    String timezone = 'Europe/Moscow'
  }) async {
    try {
      AppLogger.api('Отмена выполнения напоминания: $reminderId');
      
      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final body = <String, dynamic>{
        'timezone': timezone,
      };
      if (completionDate != null) body['completionDate'] = completionDate;

      final response = await http.delete(
        Uri.parse('$baseUrl/reminders/$reminderId/complete'),
        headers: headers,
        body: json.encode(body),
      ).timeout(Duration(seconds: 20));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          AppLogger.api('Выполнение напоминания отменено');
          final dataMap = jsonResponse['data'] as Map<String, dynamic>;
          print('↩️ Выполнение отменено: ${dataMap['message']}');
          return true;
        } else {
          AppLogger.error('Ошибка отмены выполнения: ${jsonResponse['message']}');
          return false;
        }
      } else {
        AppLogger.error('HTTP ошибка при отмене выполнения: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.error('Исключение при отмене выполнения: $e');
      return false;
    }
  }

  // Получение истории выполнений
  Future<List<ReminderCompletion>> getCompletions(String token, {
    String? startDate,
    String? endDate,
    String? reminderId,
    int page = 1,
    int limit = 20
  }) async {
    try {
      AppLogger.api('Запрос истории выполнений напоминаний');
      
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (reminderId != null) queryParams['reminderId'] = reminderId;

      final headers = {
        'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/reminders/completions').replace(queryParameters: queryParams),
        headers: headers,
      ).timeout(Duration(seconds: 20));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          final dataMap = jsonResponse['data'] as Map<String, dynamic>? ?? {};
          final List<dynamic> completionsData = dataMap['completions'] as List<dynamic>? ?? [];
          print('📊 История выполнений: ${completionsData.length}');
          return completionsData.map((completionJson) => ReminderCompletion.fromJson(completionJson)).toList();
        } else {
          AppLogger.error('Ошибка получения истории выполнений: ${jsonResponse['message']}');
          return [];
        }
      } else {
        AppLogger.error('HTTP ошибка при получении истории выполнений: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      AppLogger.error('Исключение при получении истории выполнений: $e');
      return [];
    }
  }

  // Вспомогательные методы для группировки
  
  // Группировка напоминаний по времени дня
  Map<String, List<Reminder>> groupByTimeOfDay(List<Reminder> reminders) {
    final Map<String, List<Reminder>> grouped = {
      'morning': [],
      'afternoon': [],
      'evening': [],
    };

    for (final reminder in reminders) {
      grouped[reminder.timeOfDay]?.add(reminder);
    }

    return grouped;
  }

  // Группировка напоминаний по типу
  Map<String, List<Reminder>> groupByType(List<Reminder> reminders) {
    final Map<String, List<Reminder>> grouped = {};

    for (final reminder in reminders) {
      if (!grouped.containsKey(reminder.type)) {
        grouped[reminder.type] = [];
      }
      grouped[reminder.type]!.add(reminder);
    }

    return grouped;
  }

  // Фильтрация активных напоминаний
  List<Reminder> getActiveReminders(List<Reminder> reminders) {
    return reminders.where((reminder) => reminder.isActive).toList();
  }

  // Проверка наличия напоминаний на сегодня
  bool hasRemindersToday(List<Reminder> reminders) {
    final today = DateTime.now();
    final todayWeekday = today.weekday % 7; // Конвертируем в формат 0-6

    return reminders.any((reminder) => 
      reminder.isActive && 
      (reminder.daysOfWeek.contains(todayWeekday) || 
       _isSameDay(reminder.date, today))
    );
  }


  // Вспомогательный метод для сравнения дат
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  // ========== МЕТОДЫ ДЛЯ РАБОТЫ С ИСКЛЮЧЕНИЯМИ ==========

  // Удалить задачу только для конкретного дня
  Future<bool> deleteReminderForSpecificDay(String token, String reminderId, DateTime date) async {
    try {
      AppLogger.api('Удаление напоминания только для конкретного дня');
      
      final response = await http.post(
        Uri.parse('$baseUrl/reminders/$reminderId/delete-day'),
        headers: {
          'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'exceptionDate': DateFormat('yyyy-MM-dd').format(date),
          'timezone': 'Europe/Moscow',
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        AppLogger.api('Напоминание удалено для конкретного дня');
        return jsonResponse['success'] == true;
      } else {
        AppLogger.error('HTTP ошибка при удалении дня: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.error('Исключение при удалении дня: $e');
      return false;
    }
  }

  // Создать исключение для напоминания
  Future<bool> createReminderException(
    String token, 
    String reminderId, {
    required DateTime exceptionDate,
    required String type, // 'hidden', 'modified', 'deleted'
    Map<String, dynamic>? modifiedData,
    String? reason,
  }) async {
    print('🌐 === API: СОЗДАНИЕ ИСКЛЮЧЕНИЯ ДЛЯ НАПОМИНАНИЯ ===');
    print('🆔 ID напоминания: $reminderId');
    print('📅 Дата исключения: $exceptionDate');
    print('🔧 Тип исключения: $type');
    print('📝 Модифицированные данные: $modifiedData');
    print('💬 Причина: $reason');
    
    try {
      AppLogger.api('Создание исключения для напоминания');
      
      final Map<String, dynamic> requestBody = {
        'exceptionDate': DateFormat('yyyy-MM-dd').format(exceptionDate),
        'type': type,
        'timezone': 'Europe/Moscow',
      };
      
      if (modifiedData != null) {
        requestBody['modifiedData'] = modifiedData;
      }
      
      if (reason != null) {
        requestBody['reason'] = reason;
      }
      
      print('📦 Тело запроса: $requestBody');
      
      final url = '$baseUrl/reminders/$reminderId/exceptions';
      print('🌐 URL запроса: $url');
      print('🔑 Токен: ${token.startsWith('Bearer ') ? token.substring(0, 20) + '...' : 'Bearer ' + token.substring(0, 10) + '...'}');
      
      print('🚀 Отправляем POST запрос...');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: 15));
      
      print('📊 Код ответа: ${response.statusCode}');
      print('📄 Тело ответа: ${response.body}');

      print('📊 Код ответа: ${response.statusCode}');
      print('📄 Тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Успешный ответ сервера (200)');
        final jsonResponse = json.decode(response.body);
        print('📊 Распарсенный JSON: $jsonResponse');
        
        final success = jsonResponse['success'] == true;
        print('🎯 Значение success в ответе: ${jsonResponse['success']}');
        print('✅ Результат операции: $success');
        
        AppLogger.api('Исключение создано: $success');
        print('🌐 === КОНЕЦ API: СОЗДАНИЕ ИСКЛЮЧЕНИЯ ===\n');
        return success;
      } else if (response.statusCode == 201) {
        print('✅ Исключение создано (201)');
        AppLogger.api('Исключение создано (201)');
        print('🌐 === КОНЕЦ API: СОЗДАНИЕ ИСКЛЮЧЕНИЯ ===\n');
        return true;
      } else if (response.statusCode == 400) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['message'] == 'Исключение для этой даты уже существует') {
          print('🔄 Исключение уже существует, пытаемся обновить...');
          final existingException = jsonResponse['data']['existingException'];
          final exceptionId = existingException['_id'];
          
          // Пытаемся обновить существующее исключение
          return await updateReminderException(token, reminderId, exceptionId, 
            modifiedData: modifiedData, reason: reason);
        } else {
          print('❌ Ошибка 400: ${jsonResponse['message']}');
          AppLogger.error('HTTP ошибка при создании исключения: ${response.statusCode}, тело: ${response.body}');
          print('🌐 === КОНЕЦ API: СОЗДАНИЕ ИСКЛЮЧЕНИЯ (ОШИБКА) ===\n');
          return false;
        }
      } else {
        print('❌ Неуспешный код ответа: ${response.statusCode}');
        print('❌ Заголовки ответа: ${response.headers}');
        AppLogger.error('HTTP ошибка при создании исключения: ${response.statusCode}, тело: ${response.body}');
        print('🌐 === КОНЕЦ API: СОЗДАНИЕ ИСКЛЮЧЕНИЯ (ОШИБКА) ===\n');
        return false;
      }
    } catch (e) {
      print('🚨 === ИСКЛЮЧЕНИЕ В API ===');
      print('❌ Тип исключения: ${e.runtimeType}');
      print('❌ Сообщение: $e');
      print('❌ Стек: ${StackTrace.current}');
      AppLogger.error('Исключение при создании исключения: $e');
      print('🌐 === КОНЕЦ API: СОЗДАНИЕ ИСКЛЮЧЕНИЯ (ИСКЛЮЧЕНИЕ) ===\n');
      return false;
    }
  }

  // Обновить существующее исключение для напоминания
  Future<bool> updateReminderException(
    String token, 
    String reminderId,
    String exceptionId, {
    Map<String, dynamic>? modifiedData,
    String? reason,
  }) async {
    print('🔄 === API: ОБНОВЛЕНИЕ ИСКЛЮЧЕНИЯ ДЛЯ НАПОМИНАНИЯ ===');
    print('🆔 ID напоминания: $reminderId');
    print('🆔 ID исключения: $exceptionId');
    print('📝 Модифицированные данные: $modifiedData');
    print('💬 Причина: $reason');
    
    try {
      AppLogger.api('Обновление исключения для напоминания');
      
      final Map<String, dynamic> requestBody = {};
      
      if (modifiedData != null) {
        requestBody['modifiedData'] = modifiedData;
      }
      
      if (reason != null) {
        requestBody['reason'] = reason;
      }
      
      print('📦 Тело запроса: $requestBody');
      
      final url = '$baseUrl/reminders/$reminderId/exceptions/$exceptionId';
      print('🌐 URL запроса: $url');
      
      print('🚀 Отправляем PUT запрос...');
      
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: 15));
      
      print('📊 Код ответа: ${response.statusCode}');
      print('📄 Тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Успешный ответ сервера (200)');
        final jsonResponse = json.decode(response.body);
        print('📊 Распарсенный JSON: $jsonResponse');
        
        final success = jsonResponse['success'] == true;
        print('🎯 Значение success в ответе: ${jsonResponse['success']}');
        print('✅ Результат операции: $success');
        
        AppLogger.api('Исключение обновлено: $success');
        print('🔄 === КОНЕЦ API: ОБНОВЛЕНИЕ ИСКЛЮЧЕНИЯ ===\n');
        return success;
      } else {
        print('❌ Неуспешный код ответа: ${response.statusCode}');
        print('❌ Заголовки ответа: ${response.headers}');
        AppLogger.error('HTTP ошибка при обновлении исключения: ${response.statusCode}, тело: ${response.body}');
        print('🔄 === КОНЕЦ API: ОБНОВЛЕНИЕ ИСКЛЮЧЕНИЯ (ОШИБКА) ===\n');
        return false;
      }
    } catch (e) {
      print('🚨 === ИСКЛЮЧЕНИЕ В API ===');
      print('❌ Тип исключения: ${e.runtimeType}');
      print('❌ Сообщение: $e');
      print('❌ Стек: ${StackTrace.current}');
      AppLogger.error('Исключение при обновлении исключения: $e');
      print('🔄 === КОНЕЦ API: ОБНОВЛЕНИЕ ИСКЛЮЧЕНИЯ (ИСКЛЮЧЕНИЕ) ===\n');
      return false;
    }
  }

  // Получить исключения для напоминания
  Future<List<dynamic>> getReminderExceptions(String token, String reminderId) async {
    try {
      AppLogger.api('Получение исключений для напоминания');
      
      final response = await http.get(
        Uri.parse('$baseUrl/reminders/$reminderId/exceptions'),
        headers: {
          'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
        },
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        
        if (jsonResponse['success'] == true) {
          final data = jsonResponse['data'] as Map<String, dynamic>;
          return data['exceptions'] as List<dynamic>;
        }
      }
      
      AppLogger.error('Ошибка получения исключений: ${response.statusCode}');
      return [];
    } catch (e) {
      AppLogger.error('Исключение при получении исключений: $e');
      return [];
    }
  }
} 