/// Центральная конфигурация API для приложения
class ApiConfig {
  // Базовый URL для API
  static const String baseUrl = 'http://89.110.92.227:3002/api';
  
  // URL для WebSocket подключения
  static const String socketUrl = 'http://89.110.92.227:3002';
  
  // Таймауты для различных типов запросов
  static const Duration standardTimeout = Duration(seconds: 30);
  static const Duration scanTimeout = Duration(seconds: 300);
  static const Duration chatTimeout = Duration(seconds: 30);
  
  // Эндпоинты API
  static const String authSendCode = '/auth/send-code';
  static const String authVerifyCode = '/auth/verify-code';
  static const String authUpdateProfile = '/auth/update-profile';
  static const String authOauth = '/auth/oauth';
  
  static const String scanEndpoint = '/scan/scan';
  static const String scanHistory = '/scan/history';
  
  static const String plantsEndpoint = '/plants';
  
  static const String chatHistory = '/chat/history';
  static const String chatSend = '/chat/send';
  static const String chatRequestOperator = '/chat/request-operator';
  
  static const String reminders = '/reminders';
  
  static const String achievements = '/achievements';
  static const String achievementsCheck = '/achievements/check';
  static const String achievementsProgress = '/achievements/progress';
} 