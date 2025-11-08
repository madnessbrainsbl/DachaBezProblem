import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

/// Утилита для удобного логирования в приложении
/// Позволяет фильтровать логи по категориям и включать/отключать их
class AppLogger {
  // Включен ли логгер
  static bool _enabled = true;

  // Категории логов
  static const String _AUTH = 'AUTH';
  static const String _API = 'API';
  static const String _UI = 'UI';
  static const String _ERROR = 'ERROR';

  // Метод включения/отключения логирования
  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  // Общий метод для логирования
  static void _log(String message, String category) {
    if (!_enabled) return;

    if (kDebugMode) {
      developer.log(message, name: category);
    }
  }

  // Логирование событий аутентификации
  static void auth(String message) {
    _log(message, _AUTH);
  }

  // Логирование API запросов и ответов
  static void api(String message) {
    _log(message, _API);
  }

  // Логирование UI событий
  static void ui(String message) {
    _log(message, _UI);
  }

  // Логирование ошибок
  static void error(String message,
      [dynamic exception, StackTrace? stackTrace]) {
    final errorMessage = stackTrace != null
        ? '$message\nException: $exception\n$stackTrace'
        : '$message\nException: $exception';

    _log(errorMessage, _ERROR);
  }
}
