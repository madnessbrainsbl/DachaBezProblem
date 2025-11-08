import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../models/chat_message.dart';
import '../services/api/chat_service.dart';
import '../services/websocket_service.dart';
import '../services/achievement_manager.dart';
import '../services/logger.dart';
import '../widgets/plant_analysis_widget.dart';
import '../widgets/camera_capture_screen.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({Key? key}) : super(key: key);

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final WebSocketService _webSocketService = WebSocketService();
  final AchievementManager _achievementManager = AchievementManager();

  // Состояние чата
  ChatStatus _chatStatus = ChatStatus.active;
  String? _sessionId;
  String? _operatorName;
  bool _isLoading = false;
  bool _isOperatorTyping = false;
  bool _isAiThinking = false;
  Timer? _typingTimer;
  
  // Для прикрепления фото
  File? _attachedImage;
  final int _maxMessages = 20; // Лимит сообщений в истории
  
  // Для пагинации истории
  bool _isLoadingHistory = false;
  bool _hasMoreHistory = true;
  int _currentPage = 1;

  // Подписки на события WebSocket
  late StreamSubscription _newMessageSubscription;
  late StreamSubscription _aiResponseSubscription;
  late StreamSubscription _operatorJoinedSubscription;
  late StreamSubscription _chatReleasedSubscription;
  late StreamSubscription _userTypingSubscription;
  late StreamSubscription _statusSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
    _setupWebSocketListeners();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    
    // Отмена подписок
    _newMessageSubscription.cancel();
    _aiResponseSubscription.cancel();
    _operatorJoinedSubscription.cancel();
    _chatReleasedSubscription.cancel();
    _userTypingSubscription.cancel();
    _statusSubscription.cancel();
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _webSocketService.connect();
    } else if (state == AppLifecycleState.paused) {
      _webSocketService.disconnect();
    }
  }

  /// Инициализация чата
  Future<void> _initializeChat() async {
    print('🚀 НАЧАЛО ИНИЦИАЛИЗАЦИИ ЧАТА');
    setState(() => _isLoading = true);

    try {
      print('📡 Подключение к WebSocket...');
      // Подключаемся к WebSocket
      await _webSocketService.connect();
      print('✅ WebSocket подключен: ${_webSocketService.isConnected}');
      
      print('📖 Загрузка истории чата...');
      // Загружаем историю чата
      await _loadChatHistory();
      print('✅ История чата загружена: ${_messages.length} сообщений');
      
      print('✅ Чат инициализирован успешно');
    } catch (e) {
      AppLogger.error('❌ Ошибка инициализации чата', e);
      _showErrorSnackBar('Ошибка подключения к чату: $e');
    } finally {
      setState(() => _isLoading = false);
      print('🏁 ЗАВЕРШЕНИЕ ИНИЦИАЛИЗАЦИИ ЧАТА');
    }
  }

  /// Загрузка истории чата
  Future<void> _loadChatHistory() async {
    print('📖 === ЗАГРУЗКА ИСТОРИИ ЧАТА ===');
    try {
      print('🔍 Запрос истории: limit=$_maxMessages, page=1');
      final response = await _chatService.getChatHistory(limit: _maxMessages);
      print('📦 Получен ответ: ${response.toString()}');
      
      // Правильно извлекаем данные из вложенной структуры
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final history = data['history'] as List<dynamic>? ?? [];
      final total = data['total'] as int? ?? 0;
      
      print('📊 История: ${history.length} сообщений из $total общих');
      
      setState(() {
        _messages.clear();
        print('🧹 Очищен список сообщений');
        
        if (history.isNotEmpty) {
          final parsedMessages = history.map((msg) {
            print('📝 Парсинг сообщения: ${msg.toString()}');
            return ChatMessage.fromJson(msg);
          }).toList();
          
          _messages.addAll(parsedMessages);
          print('✅ Добавлено ${parsedMessages.length} сообщений в список');
        }
        
        // Проверяем есть ли еще сообщения для загрузки
        _hasMoreHistory = _messages.length < total;
        _currentPage = 1;
        print('📄 Пагинация: hasMore=$_hasMoreHistory, currentPage=$_currentPage');
        
        // Если история пустая, добавляем приветственное сообщение
        if (_messages.isEmpty) {
          print('💬 История пустая, добавляем приветственное сообщение');
          _messages.add(ChatMessage(
            author: MessageAuthor.ai,
            text: 'Привет! 🌱 Я ваш ИИ-консультант по садоводству и растениеводству.\n\n'
                  'К сожалению, не удалось загрузить историю сообщений, но я готов помочь вам с новыми вопросами!\n\n'
                  'Отправьте фото растения или задайте свой вопрос.',
            date: DateTime.now(),
            status: MessageStatus.sent,
          ));
          _hasMoreHistory = false;
        }
      });

      // Присоединяемся к сессии чата если есть сообщения
      if (_messages.isNotEmpty && _messages.last.sessionId != null) {
        _sessionId = _messages.last.sessionId;
        print('🔗 Найдена сессия: $_sessionId');
        if (_webSocketService.isConnected) {
          print('🌐 Присоединение к WebSocket сессии...');
          _webSocketService.joinChat(_sessionId!);
        } else {
          print('⚠️ WebSocket не подключен, не можем присоединиться к сессии');
        }
      } else {
        print('ℹ️ Нет активной сессии в истории');
      }

      _scrollToBottom();
      print('✅ История чата успешно загружена: ${_messages.length} сообщений');
    } catch (e) {
      AppLogger.error('❌ Ошибка загрузки истории чата', e);
      
      // Если произошла ошибка, все равно показываем приветственное сообщение
      setState(() {
        _messages.clear();
        _messages.add(ChatMessage(
          author: MessageAuthor.ai,
          text: 'Привет! 🌱 Я ваш ИИ-консультант по садоводству и растениеводству.\n\n'
                'К сожалению, не удалось загрузить историю сообщений, но я готов помочь вам с новыми вопросами!\n\n'
                'Отправьте фото растения или задайте свой вопрос.',
          date: DateTime.now(),
          status: MessageStatus.sent,
        ));
        _hasMoreHistory = false;
      });
      print('🆘 Добавлено резервное приветственное сообщение из-за ошибки');
    }
    print('🏁 === ЗАВЕРШЕНИЕ ЗАГРУЗКИ ИСТОРИИ ===');
  }

  /// Загрузка дополнительной истории
  Future<void> _loadMoreHistory() async {
    if (_isLoadingHistory || !_hasMoreHistory) return;

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final response = await _chatService.getChatHistory(
        limit: _maxMessages,
        page: nextPage,
      );
      
      // Правильно извлекаем данные из вложенной структуры
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final history = data['history'] as List<dynamic>? ?? [];
      final total = data['total'] as int? ?? 0;
      
      if (history.isNotEmpty) {
        final newMessages = history.map((msg) => ChatMessage.fromJson(msg)).toList();
        
        setState(() {
          // Добавляем новые сообщения в начало списка
          _messages.insertAll(0, newMessages);
          _currentPage = nextPage;
          
          // Проверяем есть ли еще сообщения
          _hasMoreHistory = _messages.length < total;
        });
        
        print('Загружено еще ${history.length} сообщений. Всего: ${_messages.length}');
      } else {
        setState(() {
          _hasMoreHistory = false;
        });
      }
    } catch (e) {
      AppLogger.error('Ошибка загрузки дополнительной истории', e);
      _showErrorSnackBar('Ошибка загрузки истории: $e');
    } finally {
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  /// Настройка слушателей WebSocket
  void _setupWebSocketListeners() {
    print('🎧 === НАСТРОЙКА WEBSOCKET СЛУШАТЕЛЕЙ ===');
    
    _newMessageSubscription = _webSocketService.onNewMessage.listen((data) {
      print('📨 WebSocket: получено новое сообщение: ${data.toString()}');
      _handleNewMessage(data);
    });
    
    _aiResponseSubscription = _webSocketService.onAiResponse.listen((data) {
      print('🤖 WebSocket: получен ответ ИИ: ${data.toString()}');
      _handleAiResponse(data);
    });
    
    _operatorJoinedSubscription = _webSocketService.onOperatorJoined.listen((data) {
      print('👨‍💼 WebSocket: оператор присоединился: ${data.toString()}');
      _handleOperatorJoined(data);
    });
    
    _chatReleasedSubscription = _webSocketService.onChatReleased.listen((data) {
      print('🔄 WebSocket: чат возвращен к ИИ: ${data.toString()}');
      _handleChatReleased(data);
    });
    
    _userTypingSubscription = _webSocketService.onUserTyping.listen((data) {
      print('⌨️ WebSocket: индикатор печати: ${data.toString()}');
      _handleUserTyping(data);
    });
    
    _statusSubscription = _webSocketService.onStatusChange.listen((status) {
      print('🔌 WebSocket: изменение статуса: $status');
      _handleWebSocketStatusChange(status);
    });
    
    print('✅ Все WebSocket слушатели настроены');
  }

  /// Обработка нового сообщения
  void _handleNewMessage(Map<String, dynamic> data) {
    print('📨 === ОБРАБОТКА НОВОГО СООБЩЕНИЯ ===');
    print('📊 Данные: ${data.toString()}');
    
    try {
      final message = ChatMessage.fromJson(data);
      print('✅ Сообщение успешно распарсено: ID=${message.id}, tempId=${message.tempId}');
      
      setState(() {
        // Проверяем что это сообщение еще нет в списке
        final existingIndex = _messages.indexWhere((msg) => 
          (msg.id != null && msg.id == message.id) ||
          (msg.tempId != null && msg.tempId == message.tempId)
        );
        
        print('🔍 Проверка дублирования: existingIndex=$existingIndex');
        
        if (existingIndex == -1) {
          print('➕ Добавляем новое сообщение в список');
          _messages.add(message);
          
          // Ограничиваем количество сообщений (удаляем старые)
          if (_messages.length > _maxMessages) {
            final removedCount = _messages.length - _maxMessages;
            _messages.removeRange(0, removedCount);
            print('🗑️ Удалено $removedCount старых сообщений');
          }
        } else {
          print('⚠️ Сообщение уже существует, пропускаем');
        }
        
        if (message.sessionId != null) {
          _sessionId = message.sessionId;
          print('🔗 Обновлена сессия: $_sessionId');
        }
        
        print('📊 Итого сообщений: ${_messages.length}');
      });
      
      _scrollToBottom();
      print('📜 Прокрутка к последнему сообщению');
    } catch (e) {
      AppLogger.error('❌ Ошибка при обработке нового сообщения', e);
    }
    
    print('🏁 === ЗАВЕРШЕНИЕ ОБРАБОТКИ НОВОГО СООБЩЕНИЯ ===');
  }

  /// Обработка ответа ИИ
  void _handleAiResponse(Map<String, dynamic> data) {
    print('🤖 === ОБРАБОТКА ОТВЕТА ИИ ===');
    print('📊 Данные ответа ИИ: ${data.toString()}');
    
    try {
      final message = ChatMessage.fromJson(data);
      print('✅ Ответ ИИ успешно распарсен: ID=${message.id}');
      
      if (!mounted) {
        print('⚠️ Виджет не смонтирован, пропускаем обновление');
        return;
      }
      
      // Проверяем, не является ли это техническим сообщением об ошибке
      final isErrorMessage = message.text?.contains('проблемы с ответом') == true ||
                            message.text?.contains('Попробуй позже') == true;
      
      if (isErrorMessage) {
        print('⚠️ Обнаружено техническое сообщение об ошибке от AI');
        
        // Проверяем, было ли отправлено изображение в последнем сообщении
        final lastUserMessage = _messages.lastWhere(
          (msg) => msg.isFromUser,
          orElse: () => _messages.last,
        );
        final wasImageSent = lastUserMessage.localImageFile != null || 
                            lastUserMessage.imageUrl != null;
        
        if (wasImageSent) {
          // Показываем полезное сообщение вместо технического
          if (mounted) {
            _showErrorSnackBar(
              'AI не смог распознать растение на фото.\n\n'
              'Рекомендации:\n'
              '• Сфотографируйте растение крупным планом\n'
              '• Убедитесь, что растение хорошо освещено\n'
              '• Уберите лишние объекты из кадра\n'
              '• Попробуйте сфотографировать листья ближе'
            );
          }
        }
      }
      
      setState(() {
        // Проверяем что это сообщение еще нет в списке
        final existingIndex = _messages.indexWhere((msg) => 
          (msg.id != null && msg.id == message.id) ||
          (msg.tempId != null && msg.tempId == message.tempId)
        );
        
        print('🔍 Проверка дублирования ответа ИИ: existingIndex=$existingIndex');
        
        if (existingIndex == -1) {
          print('➕ Добавляем ответ ИИ в список');
          _messages.add(message);
          
          // Ограничиваем количество сообщений (удаляем старые)
          if (_messages.length > _maxMessages) {
            final removedCount = _messages.length - _maxMessages;
            _messages.removeRange(0, removedCount);
            print('🗑️ Удалено $removedCount старых сообщений');
          }
        } else {
          print('⚠️ Ответ ИИ уже существует, пропускаем');
        }
        
        if (message.sessionId != null) {
          _sessionId = message.sessionId;
          print('🔗 Обновлена сессия из ответа ИИ: $_sessionId');
        }
        
        // Скрываем индикатор обдумывания при получении ответа ИИ
        _isAiThinking = false;
        
        print('📊 Итого сообщений после ответа ИИ: ${_messages.length}');
      });
      
      _scrollToBottom();
      print('📜 Прокрутка к ответу ИИ');
      
      // Проверяем достижения за чат с ИИ
      print('🏆 Проверка достижений за ответ ИИ...');
      _achievementManager.checkChatAchievements(
        context,
        messageType: 'ai_response',
      );
    } catch (e) {
      print('❌ Исключение при обработке ответа ИИ: $e');
      AppLogger.error('❌ Ошибка при обработке ответа ИИ', e);
      if (mounted) {
        setState(() {
          _isAiThinking = false;
        });
      }
    }
    
    print('🏁 === ЗАВЕРШЕНИЕ ОБРАБОТКИ ОТВЕТА ИИ ===');
  }

  /// Обработка подключения оператора
  void _handleOperatorJoined(Map<String, dynamic> data) {
    setState(() {
      _chatStatus = ChatStatus.withOperator;
      _operatorName = data['operatorName'];
    });
    
    _addSystemMessage('Оператор ${data['operatorName']} присоединился к чату');
    _showSuccessSnackBar('Оператор ${data['operatorName']} подключился');
  }

  /// Обработка возврата чата к ИИ
  void _handleChatReleased(Map<String, dynamic> data) {
    setState(() {
      _chatStatus = ChatStatus.active;
      _operatorName = null;
    });
    
    _addSystemMessage('Чат возвращён ИИ-помощнику');
    _showInfoSnackBar('Чат возвращён ИИ-помощнику');
  }

  /// Обработка индикатора печати
  void _handleUserTyping(Map<String, dynamic> data) {
    if (data['userType'] == 'operator') {
      setState(() {
        _isOperatorTyping = data['typing'] == true;
      });
      
      // Автоматически скрываем индикатор через 3 секунды
      if (_isOperatorTyping) {
        _typingTimer?.cancel();
        _typingTimer = Timer(Duration(seconds: 3), () {
          setState(() => _isOperatorTyping = false);
        });
      }
    }
  }

  /// Обработка изменения статуса WebSocket
  void _handleWebSocketStatusChange(WebSocketStatus status) {
    print('🔌 === ИЗМЕНЕНИЕ СТАТУСА WEBSOCKET ===');
    print('📊 Новый статус: $status');
    
    switch (status) {
      case WebSocketStatus.connected:
        print('✅ WebSocket подключен');
        if (_sessionId != null) {
          print('🔗 Присоединение к существующей сессии: $_sessionId');
          _webSocketService.joinChat(_sessionId!);
        } else {
          print('ℹ️ Нет активной сессии для присоединения');
        }
        break;
      case WebSocketStatus.connecting:
        print('🔄 WebSocket подключается...');
        break;
      case WebSocketStatus.disconnected:
        print('❌ WebSocket отключен');
        break;
      case WebSocketStatus.error:
        print('⚠️ Ошибка WebSocket соединения');
        _showErrorSnackBar('Ошибка соединения с сервером');
        break;
    }
    
    print('🏁 === ЗАВЕРШЕНИЕ ОБРАБОТКИ СТАТУСА WEBSOCKET ===');
  }

  /// Обработка изменения фокуса
  void _onFocusChange() {
    if (_sessionId != null) {
      if (_focusNode.hasFocus) {
        _webSocketService.startTyping(_sessionId!);
      } else {
        _webSocketService.stopTyping(_sessionId!);
      }
    }
  }

  /// Обеспечение подключения к WebSocket сессии
  Future<void> _ensureWebSocketConnection(String sessionId) async {
    print('🔄 Обеспечение подключения к WebSocket сессии $sessionId');
    
    // Принудительно переподключаемся к WebSocket если он отключен
    if (!_webSocketService.isConnected) {
      print('🔄 WebSocket отключен, переподключаемся...');
      await _webSocketService.connect();
    }
    
    // Ждем стабилизации соединения
    await Future.delayed(Duration(milliseconds: 500));
    
    if (_webSocketService.isConnected) {
      print('🌐 Присоединение к сессии $sessionId...');
      _webSocketService.joinChat(sessionId);
    } else {
      print('⚠️ WebSocket по-прежнему не подключен');
    }
  }

  /// Отправка текстового сообщения
  Future<void> _sendMessage() async {
    print('✉️ === ОТПРАВКА СООБЩЕНИЯ ===');
    
    final text = _messageController.text.trim();
    print('📝 Текст: "${text}"');
    print('🖼️ Изображение прикреплено: ${_attachedImage != null}');
    
    if (text.isEmpty && _attachedImage == null) {
      print('⚠️ Пустое сообщение, отмена отправки');
      return;
    }

    // Сохраняем информацию о типе сообщения до очистки
    final isImageMessage = _attachedImage != null;
    File? imageFile = _attachedImage;
    
    // Предобрабатываем изображение если оно есть
    if (imageFile != null) {
      print('🎨 Начинаем предобработку изображения...');
      imageFile = await _preprocessImage(imageFile);
      print('✅ Предобработка завершена');
    }
    
    print('📊 Тип сообщения: ${isImageMessage ? 'изображение' : 'текст'}');

    final tempMessage = ChatMessage.createUserMessage(
      text: text.isNotEmpty ? text : (isImageMessage ? 'Отправлено изображение' : ''),
      imageFile: _attachedImage,
      tempId: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    print('📦 Создано временное сообщение: tempId=${tempMessage.tempId}');

    setState(() {
      _messages.add(tempMessage);
      _messageController.clear();
      _attachedImage = null; // Очищаем прикрепленное изображение
      _isAiThinking = true; // Показываем индикатор обдумывания
    });
    
    print('➕ Временное сообщение добавлено в UI');
    _scrollToBottom();

    try {
      print('🌐 Отправка через API...');
      
      final response = isImageMessage 
        ? await _chatService.sendImageMessage(
            imageFile: imageFile!,
            text: text.isEmpty ? null : text,
          ).timeout(
            Duration(seconds: 60), // Увеличенный таймаут для изображений
            onTimeout: () {
              throw Exception('Превышено время ожидания ответа (60 сек)');
            },
          )
        : await _chatService.sendTextMessage(text).timeout(
            Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Превышено время ожидания ответа (30 сек)');
            },
          );
      
      print('✅ Получен ответ API: ${response.toString()}');
      
      final sentMessage = ChatMessage.fromJson(response['data']['message']);
      print('📦 Сообщение отправлено: ID=${sentMessage.id}');
      
      if (!mounted) {
        print('⚠️ Виджет не смонтирован, пропускаем обновление');
        return;
      }
      
      setState(() {
        // Заменяем временное сообщение на отправленное
        final index = _messages.indexWhere((msg) => msg.tempId == tempMessage.tempId);
        print('🔍 Поиск временного сообщения: index=$index');
        
        if (index != -1) {
          _messages[index] = sentMessage;
          print('🔄 Временное сообщение заменено на отправленное');
        } else {
          print('⚠️ Временное сообщение не найдено');
        }
        
        // Ограничиваем количество сообщений
        if (_messages.length > _maxMessages) {
          final removedCount = _messages.length - _maxMessages;
          _messages.removeRange(0, removedCount);
          print('🗑️ Удалено $removedCount старых сообщений после отправки');
        }
        
        if (sentMessage.sessionId != null) {
          _sessionId = sentMessage.sessionId;
          print('🔗 Получена новая сессия: $_sessionId');
        }
      });

      // Обеспечиваем подключение к WebSocket сессии
      if (sentMessage.sessionId != null) {
        await _ensureWebSocketConnection(sentMessage.sessionId!);
      }

      // Устанавливаем таймаут для ответа AI (60 секунд для изображений, 30 для текста)
      final timeoutDuration = isImageMessage ? 60 : 30;
      print('⏱️ Запуск таймаута для ответа AI ($timeoutDuration сек)...');
      Future.delayed(Duration(seconds: timeoutDuration), () {
        if (mounted && _isAiThinking) {
          print('⏰ Таймаут ответа AI истек, скрываем индикатор');
          setState(() {
            _isAiThinking = false;
          });
          
          if (isImageMessage) {
            _showErrorSnackBar(
              'AI не смог обработать изображение.\n'
              'Попробуйте:\n'
              '• Сфотографировать растение ближе\n'
              '• Убрать лишние объекты из кадра\n'
              '• Улучшить освещение'
            );
          } else {
            _showErrorSnackBar('AI не ответил вовремя. Попробуйте еще раз.');
          }
        }
      });

      // Проверяем достижения за отправку сообщения
      print('🏆 Проверка достижений за отправку...');
      _achievementManager.checkChatAchievements(
        context,
        messageType: isImageMessage ? 'image_message' : 'text_message',
      );

      print('✅ Сообщение успешно отправлено');
    } catch (e) {
      print('❌ Исключение при отправке: $e');
      AppLogger.error('❌ Ошибка отправки сообщения', e);
      if (!mounted) return;
      
      setState(() {
        final index = _messages.indexWhere((msg) => msg.tempId == tempMessage.tempId);
        if (index != -1) {
          _messages[index] = tempMessage.copyWith(status: MessageStatus.error);
          print('🔴 Сообщение помечено как ошибка');
        }
        _isAiThinking = false; // Скрываем индикатор при ошибке
      });
      _showErrorSnackBar('Ошибка отправки: ${e.toString()}');
    }
    
    print('🏁 === ЗАВЕРШЕНИЕ ОТПРАВКИ СООБЩЕНИЯ ===');
  }

  /// Функция для получения и прикрепления изображения из галереи
  Future<void> _attachImageFromGallery() async {
    // Проверяем, не веб ли это версия
    if (kIsWeb) {
      _showErrorSnackBar('Отправка изображений доступна только в мобильном приложении. Пожалуйста, установите APK версию.');
      return;
    }
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _attachedImage = File(pickedFile.path);
        });
        _showInfoSnackBar('Изображение прикреплено. Добавьте описание и отправьте.');
      }
    } catch (e) {
      AppLogger.error('Ошибка при выборе изображения из галереи', e);
      _showErrorSnackBar('Не удалось выбрать изображение: $e');
    }
  }

  /// Открытие кастомной камеры с кропом и рамкой
  Future<void> _openCustomCamera() async {
    // Проверяем, не веб ли это версия
    if (kIsWeb) {
      _showErrorSnackBar('Камера доступна только в мобильном приложении. Пожалуйста, установите APK версию.');
      return;
    }
    
    print('📸 [_openCustomCamera] Открываем экран кастомной камеры из чата');
    final result = await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => const CameraCaptureScreen(),
        fullscreenDialog: true, // Открываем камеру на весь экран
      ),
    );
    print('📸 [_openCustomCamera] Navigator.pop вернул: $result');
    if (result != null && result is String) {
      setState(() {
        _attachedImage = File(result);
      });
      _showInfoSnackBar('Фото добавлено. Добавьте описание и отправьте.');
    }
  }

  /// Запрос оператора
  void _requestOperator() async {
    try {
      await _chatService.requestOperator(
        message: 'Пользователь запросил помощь оператора',
      );
      
      setState(() {
        _chatStatus = ChatStatus.waitingOperator;
      });
      
      _addSystemMessage('Запрос оператора отправлен. Ожидайте подключения...');
      _showInfoSnackBar('Запрос оператора отправлен');
      
    } catch (e) {
      AppLogger.error('Ошибка запроса оператора', e);
      _showErrorSnackBar('Ошибка запроса оператора: $e');
    }
  }

  /// Добавление системного сообщения
  void _addSystemMessage(String text) {
    final systemMessage = ChatMessage.createSystemMessage(
      text: text,
      sessionId: _sessionId,
    );
    
    setState(() {
      _messages.add(systemMessage);
    });
    _scrollToBottom();
  }

  /// Предобработка изображения для улучшения распознавания AI
  Future<File> _preprocessImage(File imageFile) async {
    print('🎨 === ПРЕДОБРАБОТКА ИЗОБРАЖЕНИЯ ===');
    
    try {
      // Читаем изображение
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) {
        print('⚠️ Не удалось декодировать изображение, возвращаем оригинал');
        return imageFile;
      }
      
      print('📐 Оригинальный размер: ${image.width}x${image.height}');
      
      // 1. Изменяем размер если изображение слишком большое (макс 1024px)
      if (image.width > 1024 || image.height > 1024) {
        final maxDimension = math.max(image.width, image.height);
        final scale = 1024 / maxDimension;
        final newWidth = (image.width * scale).round();
        final newHeight = (image.height * scale).round();
        
        image = img.copyResize(image, width: newWidth, height: newHeight);
        print('📏 Изменен размер до: ${image.width}x${image.height}');
      }
      
      // 2. Улучшаем контраст для лучшего распознавания
      image = img.adjustColor(image, contrast: 1.2);
      print('🎨 Улучшен контраст');
      
      // 3. Немного повышаем яркость если изображение темное
      image = img.adjustColor(image, brightness: 1.1);
      print('💡 Улучшена яркость');
      
      // 4. Применяем небольшое повышение резкости
      image = img.adjustColor(image, saturation: 1.1);
      print('✨ Улучшена насыщенность');
      
      // Сохраняем обработанное изображение
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final processedPath = '${tempDir.path}/processed_$timestamp.jpg';
      final processedFile = File(processedPath);
      
      // Кодируем в JPEG с качеством 85%
      final processedBytes = img.encodeJpg(image, quality: 85);
      await processedFile.writeAsBytes(processedBytes);
      
      print('✅ Изображение обработано и сохранено: $processedPath');
      print('📊 Размер: ${processedBytes.length} байт');
      
      return processedFile;
    } catch (e) {
      print('❌ Ошибка предобработки изображения: $e');
      AppLogger.error('Ошибка предобработки изображения', e);
      // В случае ошибки возвращаем оригинал
      return imageFile;
    }
  }

  /// Функция для показа диалога выбора источника изображения
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Выберите источник'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF63A36C)),
                title: const Text('Сделать фото'),
                onTap: () {
                  Navigator.pop(context);
                  _openCustomCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF63A36C)),
                title: const Text('Выбрать из галереи'),
                onTap: () {
                  Navigator.pop(context);
                  _attachImageFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Прокрутка к последнему сообщению
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  /// Показ различных уведомлений
  void _showErrorSnackBar(String message) {
    // Определяем длительность показа в зависимости от длины сообщения
    final duration = message.length > 100 ? Duration(seconds: 8) : Duration(seconds: 5);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontSize: 13,
            height: 1.4, // Межстрочный интервал для читаемости
          ),
        ),
        backgroundColor: Colors.red.shade700,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Color(0xFF63A36C),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Показ детального анализа растения
  void _showPlantAnalysisDialog(PlantAnalysis analysis) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: PlantAnalysisWidget(analysis: analysis),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEBF5DB),
              Color(0xFFB7E0A4),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Шапка с информацией о статусе
              _buildHeader(context),

              // Индикатор загрузки
              if (_isLoading)
                const LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: Color(0xFF63A36C),
                ),

              // Сообщения чата
              Expanded(
                child: _messages.isEmpty && !_isLoading
                    ? _buildEmptyState()
                    : _buildMessageList(),
              ),

              // Индикатор печати оператора
              if (_isOperatorTyping)
                _buildTypingIndicator(),

              // Индикатор обдумывания ИИ
              if (_isAiThinking)
                _buildAiThinkingIndicator(),

              // Поле ввода сообщения
              _buildMessageInput(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ИИ-чат',
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.005,
                  color: Color(0xFF1F2024),
                ),
              ),
              Text(
                _getStatusText(),
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 12,
                  color: _getStatusColor(),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Кнопка запроса оператора (временно отключена до готовности сервиса)
          // if (_chatStatus == ChatStatus.active)
          //   IconButton(
          //     onPressed: _requestOperator,
          //     icon: const Icon(
          //       Icons.support_agent,
          //       color: Color(0xFF63A36C),
          //     ),
          //     tooltip: 'Запросить оператора',
          //   ),
          // Индикатор состояния WebSocket
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _webSocketService.isConnected ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Color(0xFF63A36C),
          ),
          SizedBox(height: 16),
          Text(
            'Задайте вопрос консультанту',
            style: TextStyle(
              color: Color(0xFF63A36C),
              fontFamily: 'Gilroy',
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Отправьте фото растения для анализа\nили задайте вопрос по уходу',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF63A36C),
              fontFamily: 'Gilroy',
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + (_hasMoreHistory ? 1 : 0), // +1 для кнопки загрузки
      itemBuilder: (context, index) {
        // Кнопка загрузки истории в начале списка
        if (index == 0 && _hasMoreHistory) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _isLoadingHistory
                  ? const CircularProgressIndicator(
                      color: Color(0xFF63A36C),
                    )
                  : TextButton.icon(
                      onPressed: _loadMoreHistory,
                      icon: const Icon(
                        Icons.history,
                        color: Color(0xFF63A36C),
                      ),
                      label: const Text(
                        'Загрузить предыдущие сообщения',
                        style: TextStyle(
                          color: Color(0xFF63A36C),
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          );
        }
        
        // Обычные сообщения
        final messageIndex = _hasMoreHistory ? index - 1 : index;
        final message = _messages[messageIndex];
        return _buildMessageItem(message);
      },
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    return Align(
      alignment: message.isFromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isFromUser) _buildBotAvatar(message),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: message.isFromUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: message.isFromUser ? Colors.white : null,
                      gradient: message.isFromUser
                          ? null
                          : _getMessageGradient(message),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF31873F).withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Показ изображения сверху если есть
                        if (message.hasImage)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            height: 150,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: message.localImageFile != null
                                  ? (kIsWeb
                                      ? Image.network(
                                          message.localImageFile!.path,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        )
                                      : Image.file(
                                          message.localImageFile!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        ))
                                  : (message.image?.url != null
                                      ? Image.network(
                                          message.imageUrl!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[300],
                                              child: const Center(
                                                child: Icon(Icons.error, color: Colors.red),
                                              ),
                                            );
                                          },
                                        )
                                      : Container(
                                          color: Colors.grey[300],
                                          child: const Center(
                                            child: Icon(Icons.image, color: Colors.grey),
                                          ),
                                        )),
                            ),
                          ),
                        
                        // Текст сообщения (показываем только если есть содержательный текст)
                        if (message.text.isNotEmpty && 
                            message.text != '[Изображение]' && 
                            message.text != 'Отправлено изображение')
                          Text(
                            message.text,
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                              color: message.isFromUser
                                  ? const Color(0xFF1F2024)
                                  : Colors.white,
                            ),
                          ),
                        
                        // Кнопка детального анализа
                        if (message.hasPlantAnalysis)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextButton.icon(
                                onPressed: () => _showPlantAnalysisDialog(message.aiAnalysis!),
                                icon: const Icon(Icons.visibility, color: Colors.white, size: 16),
                                label: const Text(
                                  'Показать детальный анализ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Индикатор статуса сообщения
                  if (message.isSending || message.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message.isSending)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF63A36C),
                              ),
                            )
                          else if (message.hasError)
                            const Icon(
                              Icons.error_outline,
                              size: 12,
                              color: Colors.red,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            message.isSending ? 'Отправляется...' : 'Ошибка отправки',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: message.hasError ? Colors.red : const Color(0xFF63A36C),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (message.isFromUser) _buildUserAvatar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBotAvatar(ChatMessage message) {
    IconData iconData;
    if (message.isFromOperator) {
      iconData = Icons.support_agent;
    } else if (message.isSystemMessage) {
      iconData = Icons.info_outline;
    } else {
      iconData = Icons.smart_toy;
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: _getMessageGradient(message),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF31873F).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        iconData,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF63A36C),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildBotAvatar(ChatMessage.createSystemMessage(text: '')),
          const SizedBox(width: 8),
          Text(
            '${_operatorName ?? 'Оператор'} печатает...',
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: Color(0xFF63A36C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiThinkingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildBotAvatar(ChatMessage(
            author: MessageAuthor.ai,
            text: '',
            date: DateTime.now(),
          )),
          const SizedBox(width: 8),
          Row(
            children: [
              const Text(
                'Идет обработка, подождите 2–3 минуты',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF63A36C),
                  fontFamily: 'Gilroy',
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF63A36C)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(BuildContext context) {
    // Вычисляем высоту нижней навигации (70 из BottomNavigationComponent + системный отступ)
    final double systemPadding = MediaQuery.of(context).padding.bottom; // safe area (например, 34 на iPhone X)
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double bottomPadding = (keyboardHeight > 0 ? keyboardHeight : systemPadding) + 12;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: bottomPadding,
      ),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        children: [
          // Превью прикрепленного изображения
          if (_attachedImage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF31873F).withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.network(
                            _attachedImage!.path,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            _attachedImage!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Изображение прикреплено',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1F2024),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _attachedImage = null;
                      });
                    },
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF63A36C),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

          // Основное поле ввода
          Container(
            constraints: const BoxConstraints(
              minHeight: 50,
              maxHeight: 150, // Примерно 5 строк
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF31873F).withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Кнопка камеры слева
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFF63A36C),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),

                // Текстовое поле
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      maxLines: null,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1F2024),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Напишите свой вопрос...',
                        hintStyle: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 15,
                          color: Color(0xFFB8B8B8),
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),

                // Кнопка отправки справа
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFF63A36C),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Получение градиента для сообщения
  LinearGradient _getMessageGradient(ChatMessage message) {
    if (message.isFromOperator) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
      );
    } else if (message.isSystemMessage) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF9E9E9E), Color(0xFF757575)],
      );
    } else {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF78B065), Color(0xFF388D79)],
      );
    }
  }

  /// Получение текста статуса
  String _getStatusText() {
    switch (_chatStatus) {
      case ChatStatus.active:
        return _webSocketService.isConnected ? 'Онлайн' : 'Подключение...';
      case ChatStatus.waitingOperator:
        return 'Ожидание оператора...';
      case ChatStatus.withOperator:
        return _operatorName != null ? 'Чат с $_operatorName' : 'Чат с оператором';
      case ChatStatus.closed:
        return 'Чат завершён';
    }
  }

  /// Получение цвета статуса
  Color _getStatusColor() {
    switch (_chatStatus) {
      case ChatStatus.active:
        return _webSocketService.isConnected ? Colors.green : Colors.orange;
      case ChatStatus.waitingOperator:
        return Colors.orange;
      case ChatStatus.withOperator:
        return Colors.blue;
      case ChatStatus.closed:
        return Colors.red;
    }
  }
}
