import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

import 'logger.dart';

enum WebSocketStatus { connecting, connected, disconnected, error }

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  static String get socketUrl => ApiConfig.socketUrl;
  
  IO.Socket? _socket;
  WebSocketStatus _status = WebSocketStatus.disconnected;
  String? _currentSessionId;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  // Stream controllers для событий
  final StreamController<Map<String, dynamic>> _newMessageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _aiResponseController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _operatorJoinedController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _chatReleasedController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _userTypingController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<WebSocketStatus> _statusController = 
      StreamController<WebSocketStatus>.broadcast();

  // Геттеры для подписки на события
  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onAiResponse => _aiResponseController.stream;
  Stream<Map<String, dynamic>> get onOperatorJoined => _operatorJoinedController.stream;
  Stream<Map<String, dynamic>> get onChatReleased => _chatReleasedController.stream;
  Stream<Map<String, dynamic>> get onUserTyping => _userTypingController.stream;
  Stream<WebSocketStatus> get onStatusChange => _statusController.stream;

  WebSocketStatus get status => _status;
  bool get isConnected => _status == WebSocketStatus.connected;
  String? get currentSessionId => _currentSessionId;

  /// Получение токена авторизации
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      AppLogger.error('Ошибка получения токена для WebSocket', e);
      return null;
    }
  }

  /// Подключение к серверу
  Future<void> connect() async {
    if (_socket != null) {
      print('🔌 WebSocket уже подключен или подключается, отключаем сначала');
      disconnect();
    }

    try {
      print('🚀 === ПОДКЛЮЧЕНИЕ К WEBSOCKET ===');
      print('🌐 URL: $socketUrl');
      
      _updateStatus(WebSocketStatus.connecting);

      // Получаем токен авторизации для подключения
      final authObject = await _getAuthObject();
      print('🔐 Токен авторизации для WebSocket: ${authObject.isNotEmpty ? 'найден' : 'отсутствует'}');

      _socket = IO.io(socketUrl, IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .setAuth(authObject) // Передаем авторизацию
          .build());

      print('⚙️ WebSocket сокет создан с параметрами');

      // Обработчики событий подключения
      _socket!.onConnect((_) {
        print('✅ WebSocket подключен успешно');
        _updateStatus(WebSocketStatus.connected);
        _setupEventListeners();
      });

      _socket!.onDisconnect((reason) {
        print('❌ WebSocket отключен: $reason');
        _updateStatus(WebSocketStatus.disconnected);
      });

      _socket!.onConnectError((error) {
        AppLogger.error('⚠️ Ошибка подключения WebSocket', error);
        _updateStatus(WebSocketStatus.error);
      });

      _socket!.onError((error) {
        AppLogger.error('🔥 Ошибка WebSocket', error);
        _updateStatus(WebSocketStatus.error);
      });

      print('🔗 Попытка подключения...');
      _socket!.connect();
      
      // Ждем подключения максимум 10 секунд
      print('⏳ Ожидание подключения (таймаут 10с)...');
      int attempts = 0;
      while (!isConnected && attempts < 50) { // 50 * 200ms = 10s
        await Future.delayed(Duration(milliseconds: 200));
        attempts++;
        if (attempts % 5 == 0) {
          print('⏳ Ожидание подключения... ${attempts * 200}ms');
        }
      }

      if (isConnected) {
        print('🎉 WebSocket успешно подключен за ${attempts * 200}ms');
      } else {
        print('⚠️ Таймаут подключения WebSocket');
        throw Exception('Таймаут подключения к серверу');
      }

    } catch (e) {
      AppLogger.error('❌ Ошибка при подключении к WebSocket', e);
      _updateStatus(WebSocketStatus.error);
      rethrow;
    }
  }

  /// Настройка слушателей событий
  void _setupEventListeners() {
    if (_socket == null) {
      print('⚠️ Попытка настройки слушателей без сокета');
      return;
    }

    print('🎧 === НАСТРОЙКА СЛУШАТЕЛЕЙ WEBSOCKET ===');

    // Сообщения чата
    _socket!.on('new_message', (data) {
      print('📨 Событие new_message: ${data.toString()}');
      try {
        _newMessageController.add(Map<String, dynamic>.from(data));
      } catch (e) {
        AppLogger.error('❌ Ошибка обработки new_message', e);
      }
    });

    _socket!.on('ai_response', (data) {
      print('🤖 Событие ai_response: ${data.toString()}');
      try {
        _aiResponseController.add(Map<String, dynamic>.from(data));
      } catch (e) {
        AppLogger.error('❌ Ошибка обработки ai_response', e);
      }
    });

    // События операторов
    _socket!.on('operator_joined', (data) {
      print('👨‍💼 Событие operator_joined: ${data.toString()}');
      try {
        _operatorJoinedController.add(Map<String, dynamic>.from(data));
      } catch (e) {
        AppLogger.error('❌ Ошибка обработки operator_joined', e);
      }
    });

    _socket!.on('chat_released_to_ai', (data) {
      print('🔄 Событие chat_released_to_ai: ${data.toString()}');
      try {
        _chatReleasedController.add(Map<String, dynamic>.from(data));
      } catch (e) {
        AppLogger.error('❌ Ошибка обработки chat_released_to_ai', e);
      }
    });

    // Индикаторы печати
    _socket!.on('user_typing', (data) {
      print('⌨️ Событие user_typing: ${data.toString()}');
      try {
        _userTypingController.add(Map<String, dynamic>.from(data));
      } catch (e) {
        AppLogger.error('❌ Ошибка обработки user_typing', e);
      }
    });

    // Общие события
    _socket!.on('error', (data) {
      print('🔥 Событие error: ${data.toString()}');
    });

    _socket!.on('message', (data) {
      print('💬 Общее событие message: ${data.toString()}');
    });

    print('✅ Все слушатели WebSocket настроены');
  }

  /// Присоединение к чату
  Future<void> joinChat(String sessionId) async {
    if (!isConnected) {
      print('⚠️ Попытка присоединения к чату без подключения');
      return;
    }

    print('🔗 === ПРИСОЕДИНЕНИЕ К ЧАТУ ===');
    print('🆔 Session ID: $sessionId');

    try {
      final joinData = {
        'sessionId': sessionId,
        'auth': await _getAuthObject(),
      };

      print('📤 Отправка join_chat: ${joinData.toString()}');
      _socket!.emit('join_chat', joinData);
      print('✅ Событие join_chat отправлено');
    } catch (e) {
      AppLogger.error('❌ Ошибка при присоединении к чату', e);
    }
  }

  /// Начало печати
  Future<void> startTyping(String sessionId) async {
    if (!isConnected) return;

    print('⌨️ Начало печати в сессии: $sessionId');
    try {
      _socket!.emit('typing_start', {
        'sessionId': sessionId,
        'auth': await _getAuthObject(),
      });
    } catch (e) {
      AppLogger.error('❌ Ошибка отправки typing_start', e);
    }
  }

  /// Окончание печати
  Future<void> stopTyping(String sessionId) async {
    if (!isConnected) return;

    print('⌨️ Окончание печати в сессии: $sessionId');
    try {
      _socket!.emit('typing_stop', {
        'sessionId': sessionId,
        'auth': await _getAuthObject(),
      });
    } catch (e) {
      AppLogger.error('❌ Ошибка отправки typing_stop', e);
    }
  }

  /// Запрос оператора
  Future<void> requestOperator(String sessionId, {String? message}) async {
    if (!isConnected) return;

    print('👨‍💼 Запрос оператора для сессии: $sessionId');
    print('💬 Сообщение: ${message ?? 'нет'}');
    
    try {
      final requestData = {
        'sessionId': sessionId,
        'auth': await _getAuthObject(),
      };
      
      if (message != null) {
        requestData['message'] = message;
      }

      print('📤 Отправка request_operator: ${requestData.toString()}');
      _socket!.emit('request_operator', requestData);
      print('✅ Запрос оператора отправлен');
    } catch (e) {
      AppLogger.error('❌ Ошибка запроса оператора', e);
    }
  }

  /// Получение объекта авторизации
  Future<Map<String, dynamic>> _getAuthObject() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        print('⚠️ Токен авторизации не найден');
        return {};
      }

      // Для WebSocket убираем префикс "Bearer " если есть
      final cleanToken = token.startsWith('Bearer ') ? token.substring(7) : token;

      final authObject = {
        'token': cleanToken,
      };
      
      print('🔐 Объект авторизации создан (без Bearer префикса)');
      return authObject;
    } catch (e) {
      AppLogger.error('❌ Ошибка создания объекта авторизации', e);
      return {};
    }
  }

  /// Обновление статуса
  void _updateStatus(WebSocketStatus status) {
    print('🔄 Изменение статуса WebSocket: $_status -> $status');
    _status = status;
    _statusController.add(status);
  }

  /// Планирование переподключения
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      AppLogger.error('Достигнуто максимальное количество попыток переподключения');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    
    final delay = Duration(seconds: _reconnectAttempts * 2); // Экспоненциальная задержка
    print('Планирование переподключения через ${delay.inSeconds} секунд (попытка $_reconnectAttempts)');
    
    _reconnectTimer = Timer(delay, () {
      print('Попытка переподключения $_reconnectAttempts из $_maxReconnectAttempts');
      connect();
    });
  }

  /// Отключение от WebSocket
  void disconnect() {
    print('Отключение от WebSocket');
    
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _currentSessionId = null;
    
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    
    _updateStatus(WebSocketStatus.disconnected);
  }

  /// Освобождение ресурсов
  void dispose() {
    print('Освобождение ресурсов WebSocketService');
    
    disconnect();
    
    _newMessageController.close();
    _aiResponseController.close();
    _operatorJoinedController.close();
    _chatReleasedController.close();
    _userTypingController.close();
    _statusController.close();
  }

  /// Переподключение с новым токеном
  Future<void> reconnectWithNewToken() async {
    print('Переподключение с новым токеном');
    disconnect();
    await Future.delayed(Duration(milliseconds: 500));
    await connect();
  }
} 