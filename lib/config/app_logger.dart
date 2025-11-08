import 'dart:developer' as developer;

/// Простой логгер для приложения
class AppLogger {
  /// Уровни логирования
  static const String _tagInfo = 'INFO';
  static const String _tagWarning = 'WARNING';
  static const String _tagError = 'ERROR';
  static const String _tagDebug = 'DEBUG';

  /// Логирование информационных сообщений
  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    _log(_tagInfo, message, error, stackTrace);
  }

  /// Логирование предупреждений
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _log(_tagWarning, message, error, stackTrace);
  }

  /// Логирование ошибок
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(_tagError, message, error, stackTrace);
  }

  /// Логирование отладочных сообщений
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _log(_tagDebug, message, error, stackTrace);
  }

  /// Внутренний метод для логирования
  static void _log(String level, String message, [Object? error, StackTrace? stackTrace]) {
    final logMessage = '[$level] $message';
    
    if (error != null) {
      developer.log(
        logMessage,
        name: 'DachaBezProblem',
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      developer.log(
        logMessage,
        name: 'DachaBezProblem',
      );
    }
    
    // В debug режиме также выводим в консоль
    print('🌱 $logMessage');
    if (error != null) {
      print('   Error: $error');
    }
    if (stackTrace != null) {
      print('   StackTrace: $stackTrace');
    }
  }
} 