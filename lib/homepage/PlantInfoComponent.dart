import 'dart:async';
import 'package:flutter/material.dart';
import 'home_styles.dart';
import '../services/api/reminder_service.dart';
import '../models/reminder.dart';
import '../services/logger.dart';
import '../services/plant_events.dart';
import '../scanner/scanner_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlantInfoComponent extends StatefulWidget {
  const PlantInfoComponent({Key? key}) : super(key: key);

  @override
  State<PlantInfoComponent> createState() => _PlantInfoComponentState();
}

class _PlantInfoComponentState extends State<PlantInfoComponent> {
  static const String baseUrl = 'http://89.110.92.227:3002';
  
  final ReminderService _reminderService = ReminderService();
  List<Reminder> _todayReminders = [];
  bool _isLoading = true;
  int _currentReminderIndex = 0;
  PageController _pageController = PageController();
  
  StreamSubscription<PlantEventData>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _loadTodayReminders();
    _subscribeToEvents();
  }
  
  void _subscribeToEvents() {
    _eventSubscription = PlantEvents().stream.listen((event) {
      print('🏠 PlantInfoComponent: Получено событие ${event.type}');
      
      // Обновляем напоминания при любых изменениях
      if (event.type == PlantEventType.reminderCompleted ||
          event.type == PlantEventType.reminderDeleted ||
          event.type == PlantEventType.reminderCreated ||
          event.type == PlantEventType.reminderUpdated) {
        _loadTodayReminders();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обновляем данные при возврате на главную страницу
    if (!_isLoading && mounted) {
      _loadTodayReminders();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _eventSubscription?.cancel();
    super.dispose();
  }

  String _convertToFullUrl(String imageUrl) {
    if (imageUrl.isEmpty) return '';
    
    // Если это относительный путь, добавляем базовый URL
    if (imageUrl.startsWith('/uploads/')) {
      return '$baseUrl$imageUrl';
    }
    
    // Если уже полный URL или локальный asset, возвращаем как есть
    return imageUrl;
  }

  String? _getPlantImageUrl(Reminder reminder) {
    print('🖼️ Получение изображения для растения:');
    print('   Plant ID: ${reminder.plantId}');
    print('   Plant name: ${reminder.plant?.name ?? "нет названия"}');
    print('   Plant images count: ${reminder.plant?.images.length ?? 0}');
    
    if (reminder.plant?.images.isNotEmpty == true) {
      final images = reminder.plant!.images;
      print('   Images available: ${images.keys.join(", ")}');
      
      // Расширенный список приоритетных ключей включая 'photo'
      final imageKeys = ['photo', 'user_image', 'original', 'main_image', 'thumbnail', 'image', 'picture'];
      
      for (String key in imageKeys) {
        if (images[key] != null && images[key]!.isNotEmpty) {
          final fullUrl = _convertToFullUrl(images[key]!);
          print('   ✅ Используем изображение $key: $fullUrl');
          return fullUrl;
        }
      }
      
      // Если ничего не найдено в приоритетных, берем первое доступное
      for (var entry in images.entries) {
        if (entry.value.isNotEmpty) {
          final fullUrl = _convertToFullUrl(entry.value);
          print('   ✅ Используем первое доступное изображение ${entry.key}: $fullUrl');
          return fullUrl;
        }
      }
    }
    
    print('   ❌ Изображения не найдены');
    return null;
  }

  Future<void> _loadTodayReminders() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Загружаем сегодняшние напоминания со статусом выполнения
      final reminders = await _reminderService.getRemindersWithStatus(token);
      
      print('🏠 === АНАЛИЗ НАПОМИНАНИЙ В PlantInfoComponent ===');
      print('🏠 Всего напоминаний получено от API: ${reminders.length}');
      
      // Анализируем каждое напоминание
      for (int i = 0; i < reminders.length; i++) {
        final r = reminders[i];
        print('🏠 Напоминание #$i: id=${r.id}, type=${r.type}, plantId=${r.plantId}');
        print('   ✅ Активно: ${r.isActive}, Завершено: ${r.isCompleted}');
        print('   🌱 Растение: ${r.plant?.name ?? "не привязано"}');
        final willBeShown = r.isActive && !r.isCompleted;
        print('   👁️ Будет показано: $willBeShown');
      }
      
      final filteredReminders = reminders.where((r) => r.isActive && !r.isCompleted).toList();
      print('🏠 После фильтрации (активные + невыполненные): ${filteredReminders.length}');
      print('🏠 === КОНЕЦ АНАЛИЗА НАПОМИНАНИЙ ===');
      
      setState(() {
        // Показываем все активные напоминания (включая выполненные, но сегодняшние)
        // Это должно решить проблему с не отображающимися задачами
        _todayReminders = filteredReminders; // уже отфильтрованы активные + невыполненные
        _isLoading = false;
      });

      print('🏠 PlantInfoComponent: Загружены активные напоминания: ${_todayReminders.length}');
      
    } catch (e) {
      AppLogger.error('Ошибка загрузки напоминаний в PlantInfoComponent: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isProcessingCompletion = false; // Добавляем флаг для предотвращения двойных тапов

  Future<void> _toggleReminderCompletion(Reminder reminder) async {
    // Защита от двойных тапов
    if (_isProcessingCompletion) return;
    
    try {
      setState(() {
        _isProcessingCompletion = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty || reminder.id == null) return;

      final success = await _reminderService.completeReminder(
        token, 
        reminder.id!,
        note: 'Выполнено из верхнего блока',
      );

      if (success) {
        // Плавная анимация удаления с задержкой
        await Future.delayed(Duration(milliseconds: 500));
        
        // Отправляем событие о выполнении напоминания
        PlantEvents().notifyReminderCompleted(reminder.id!, plantId: reminder.plantId);
        
        // МГНОВЕННОЕ обновление UI - убираем выполненное напоминание из списка
        setState(() {
          _todayReminders.removeWhere((r) => r.id == reminder.id);
          print('🔄 PlantInfo: Убрали выполненное напоминание ${reminder.id} из списка. Осталось: ${_todayReminders.length}');
        });

        // Показываем успешное сообщение
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Напоминание выполнено!'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Ошибка изменения статуса напоминания: $e');
    } finally {
      // Снимаем блокировку через 0.5 секунды (как просил клиент)
      await Future.delayed(Duration(milliseconds: 500));
      setState(() {
        _isProcessingCompletion = false;
      });
    }
  }

  String _getReminderTypeName(String type) {
    const typeNames = {
      'watering': 'Полив',
      'spraying': 'Орошение', 
      'fertilizing': 'Удобрение',
      'transplanting': 'Пересадка',
      'pruning': 'Обрезка',
      'pest_control': 'Обработка от вредителей',
      'disease_treatment': 'От болезней',
      'disease_control': 'Обработка от болезней',


    };
    return typeNames[type] ?? type;
  }

  String _getReminderTypeIcon(String type) {
    const typeIcons = {
      'watering': '💧',
      'spraying': '🌿',
      'fertilizing': '🌱',
      'transplanting': '🪴',
      'pruning': '✂️',
      'pest_control': '🐛',
      'disease_treatment': '🏥',
      'disease_control': '🩹',


    };
    return typeIcons[type] ?? '📋';
  }

  Widget _buildReminderTypeIcon(String reminderType, double iconSize) {
    String emoji;
    Color backgroundColor;
    
    switch (reminderType.toLowerCase()) {
      case 'watering':
        emoji = '💧';
        backgroundColor = Color(0xFFE3F2FD);
        break;
      case 'spraying':
        emoji = '🌿';
        backgroundColor = Color(0xFFE8F5E8);
        break;
      case 'fertilizing':
        emoji = '🌱';
        backgroundColor = Color(0xFFF3E5F5);
        break;
      case 'transplanting':
        emoji = '🪴';
        backgroundColor = Color(0xFFFFF3E0);
        break;
      case 'pruning':
        emoji = '✂️';
        backgroundColor = Color(0xFFFFEBEE);
        break;
      case 'pest_control':
        emoji = '🐛';
        backgroundColor = Color(0xFFFFF8E1);
        break;
      case 'disease_treatment':
        emoji = '🏥';
        backgroundColor = Color(0xFFE0F2F1);
        break;
      case 'disease_control':
        emoji = '🩹';
        backgroundColor = Color(0xFFE8F5E8);
        break;

      default:
        emoji = '🌸';
        backgroundColor = Color(0xFFF5F5F5);
    }
    
    return Container(
      width: iconSize * 1.8,
      height: iconSize * 1.8,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(iconSize * 0.2),
      ),
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: iconSize),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF63A36C)),
        ),
      );
    }

    // Если есть активные напоминания, показываем их
    if (_todayReminders.isNotEmpty) {
      return _buildReminderContent();
    }

    // Если нет напоминаний, показываем заглушку
    return _buildEmptyContent();
  }

  Widget _buildEmptyContent() {
    return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/images/home/2262668.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade100,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_florist,
                                  size: 50, color: HomeStyles.primaryGreen),
                              SizedBox(height: 10),
                              Text(
                                'Изображение растения',
                                style: TextStyle(
                                  color: HomeStyles.primaryGreen,
                                  fontFamily: 'Gilroy',
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
          padding: EdgeInsets.only(top: 8, bottom: 10),
                  child: Text(
                    'Сегодня нет запланированных работ',
                    textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF63A36C),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReminderContent() {
    if (_todayReminders.length == 1) {
      return _buildSingleReminderContent(_todayReminders.first);
    } else {
      return _buildMultipleReminderContent();
    }
  }

  Widget _buildSingleReminderContent(Reminder reminder) {
    final plantImageUrl = _getPlantImageUrl(reminder);
    final DateTime? remindDate = reminder.date;
    String? dateString;
    if (remindDate != null) {
      dateString = 'Полить: '
        + '${remindDate.day.toString().padLeft(2, '0')}'
        + ' '
        + _monthName(remindDate.month)
        + ' ${remindDate.year}, '
        + '${remindDate.hour.toString().padLeft(2, '0')}:${remindDate.minute.toString().padLeft(2, '0')}';
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxH = constraints.maxHeight;
        final double maxW = constraints.maxWidth;
        final double imageSize = (maxH * 0.36).clamp(50, 90);
        final double iconSize = (imageSize * 0.45).clamp(18, 36);
        final double titleFont = (maxH * 0.08).clamp(12, 18);
        final double latinFont = (titleFont * 0.7).clamp(9, 13);
        final double buttonFont = (titleFont * 0.8).clamp(10, 15);
        final double buttonIcon = (iconSize * 0.7).clamp(13, 18);
        final double buttonPadV = (maxH * 0.03).clamp(4, 8);
        final double buttonPadH = (maxW * 0.04).clamp(10, 18);
        final double gap = (maxH * 0.03).clamp(4, 10);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Индикатор типа напоминания
            Padding(
              padding: EdgeInsets.only(top: gap, bottom: gap/2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getReminderTypeIcon(reminder.type),
                    style: TextStyle(fontSize: iconSize),
                  ),
                  SizedBox(width: gap/2),
                  Text(
                    _getReminderTypeName(reminder.type),
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: titleFont,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF63A36C),
                    ),
                  ),
                ],
              ),
            ),
            // Картинка + справа названия и кнопка под ними
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Картинка
                Container(
                  width: imageSize,
                  height: imageSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(imageSize * 0.12),
                    color: Color(0xFFF0F8EC),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(imageSize * 0.12),
                    child: plantImageUrl != null
                        ? Image.network(
                            plantImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildReminderTypeIcon(reminder.type, iconSize);
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF63A36C)),
                                ),
                              );
                            },
                          )
                        : _buildReminderTypeIcon(reminder.type, iconSize),
                  ),
                ),
                SizedBox(width: gap),
                // Справа: названия и кнопка под ними
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        _getPlantDisplayName(reminder.plant?.name ?? '', reminder.type),
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: titleFont,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2024),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (reminder.plant?.latinName?.isNotEmpty == true)
                        Padding(
                          padding: EdgeInsets.only(top: 2, bottom: 4),
                          child: Text(
                            reminder.plant!.latinName,
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: latinFont,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF7A7A7A),
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      // Кнопка под названиями
                      GestureDetector(
                        onTap: () => _toggleReminderCompletion(reminder),
                        child: Container(
                          margin: EdgeInsets.only(top: 4),
                          padding: EdgeInsets.symmetric(
                            horizontal: buttonPadH,
                            vertical: buttonPadV,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Color(0xFF63A36C), width: 2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check,
                                color: Color(0xFF63A36C),
                                size: buttonIcon,
                              ),
                              SizedBox(width: gap/2),
                              Text(
                                'Отметить выполненным',
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontSize: buttonFont,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF63A36C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: gap * 1.2),
            // Внизу — дата и время полива
            if (dateString != null)
              Padding(
                padding: EdgeInsets.only(top: gap * 0.7),
                child: Text(
                  dateString,
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: latinFont,
                    color: Color(0xFF7A7A7A),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        );
      },
    );
  }

  String _monthName(int month) {
    const months = [
      '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return months[month];
  }

  Widget _buildMultipleReminderContent() {
    return Column(
      children: [
        // Компактный индикатор количества напоминаний
        Padding(
          padding: EdgeInsets.only(top: 5, bottom: 5),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Color(0xFF63A36C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_currentReminderIndex + 1} из ${_todayReminders.length}',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF63A36C),
              ),
            ),
          ),
        ),
        
        // PageView для напоминаний
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentReminderIndex = index;
              });
            },
            itemCount: _todayReminders.length,
            itemBuilder: (context, index) {
              return _buildSingleReminderContent(_todayReminders[index]);
            },
          ),
        ),
        
        // Компактные точки индикаторы
        if (_todayReminders.length > 1)
          Padding(
            padding: EdgeInsets.only(bottom: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _todayReminders.length,
                (index) => Container(
                  width: 6,
                  height: 6,
                  margin: EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: index == _currentReminderIndex 
                        ? Color(0xFF63A36C)
                        : Color(0xFF63A36C).withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlantImageWithFallback(String plantId, String plantName, Map<String, dynamic> images, String reminderType) {
    // Если есть изображения, используем их
    if (images.isNotEmpty) {
      for (String key in ['thumbnail', 'crop', 'user_image', 'original_image', 'scan_image', 'main_image']) {
        if (images.containsKey(key) && images[key] != null && images[key].toString().isNotEmpty) {
          final imageUrl = images[key].toString();
          final fullImageUrl = imageUrl.startsWith('http') ? imageUrl : '$baseUrl$imageUrl';
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              fullImageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(reminderType),
            ),
          );
        }
      }
    }
    
    // Если нет изображений, показываем иконку на основе типа напоминания
    return _buildFallbackIcon(reminderType);
  }

  Widget _buildFallbackIcon(String reminderType) {
    String emoji;
    Color backgroundColor;
    
    switch (reminderType.toLowerCase()) {
      case 'watering':
        emoji = '💧';
        backgroundColor = Color(0xFFE3F2FD);
        break;
      case 'spraying':
        emoji = '🌿';
        backgroundColor = Color(0xFFE8F5E8);
        break;
      case 'fertilizing':
        emoji = '🌱';
        backgroundColor = Color(0xFFF3E5F5);
        break;
      case 'transplanting':
        emoji = '🪴';
        backgroundColor = Color(0xFFFFF3E0);
        break;
      case 'pruning':
        emoji = '✂️';
        backgroundColor = Color(0xFFFFEBEE);
        break;
      case 'pest_control':
        emoji = '🐛';
        backgroundColor = Color(0xFFFFF8E1);
        break;
      case 'disease_treatment':
        emoji = '🏥';
        backgroundColor = Color(0xFFE0F2F1);
        break;
      case 'disease_control':
        emoji = '🩹';
        backgroundColor = Color(0xFFE8F5E8);
        break;

      default:
        emoji = '🌸';
        backgroundColor = Color(0xFFF5F5F5);
    }
    
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: 28),
        ),
      ),
    );
  }

  String _getPlantDisplayName(String plantName, String reminderType) {
    if (plantName.isNotEmpty && plantName != 'нет названия') {
      return plantName;
    }
    
    // Возвращаем название на основе типа напоминания
    switch (reminderType.toLowerCase()) {
      case 'watering':
        return 'Полив растения';
      case 'spraying':
        return 'Орошение растения';
      case 'fertilizing':
        return 'Удобрение растения';
      case 'transplanting':
        return 'Пересадка растения';
      case 'pruning':
        return 'Обрезка растения';
      case 'pest_control':
        return 'Обработка от вредителей';
      case 'disease_treatment':
        return 'От болезней';
      default:
        return 'Общее напоминание';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: 20, right: 20, top: 6, bottom: 40),
      height: 270,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Color(0x1931873F),
            blurRadius: 15,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(15, 15, 15, 30),
            child: _buildMainContent(),
          ),
          // Кнопка "Добавить растение" всегда внизу (как в старом коде)
          Positioned(
            bottom: -20,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  print('🌱 PlantInfoComponent: Кнопка "Добавить растение" нажата!');
                  print('🌱 _isLoading: $_isLoading, _isProcessingCompletion: $_isProcessingCompletion');
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ScannerScreen()),
                  );
                },
                // Увеличиваем область нажатия
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 50, // Увеличиваем высоту с 40 до 50
                  width: 220, // Увеличиваем ширину с 200 до 220
                  margin: EdgeInsets.symmetric(horizontal: 10), // Добавляем отступы
                  decoration: BoxDecoration(
                    gradient: HomeStyles.addPlantButtonGradient,
                    borderRadius: BorderRadius.circular(25), // Увеличиваем radius пропорционально
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x2963A36C),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      )
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Добавить растение',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
