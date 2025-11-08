import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/achievement.dart';
import '../services/api/achievement_service.dart';
import '../widgets/achievement_notification.dart';
import '../services/logger.dart';

// =============================================================================
// СИСТЕМА УВЕДОМЛЕНИЙ О ДОСТИЖЕНИЯХ
// =============================================================================
//
// AchievementManager поддерживает два типа уведомлений:
//
// 1. TOAST УВЕДОМЛЕНИЯ (для сканирования):
//    - Показываются сразу после завершения сканирования
//    - Не заслоняют кнопку "Продолжить"
//    - Плавают поверх интерфейса с анимацией
//    - Исчезают автоматически через 4 секунды
//    - Используются методом: checkScanAchievements()
//
// 2. ПОЛНОЦЕННЫЕ ПОПАПЫ (для экрана результата):
//    - Показываются на экране результата сканирования
//    - Полноценный диалог с подробной информацией
//    - Кнопки "Закрыть" и "Посмотреть"
//    - Используются методом: checkScanAchievementsWithPopup()
//
// Это решает UX проблему когда попап заслонял кнопку продолжения сканирования.
// =============================================================================

class AchievementManager {
  static AchievementManager? _instance;
  
  AchievementManager._internal();
  
  factory AchievementManager() {
    _instance ??= AchievementManager._internal();
    return _instance!;
  }

