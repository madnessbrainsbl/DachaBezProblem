import 'dart:async';
import 'package:flutter/material.dart';
import 'CalendarComponent.dart';
import 'PlantInfoComponent.dart';
import 'DiseaseAlertComponent.dart';
import 'UsefulInfoComponent.dart';
import 'BottomNavigationComponent.dart';
import 'home_styles.dart';
// Комментируем импорт video_player
// import 'package:video_player/video_player.dart';
import '../scanner/scanner_screen.dart';
// Импортируем новые страницы
import '../pages/calendar_page.dart';
import '../pages/my_dacha_page.dart';
import '../pages/ai_chat_page.dart';
import '../services/achievement_manager.dart';
// Импортируем необходимые классы для напоминаний
import '../services/api/reminder_service.dart';
import '../models/reminder.dart';
import '../services/logger.dart';
import '../services/user_preferences_service.dart';
import '../services/plant_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  const HomeScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex; // Добавляем индекс выбранной страницы

  // Комментируем ненужные состояния и методы
  // bool _showAddPlantModal = false;
  // late VideoPlayerController _videoController;
  // bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    // _initializeVideoPlayer();
    
    // НОВОЕ: Проверяем достижения при запуске приложения
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginAchievements();
    });
  }

  // НОВЫЙ МЕТОД: Проверка достижений при входе в приложение
  Future<void> _checkLoginAchievements() async {
    try {
      final achievementManager = AchievementManager();
      await achievementManager.syncAchievementsOnStartup(context);
    } catch (e) {
      // Не показываем ошибку пользователю, так как это не критично
      print('Ошибка при проверке достижений при запуске: $e');
    }
  }

  // void _initializeVideoPlayer() { ... } // Комментируем

  @override
  void dispose() {
    // _videoController.dispose();
    super.dispose();
  }

  // void _toggleAddPlantModal() { ... } // Комментируем

  // Метод для изменения выбранного индекса
  void _onItemTapped(int index) {
    // Всегда скрываем клавиатуру при переключении вкладок
    FocusScope.of(context).unfocus();
    // Пока не обрабатываем кнопку сканера (индекс 2)
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ScannerScreen()),
      );
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  // Метод для получения текущего виджета (ленивая загрузка)
  Widget _getCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return HomePageContent();
      case 1:
        return CalendarPage();
      case 2:
        return Text('Scanner Placeholder'); // Заглушка для индекса 2 (кнопка сканера)
      case 3:
        return MyDachaPage();
      case 4:
        return AiChatPage(); // Создается только при переходе на эту вкладку!
      default:
        return HomePageContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Расширяем body под нижнюю навигацию
      // Показываем только текущую выбранную страницу
      body: _getCurrentPage(),
      // Нижняя навигация остается неизменной
      bottomNavigationBar: BottomNavigationComponent(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
      // Убираем плавающую кнопку, так как она в BottomNavigationComponent
      // floatingActionButton: ...
      // floatingActionButtonLocation: ...
    );
  }
}