  // Получение токена авторизации
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      AppLogger.error('Ошибка получения токена', e);
      return null;
    }
  }

  // Показать уведомления о новых достижениях
  Future<void> _showAchievementNotifications(
    BuildContext context, 
    List<Achievement> achievements
  ) async {
    if (achievements.isEmpty || !context.mounted) return;

    for (int i = 0; i < achievements.length; i++) {
      final achievement = achievements[i];
      AppLogger.api('Показываем уведомление о достижении: ${achievement.name}');
      
      // Добавляем задержку между уведомлениями
      if (i > 0) {
        await Future.delayed(Duration(milliseconds: 500));
      }
      
      if (context.mounted) {
        AchievementNotification.show(context, achievement);
      }
    }
  }

  // НОВЫЙ МЕТОД: Показать Toast уведомления для достижений сканирования
  Future<void> _showScanAchievementToasts(
    BuildContext context, 
    List<Achievement> achievements
  ) async {
    if (achievements.isEmpty || !context.mounted) return;

    for (int i = 0; i < achievements.length; i++) {
      final achievement = achievements[i];
      AppLogger.api('Показываем Toast уведомление о достижении: ${achievement.name}');
      
      // Добавляем задержку между уведомлениями
      if (i > 0) {
        await Future.delayed(Duration(milliseconds: 1000));
      }
      
      if (context.mounted) {
        AchievementNotification.showToast(context, achievement);
      }
    }
  }

  // ПРОВЕРКА ДОСТИЖЕНИЙ ЗА СКАНИРОВАНИЕ (с Toast уведомлениями)
  Future<void> checkScanAchievements(
    BuildContext context, {
    String? plantName,
    double? confidence,
    String? scanType = 'camera',
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null || token.isEmpty) {
        AppLogger.error('Токен авторизации не найден для проверки достижений');
        return;
      }

      AppLogger.api('Проверка достижений за сканирование: plantName=$plantName, confidence=$confidence');
      
      final newAchievements = await AchievementService.checkScanAchievements(
        token,
        plantName: plantName,
        confidence: confidence,
        scanType: scanType,
      );

      if (newAchievements.isNotEmpty) {
        AppLogger.api('Получено ${newAchievements.length} новых достижений за сканирование');
        // ИЗМЕНЕНО: Используем Toast уведомления вместо полных попапов при сканировании
        await _showScanAchievementToasts(context, newAchievements);
      }
    } catch (e) {
      AppLogger.error('Ошибка при проверке достижений за сканирование', e);
    }
  }

  // НОВЫЙ МЕТОД: ПРОВЕРКА ДОСТИЖЕНИЙ ЗА СКАНИРОВАНИЕ (с полноценными попапами)
  Future<void> checkScanAchievementsWithPopup(
    BuildContext context, {
    String? plantName,
    double? confidence,
    String? scanType = 'camera',
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null || token.isEmpty) {
        AppLogger.error('Токен авторизации не найден для проверки достижений');
        return;
      }

      AppLogger.api('Проверка достижений за сканирование (с попапами): plantName=$plantName, confidence=$confidence');
      
      final newAchievements = await AchievementService.checkScanAchievements(
        token,
        plantName: plantName,
        confidence: confidence,
        scanType: scanType,
      );

      if (newAchievements.isNotEmpty) {
        AppLogger.api('Получено ${newAchievements.length} новых достижений за сканирование (показываем попапы)');
        // Используем полноценные попапы для экрана результата
        await _showAchievementNotifications(context, newAchievements);
      }
    } catch (e) {
      AppLogger.error('Ошибка при проверке достижений за сканирование с попапами', e);
    }
  }

  // ПРОВЕРКА ДОСТИЖЕНИЙ ЗА НАПОМИНАНИЯ
  Future<void> checkReminderAchievements(
    BuildContext context, {
    String? reminderType,
    String? plantId,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null || token.isEmpty) {
        AppLogger.error('Токен авторизации не найден для проверки достижений');
        return;
      }

      AppLogger.api('Проверка достижений за напоминания: reminderType=$reminderType, plantId=$plantId');
      
      final newAchievements = await AchievementService.checkReminderAchievements(
        token,
        reminderType: reminderType,
        plantId: plantId,
      );

      if (newAchievements.isNotEmpty) {
        AppLogger.api('Получено ${newAchievements.length} новых достижений за напоминания');
        await _showAchievementNotifications(context, newAchievements);
      }
    } catch (e) {
      AppLogger.error('Ошибка при проверке достижений за напоминания', e);
    }
  }

  // ПРОВЕРКА ДОСТИЖЕНИЙ ЗА АКТИВНОСТЬ (ВХОД В ПРИЛОЖЕНИЕ)
  Future<void> checkLoginAchievements(BuildContext context) async {
    try {
      final token = await _getAuthToken();
      if (token == null || token.isEmpty) {
        AppLogger.error('Токен авторизации не найден для проверки достижений');
        return;
      }

      AppLogger.api('Проверка достижений за активность (вход в приложение)');
      
      final newAchievements = await AchievementService.checkLoginAchievements(token);

      if (newAchievements.isNotEmpty) {
        AppLogger.api('Получено ${newAchievements.length} новых достижений за активность');
        await _showAchievementNotifications(context, newAchievements);
      }
    } catch (e) {
      AppLogger.error('Ошибка при проверке достижений за активность', e);
    }
  }

  // ПРОВЕРКА ДОСТИЖЕНИЙ ЗА ЧАТ С ИИ
  Future<void> checkChatAchievements(
    BuildContext context, {
    String? messageType,
    String? topic,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null || token.isEmpty) {
        AppLogger.error('Токен авторизации не найден для проверки достижений');
        return;
      }

      AppLogger.api('Проверка достижений за чат с ИИ: messageType=$messageType, topic=$topic');
      
      final newAchievements = await AchievementService.checkChatAchievements(
        token,
        messageType: messageType,
        topic: topic,
      );

      if (newAchievements.isNotEmpty) {
        AppLogger.api('Получено ${newAchievements.length} новых достижений за чат');
        await _showAchievementNotifications(context, newAchievements);
      }
    } catch (e) {
      AppLogger.error('Ошибка при проверке достижений за чат', e);
    }
  }

  // ПРОВЕРКА ДОСТИЖЕНИЙ ЗА ИЗБРАННОЕ
  Future<void> checkFavoriteAchievements(
    BuildContext context, {
    String? itemType,
    String? itemId,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null || token.isEmpty) {
        AppLogger.error('Токен авторизации не найден для проверки достижений');
        return;
      }

      AppLogger.api('Проверка достижений за избранное: itemType=$itemType, itemId=$itemId');
      
      final newAchievements = await AchievementService.checkFavoriteAchievements(
        token,
        itemType: itemType,
        itemId: itemId,
      );

      if (newAchievements.isNotEmpty) {
        AppLogger.api('Получено ${newAchievements.length} новых достижений за избранное');
        await _showAchievementNotifications(context, newAchievements);
      }
    } catch (e) {
      AppLogger.error('Ошибка при проверке достижений за избранное', e);
    }
  }

  // УНИВЕРСАЛЬНЫЙ МЕТОД ДЛЯ ПРОВЕРКИ ДОСТИЖЕНИЙ
  Future<void> checkAchievements(
    BuildContext context,
    String action, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null || token.isEmpty) {
        AppLogger.error('Токен авторизации не найден для проверки достижений');
        return;
      }

      AppLogger.api('Универсальная проверка достижений: action=$action, metadata=$metadata');
      
      final newAchievements = await AchievementService.checkAchievements(
        token,
        action,
        metadata: metadata,
      );

      if (newAchievements.isNotEmpty) {
        AppLogger.api('Получено ${newAchievements.length} новых достижений для действия: $action');
        await _showAchievementNotifications(context, newAchievements);
      }
    } catch (e) {
      AppLogger.error('Ошибка при универсальной проверке достижений', e);
    }
  }

  // СИНХРОНИЗАЦИЯ ДОСТИЖЕНИЙ ПРИ ЗАПУСКЕ ПРИЛОЖЕНИЯ
  Future<void> syncAchievementsOnStartup(BuildContext context) async {
    try {
      AppLogger.api('Синхронизация достижений при запуске приложения...');
      
      // Проверяем достижения за активность (вход в приложение)
      await checkLoginAchievements(context);
      
      AppLogger.api('Синхронизация достижений завершена');
    } catch (e) {
      AppLogger.error('Ошибка при синхронизации достижений', e);
    }
  }
} 