// Создаем отдельный виджет для содержимого главной страницы,
// чтобы не загромождать основной build метод
class HomePageContent extends StatelessWidget {
  const HomePageContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Возвращаем исходный Stack с градиентом и контентом главной страницы
    // Оборачиваем в SafeArea, чтобы контент не залезал под системные элементы
    return SafeArea(
      top: false, // Отключаем верхний SafeArea, так как он был в исходном коде
      bottom: false, // Нижний отступ будет управляться Scaffold и BottomNavBar
      child: Container(
        // Оборачиваем в Container, чтобы применить градиент
        decoration: BoxDecoration(
          gradient: HomeStyles.backgroundGradient,
        ),
        child: Column(
          children: [
            // Верхняя белая часть экрана (включая статус-бар)
            Material(
              color: Colors.white,
              child: SafeArea(
                // Этот SafeArea нужен для отступа сверху
                bottom: false,
                child: Container(
                  color: Colors.white,
                  width: double.infinity,
                  height: 40, // Возможно, нужно будет настроить высоту
                ),
              ),
            ),
            // Верхний календарь
            CalendarComponent(),
            // Блок с информацией о растениях
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Карточка с информацией о растении
                  PlantInfoComponent(),
                  // Оповещение о болезни
                  DiseaseAlertComponent(),
                  // Виджет с сегодняшними напоминаниями
                  TodayRemindersWidget(),
                  // Полезная информация
                  UsefulInfoComponent(),
                  // Отступ снизу не нужен, так как ListView находится внутри Expanded
                  // SizedBox(height: 70),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Виджет для отображения сегодняшних напоминаний
class TodayRemindersWidget extends StatefulWidget {
  const TodayRemindersWidget({Key? key}) : super(key: key);

  @override
  State<TodayRemindersWidget> createState() => _TodayRemindersWidgetState();
}

class _TodayRemindersWidgetState extends State<TodayRemindersWidget> {
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
      print('🏠 TodayRemindersWidget: Получено событие ${event.type}');
      
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

  // Обновляем данные при возврате на экран
  void refreshReminders() {
    if (mounted) {
      _loadTodayReminders();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _eventSubscription?.cancel();
    super.dispose();
  }

  // Метод для получения иконки напоминания по типу
  Widget _getReminderIcon(String type, double size) {
    IconData iconData;
    Color iconColor = Colors.white;
    
    switch (type.toLowerCase()) {
      case 'watering':
        iconData = Icons.water_drop;
        break;
      case 'spraying':
        iconData = Icons.water;
        break;
      case 'fertilizing':
        iconData = Icons.energy_savings_leaf;
        break;
      case 'transplanting':
        iconData = Icons.local_florist;
        break;
      case 'pruning':
        iconData = Icons.content_cut;
        break;
      case 'pest_control':
        iconData = Icons.bug_report;
        break;
      case 'disease_treatment':
        iconData = Icons.healing;
        break;
      default:
        iconData = Icons.eco;
    }
    
    return Icon(
      iconData,
      color: iconColor,
      size: size,
    );
  }

  Future<void> _loadTodayReminders() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final token = await UserPreferencesService.getAuthToken();

      if (token == null || token.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Загружаем сегодняшние напоминания со статусом выполнения
      final reminders = await _reminderService.getRemindersWithStatus(token);
      
      setState(() {
        _todayReminders = reminders.where((r) => r.isActive).toList(); // Только активные
        _isLoading = false;
      });

      print('🏠 Загружены сегодняшние напоминания для главной: ${_todayReminders.length}');
      
      // Детальная информация о каждом напоминании
      for (int i = 0; i < _todayReminders.length; i++) {
        final reminder = _todayReminders[i];
        print('📋 Напоминание ${i + 1}:');
        print('   • ID: ${reminder.id}');
        print('   • Тип: ${reminder.type}');
        print('   • Plant ID: ${reminder.plantId}');
        print('   • Есть plant объект: ${reminder.plant != null}');
        if (reminder.plant != null) {
          print('   • Название растения: ${reminder.plant!.name}');
          print('   • Латинское название: ${reminder.plant!.latinName}');
        } else {
          print('   • ❌ Plant объект отсутствует!');
        }
        print('   • Активно: ${reminder.isActive}');
        print('   • Выполнено: ${reminder.isCompleted}');
        print('');
      }
    } catch (e) {
      AppLogger.error('Ошибка загрузки сегодняшних напоминаний: $e');
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

      final token = await UserPreferencesService.getAuthToken();

      if (token == null || token.isEmpty || reminder.id == null) return;

      bool success;
      if (reminder.isCompleted) {
        success = await _reminderService.uncompleteReminder(token, reminder.id!);
      } else {
        success = await _reminderService.completeReminder(
          token, 
          reminder.id!,
          note: 'Выполнено с главной страницы',
        );
      }

      if (success) {
        // Обновляем состояние с анимацией
        setState(() {
          final index = _todayReminders.indexWhere((r) => r.id == reminder.id);
          if (index != -1) {
            _todayReminders[index] = reminder.copyWith(isCompleted: !reminder.isCompleted);
          }
        });

        // Если отметили как выполненное, показываем анимацию и обновляем через 500ms (увеличено)
        if (!reminder.isCompleted) {
          // Отправляем событие о выполнении напоминания
          PlantEvents().notifyReminderCompleted(reminder.id!, plantId: reminder.plantId);
          
          // МГНОВЕННОЕ обновление UI - убираем выполненное напоминание из списка
          setState(() {
            _todayReminders = _todayReminders.where((r) => r.id != reminder.id).toList();
            print('🔄 Убрали выполненное напоминание ${reminder.id} из списка. Осталось: ${_todayReminders.length}');
          });
          
          await Future.delayed(Duration(milliseconds: 500)); // Уменьшено для быстрого обновления
          _loadTodayReminders(); // Перезагружаем для получения актуальных данных с сервера
        }
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

  String _getReminderTypeDisplayName(String type) {
    switch (type.toLowerCase()) {
      case 'watering':
        return 'Полив';
      case 'spraying':
        return 'Орошение';
      case 'fertilizing':
        return 'Удобрение';
      case 'transplanting':
        return 'Пересадка';
      case 'pruning':
        return 'Обрезка';
      case 'pest_control':
        return 'Обработка от вредителей';
      case 'disease_treatment':
        return 'От болезней';
      case 'disease_control':
        return 'Обработка от болезней';
      default:
        return type.isNotEmpty ? type : 'Напоминание';
    }
  }

  String _getReminderTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'watering':
        return '💧';
      case 'spraying':
        return '🌿';
      case 'fertilizing':
        return '🌱';
      case 'transplanting':
        return '🪴';
      case 'pruning':
        return '✂️';
      case 'pest_control':
        return '🐛';
      case 'disease_treatment':
        return '🏥';
      case 'disease_control':
        return '🩹';
      default:
        return '📋';
    }
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
       case 'disease_control':
         return 'Обработка от болезней';
       default:
         return 'Общее напоминание';
     }
   }

  Widget _buildReminderTypeIcon(String reminderType, double size) {
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
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 
                   'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${now.day}\n${months[now.month - 1]}';
  }

  // Адаптивные размеры для разных экранов
  Map<String, double> _getAdaptiveSizes(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;
    final isMediumScreen = screenWidth >= 375 && screenWidth < 414;
    
    return {
      'dayFontSize': isSmallScreen ? 16.0 : 20.0,
      'monthFontSize': isSmallScreen ? 10.0 : 13.0,
      'titleFontSize': isSmallScreen ? 12.0 : 14.0,
      'subtitleFontSize': isSmallScreen ? 10.0 : 12.0,
      'dateWidth': isSmallScreen ? 28.0 : 32.0,
      'containerHeight': isSmallScreen ? 50.0 : 60.0,
      'horizontalMargin': isSmallScreen ? 16.0 : 20.0,
    };
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sizes = _getAdaptiveSizes(context);
        
        print('🏠 === _buildEmptyState ВЫЗВАН ===');
        print('📊 Всего напоминаний: ${_todayReminders.length}');
        
        // Если есть выполненные задачи, показываем их
        final completedReminders = _todayReminders.where((r) => r.isCompleted).toList();
        print('✅ Выполненных напоминаний: ${completedReminders.length}');
        
        if (completedReminders.isNotEmpty) {
          print('✅ Показываем выполненные задачи');
          return _buildCompletedTasksView(completedReminders, sizes);
        }
        
        // Иначе показываем заглушку
        print('⚠️ Показываем заглушку "нет запланированных работ"');
        return _buildNoTasksView(sizes);
      },
    );
  }

  Widget _buildCompletedTasksView(List<Reminder> completedReminders, Map<String, double> sizes) {
    if (completedReminders.length == 1) {
      // Одна выполненная задача - показываем красиво
      return _buildSingleCompletedTask(completedReminders.first, sizes);
    } else {
      // Несколько выполненных задач - показываем PageView
      return _buildMultipleCompletedTasks(completedReminders, sizes);
    }
  }

  Widget _buildSingleCompletedTask(Reminder reminder, Map<String, double> sizes) {
    final dateParts = _getCurrentDate().split('\n');
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: sizes['horizontalMargin']!, vertical: 8),
      height: sizes['containerHeight']!,
                    decoration: BoxDecoration(
        color: Color(0xFF4CAF50), // Зеленый для выполненных
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x1931873F),
                          blurRadius: 20,
                          offset: Offset(0, 4),
                        )
                      ],
                    ),
                    child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      child: Row(
                        children: [
            // Дата
            Container(
              width: sizes['dateWidth']!,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                    dateParts[0],
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Gilroy',
                      fontSize: sizes['dayFontSize']!,
                                        fontWeight: FontWeight.w600,
                      height: 1.0,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                    dateParts[1],
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Gilroy',
                      fontSize: sizes['monthFontSize']!,
                                        fontWeight: FontWeight.w600,
                      height: 1.0,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
            // Разделитель
                              Container(
              margin: EdgeInsets.symmetric(horizontal: 8),
                                width: 1,
              height: sizes['containerHeight']! * 0.6,
                                color: Colors.white.withOpacity(0.3),
                              ),
            // Фото растения или иконка по умолчанию
            Container(
              width: sizes['containerHeight']! * 0.6,
              height: sizes['containerHeight']! * 0.6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withOpacity(0.2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _getReminderIcon(reminder.type, sizes['containerHeight']! * 0.35),
              ),
            ),
            SizedBox(width: 8),
            // Информация о задаче
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getReminderTypeIcon(reminder.type),
                          style: TextStyle(fontSize: sizes['titleFontSize']!),
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _getReminderTypeDisplayName(reminder.type),
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Gilroy',
                              fontSize: sizes['titleFontSize']!,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.lineThrough,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 2),
                  Flexible(
                    child: Text(
                      _getPlantDisplayName(reminder.plant?.name ?? '', reminder.type),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontFamily: 'Gilroy',
                        fontSize: sizes['subtitleFontSize']!,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.lineThrough,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Галочка выполнения
            Container(
              width: sizes['titleFontSize']! + 6,
              height: sizes['titleFontSize']! + 6,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.check,
                size: sizes['titleFontSize']! - 2,
                color: Color(0xFF4CAF50),
                                    ),
                                  ),
                                ],
                              ),
      ),
    );
  }

  Widget _buildMultipleCompletedTasks(List<Reminder> completedReminders, Map<String, double> sizes) {
    return Container(
      height: sizes['containerHeight']! + 16, // Высота + место для индикаторов
      margin: EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              children: [
          Expanded(
            child: PageView.builder(
              onPageChanged: (index) {
                setState(() {
                  _currentReminderIndex = index;
                });
              },
              itemCount: completedReminders.length,
              itemBuilder: (context, index) {
                return _buildSingleCompletedTask(completedReminders[index], sizes);
              },
            ),
          ),
          // Индикаторы страниц
                                Container(
            padding: EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                completedReminders.length,
                (index) => Container(
                  width: sizes['containerHeight']! * 0.1,
                  height: sizes['containerHeight']! * 0.1,
                  margin: EdgeInsets.symmetric(horizontal: 3),
                                  decoration: BoxDecoration(
                    color: index == _currentReminderIndex 
                        ? Color(0xFF4CAF50)
                        : Color(0xFF4CAF50).withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTasksView(Map<String, double> sizes) {
    final dateParts = _getCurrentDate().split('\n');
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: sizes['horizontalMargin']!, vertical: 8),
      height: sizes['containerHeight']!,
      decoration: BoxDecoration(
        color: Color(0xFF9E9E9E), // Серый цвет для пустого состояния
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Color(0x1931873F),
            blurRadius: 20,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        child: Row(
          children: [
            // Дата
                                Container(
              width: sizes['dateWidth']!,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dateParts[0],
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Gilroy',
                      fontSize: sizes['dayFontSize']!,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    dateParts[1],
                    style: TextStyle(
                                    color: Colors.white,
                      fontFamily: 'Gilroy',
                      fontSize: sizes['monthFontSize']!,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                                  ),
                                ),
            // Разделитель
                                Container(
              margin: EdgeInsets.symmetric(horizontal: 10),
              width: 1,
              height: sizes['containerHeight']! * 0.6,
              color: Colors.white.withOpacity(0.3),
            ),
            // Текст состояния
            Expanded(
              child: Text(
                'Сегодня нет активных напоминаний',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Gilroy',
                  fontSize: sizes['titleFontSize']!,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Иконка
            Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: sizes['titleFontSize']! + 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sizes = _getAdaptiveSizes(context);
        final dateParts = _getCurrentDate().split('\n');
        
        return AnimatedContainer(
          duration: Duration(milliseconds: 500),
          margin: EdgeInsets.symmetric(horizontal: sizes['horizontalMargin']!, vertical: 8),
          height: sizes['containerHeight']!,
                                  decoration: BoxDecoration(
            color: reminder.isCompleted 
                ? Color(0xFF4CAF50) // Зеленый если выполнено
                : Color(0xFF63A36C), // Обычный зеленый
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Color(0x1931873F),
                blurRadius: 20,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: Row(
              children: [
                // Дата
                Container(
                  width: sizes['dateWidth']!,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // День
                      Text(
                        dateParts[0],
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Gilroy',
                          fontSize: sizes['dayFontSize']!,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Месяц
                      Text(
                        dateParts[1],
                        style: TextStyle(
                                    color: Colors.white,
                          fontFamily: 'Gilroy',
                          fontSize: sizes['monthFontSize']!,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Разделитель
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 10),
                  width: 1,
                  height: sizes['containerHeight']! * 0.6,
                  color: Colors.white.withOpacity(0.3),
                ),
                // Контент напоминания
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            _getReminderTypeIcon(reminder.type),
                            style: TextStyle(fontSize: sizes['titleFontSize']!),
                                ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _getReminderTypeDisplayName(reminder.type),
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Gilroy',
                                fontSize: sizes['titleFontSize']!,
                                fontWeight: FontWeight.w600,
                                decoration: reminder.isCompleted 
                                    ? TextDecoration.lineThrough 
                                    : TextDecoration.none,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                                                                      Text(
                        _getPlantDisplayName(reminder.plant?.name ?? '', reminder.type),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontFamily: 'Gilroy',
                          fontSize: sizes['subtitleFontSize']!,
                          fontWeight: FontWeight.w500,
                          decoration: reminder.isCompleted 
                              ? TextDecoration.lineThrough 
                              : TextDecoration.none,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    ),
                  ),
                // Чекбокс для отметки выполнения
                GestureDetector(
                  onTap: () => _toggleReminderCompletion(reminder),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    width: sizes['titleFontSize']! + 6,
                    height: sizes['titleFontSize']! + 6,
                    decoration: BoxDecoration(
                      color: reminder.isCompleted 
                          ? Colors.white 
                          : Colors.transparent,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: reminder.isCompleted 
                        ? Icon(
                            Icons.check,
                            size: sizes['titleFontSize']! - 2,
                            color: Color(0xFF4CAF50),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizes = _getAdaptiveSizes(context);
    
    if (_isLoading) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: sizes['horizontalMargin']!, vertical: 8),
        height: sizes['containerHeight']!,
        decoration: BoxDecoration(
          color: Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: SizedBox(
            width: sizes['containerHeight']! * 0.3,
            height: sizes['containerHeight']! * 0.3,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF63A36C)),
            ),
          ),
        ),
      );
    }

    // Детальное логирование для отладки
    print('🏠 === ОТЛАДКА ОТОБРАЖЕНИЯ НАПОМИНАНИЙ ===');
    print('📊 Всего напоминаний на сегодня: ${_todayReminders.length}');
    _todayReminders.asMap().forEach((index, reminder) {
      print('📋 Напоминание ${index + 1}:');
      print('   • ID: ${reminder.id}');
      print('   • Тип: ${reminder.type}');
      print('   • Активно: ${reminder.isActive}');
      print('   • Выполнено: ${reminder.isCompleted}');
      print('   • Plant ID: ${reminder.plantId}');
      print('   • Название растения: ${reminder.plant?.name ?? 'нет названия'}');
    });

    // Фильтруем невыполненные напоминания для отображения
    final activeReminders = _todayReminders.where((r) => !r.isCompleted).toList();
    
    print('🔍 Активных (невыполненных) напоминаний: ${activeReminders.length}');
    activeReminders.asMap().forEach((index, reminder) {
      print('✅ Активное напоминание ${index + 1}: ${reminder.type} - ${reminder.plant?.name ?? reminder.plantId}');
    });
    
    if (activeReminders.isEmpty) {
      print('⚠️ Нет активных напоминаний, показываем пустое состояние');
      return _buildEmptyState();
    }

    print('✅ Показываем ${activeReminders.length} активных напоминаний');
    print('🏠 === КОНЕЦ ОТЛАДКИ ===\n');

    // Если одно напоминание - показываем без PageView
    if (activeReminders.length == 1) {
      return _buildReminderCard(activeReminders.first);
    }

    // Если несколько - показываем с PageView для свайпа
    return Container(
      height: sizes['containerHeight']! + 16, // Высота контейнера + место для индикаторов
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentReminderIndex = index;
                });
              },
              itemCount: activeReminders.length,
              itemBuilder: (context, index) {
                return _buildReminderCard(activeReminders[index]);
              },
            ),
          ),
          // Индикаторы страниц
          if (activeReminders.length > 1)
            Container(
              padding: EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  activeReminders.length,
                  (index) => Container(
                    width: sizes['containerHeight']! * 0.1,
                    height: sizes['containerHeight']! * 0.1,
                    margin: EdgeInsets.symmetric(horizontal: 3),
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
      ),
    );
  }
}
