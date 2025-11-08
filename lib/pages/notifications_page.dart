import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api/reminder_service.dart';
import '../models/reminder.dart';
import '../services/logger.dart';
import '../services/plant_events.dart'; // ИСПРАВЛЕНИЕ: Добавляем импорт PlantEvents

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with TickerProviderStateMixin {
  static const String baseUrl = 'http://89.110.92.227:3002';
  
  bool _isLoading = true;
  List<Reminder> _allReminders = [];
  List<Reminder> _todayReminders = [];
  List<Reminder> _upcomingReminders = [];
  String _errorMessage = '';
  
  late TabController _tabController;
  final ReminderService _reminderService = ReminderService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReminders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Очистка маркеров из заметки для отображения
  String _cleanNoteText(String? note) {
    if (note == null || note.isEmpty) return '';
    
    // Убираем маркеры [ROTATION] и [CUSTOM_TASK]
    String cleaned = note;
    if (cleaned.startsWith('[ROTATION]')) {
      cleaned = cleaned.replaceFirst('[ROTATION]', '').trim();
    } else if (cleaned.startsWith('[CUSTOM_TASK]')) {
      cleaned = cleaned.replaceFirst('[CUSTOM_TASK]', '').trim();
    }
    
    return cleaned;
  }

  Future<void> _loadReminders() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Необходимо войти в аккаунт';
        });
        return;
      }
      
      AppLogger.ui('Загружаем напоминания');
      
      // Загружаем все типы напоминаний параллельно
      // Для "Сегодня" используем getRemindersWithStatus чтобы получить статус выполнения
      final futures = await Future.wait([
        _reminderService.getReminders(token),
        _reminderService.getRemindersWithStatus(token), // Сегодняшние со статусом
        _reminderService.getUpcomingReminders(token, days: 7),
      ]);
      
      setState(() {
        _allReminders = futures[0];
        _todayReminders = futures[1];
        _upcomingReminders = futures[2];
        _isLoading = false;
      });
      
      // Добавляем детальную отладочную информацию
      print('🔍 === АНАЛИЗ ЗАГРУЖЕННЫХ НАПОМИНАНИЙ ===');
      print('📊 Общее количество напоминаний: ${_allReminders.length}');
      print('📊 Сегодняшних напоминаний: ${_todayReminders.length}');
      print('📊 Ближайших напоминаний: ${_upcomingReminders.length}');
      
      if (_todayReminders.isNotEmpty) {
        print('✅ Первое сегодняшнее напоминание:');
        final first = _todayReminders.first;
        print('   • ID: ${first.id}');
        print('   • Тип: ${first.type}');
        print('   • Растение ID: ${first.plantId}');
        print('   • Активно: ${first.isActive}');
        print('   • Выполнено: ${first.isCompleted}');
        print('   • Дата: ${first.date}');
        print('   • Время дня: ${first.timeOfDay}');
        print('   • Объект растения: ${first.plant?.toString() ?? "null"}');
        if (first.completion != null) {
          print('   • Данные выполнения: выполнено в ${first.completion!.completedAt}');
          if (first.completion!.note != null) {
            print('   • Заметка: ${first.completion!.note}');
          }
        }
      } else {
        print('❌ Список сегодняшних напоминаний пустой!');
      }
      
      AppLogger.ui('Загружено напоминаний: все=${_allReminders.length}, сегодня=${_todayReminders.length}, ближайшие=${_upcomingReminders.length}');
      
    } catch (e) {
      AppLogger.error('Ошибка при загрузке напоминаний: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Не удалось загрузить уведомления';
      });
    }
  }

  Future<void> _toggleReminderActive(Reminder reminder) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        _showMessage('Необходимо войти в аккаунт', isError: true);
        return;
      }
      
      if (reminder.id == null) {
        _showMessage('Невозможно изменить статус напоминания', isError: true);
        return;
      }
      
      final success = await _reminderService.toggleReminderActive(token, reminder.id!);
      
      if (success) {
        // Обновляем локальный список
        setState(() {
          _updateReminderInLists(reminder.copyWith(isActive: !reminder.isActive));
        });
        
        _showMessage(reminder.isActive ? 'Напоминание отключено' : 'Напоминание включено');
      } else {
        _showMessage('Ошибка при изменении статуса', isError: true);
      }
    } catch (e) {
      AppLogger.error('Ошибка при переключении статуса напоминания: $e');
      _showMessage('Ошибка при изменении статуса', isError: true);
    }
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        _showMessage('Необходимо войти в аккаунт', isError: true);
        return;
      }
      
      if (reminder.id == null) {
        _showMessage('Невозможно удалить напоминание', isError: true);
        return;
      }
      
      final success = await _reminderService.deleteReminder(token, reminder.id!);
      
      if (success) {
        // ИСПРАВЛЕНИЕ: Отправляем событие об удалении напоминания
        PlantEvents().notifyReminderDeleted(reminder.id!, plantId: reminder.plantId);
        
        // Удаляем из всех списков
        setState(() {
          _allReminders.removeWhere((r) => r.id == reminder.id);
          _todayReminders.removeWhere((r) => r.id == reminder.id);
          _upcomingReminders.removeWhere((r) => r.id == reminder.id);
        });
        
        _showMessage('Напоминание удалено');
      } else {
        _showMessage('Ошибка при удалении', isError: true);
      }
    } catch (e) {
      AppLogger.error('Ошибка при удалении напоминания: $e');
      _showMessage('Ошибка при удалении', isError: true);
    }
  }

  // Отметить напоминание как выполненное
  Future<void> _completeReminder(Reminder reminder) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        _showMessage('Необходимо войти в аккаунт', isError: true);
        return;
      }
      
      if (reminder.id == null) {
        _showMessage('Невозможно отметить напоминание', isError: true);
        return;
      }
      
      final success = await _reminderService.completeReminder(
        token, 
        reminder.id!,
        note: 'Выполнено через приложение',
      );
      
      if (success) {
        // Обновляем локальный список
        setState(() {
          _updateReminderInLists(reminder.copyWith(isCompleted: true));
        });
        
        _showMessage('✅ Действие отмечено как выполненное');
        
        // Обновляем сегодняшние напоминания чтобы получить актуальный статус
        _refreshTodayReminders();
      } else {
        _showMessage('Ошибка при отметке выполнения', isError: true);
      }
    } catch (e) {
      AppLogger.error('Ошибка при отметке выполнения: $e');
      _showMessage('Ошибка при отметке выполнения', isError: true);
    }
  }

  // Отменить выполнение напоминания
  Future<void> _uncompleteReminder(Reminder reminder) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        _showMessage('Необходимо войти в аккаунт', isError: true);
        return;
      }
      
      if (reminder.id == null) {
        _showMessage('Невозможно отменить выполнение', isError: true);
        return;
      }
      
      final success = await _reminderService.uncompleteReminder(token, reminder.id!);
      
      if (success) {
        // Обновляем локальный список
        setState(() {
          _updateReminderInLists(reminder.copyWith(isCompleted: false, completion: null));
        });
        
        _showMessage('↩️ Выполнение отменено');
        
        // Обновляем сегодняшние напоминания
        _refreshTodayReminders();
      } else {
        _showMessage('Ошибка при отмене выполнения', isError: true);
      }
    } catch (e) {
      AppLogger.error('Ошибка при отмене выполнения: $e');
      _showMessage('Ошибка при отмене выполнения', isError: true);
    }
  }

  // Обновить только сегодняшние напоминания
  Future<void> _refreshTodayReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) return;
      
      final todayReminders = await _reminderService.getRemindersWithStatus(token);
      
      setState(() {
        _todayReminders = todayReminders;
      });
    } catch (e) {
      AppLogger.error('Ошибка при обновлении сегодняшних напоминаний: $e');
    }
  }

  // Проверяем, находимся ли мы на вкладке "Сегодня"
  bool _isFromTodayTab() {
    return _tabController.index == 0;
  }

  void _updateReminderInLists(Reminder updatedReminder) {
    // Обновляем во всех списках
    _updateReminderInList(_allReminders, updatedReminder);
    _updateReminderInList(_todayReminders, updatedReminder);
    _updateReminderInList(_upcomingReminders, updatedReminder);
  }

  void _updateReminderInList(List<Reminder> list, Reminder updatedReminder) {
    final index = list.indexWhere((r) => r.id == updatedReminder.id);
    if (index != -1) {
      list[index] = updatedReminder;
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Color(0xFF63A36C),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Reminder reminder) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Удалить напоминание?',
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Напоминание "${_getReminderTypeName(reminder.type, note: reminder.note)}" будет удалено навсегда.',
            style: TextStyle(
              fontFamily: 'Gilroy',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Отмена',
                style: TextStyle(
                  color: Color(0xFF63A36C),
                  fontFamily: 'Gilroy',
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteReminder(reminder);
              },
              child: Text(
                'Удалить',
                style: TextStyle(
                  color: Colors.red,
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(0.00, -1.00),
            end: Alignment(0, 1),
            colors: [Color(0xFFEAF5DA), Color(0xFFB6DFA3)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Заголовок
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: SvgPicture.asset(
                        'assets/images/favorites/back_arrow.svg',
                        width: 24,
                        height: 24,
                        color: Color(0xFF63A36C),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 12 : 16),
                    Text(
                      'Уведомления',
                      style: TextStyle(
                        color: Color(0xFF1F2024),
                        fontSize: isSmallScreen ? 16 : 18,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.005,
                      ),
                    ),
                  ],
                ),
              ),

              // Табы
              Container(
                margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 22),
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1931873F),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: 'Сегодня'),
                    Tab(text: 'Ближайшие'),
                    Tab(text: 'Все'),
                  ],
                  labelColor: Colors.white,
                  unselectedLabelColor: Color(0xFF63A36C),
                  labelStyle: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w600,
                    fontSize: isSmallScreen ? 12 : 14,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w500,
                    fontSize: isSmallScreen ? 12 : 14,
                  ),
                  indicator: BoxDecoration(
                    color: Color(0xFF63A36C),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  dividerColor: Colors.transparent,
                ),
              ),

              SizedBox(height: isSmallScreen ? 12 : 16),

              // Основной контент
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 22),
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1931873F),
                        blurRadius: 20,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF63A36C),
                          ),
                        )
                      : _errorMessage.isNotEmpty
                          ? _buildErrorState(isSmallScreen)
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _buildRemindersList(_todayReminders, isSmallScreen, 'Нет напоминаний на сегодня'),
                                _buildRemindersList(_upcomingReminders, isSmallScreen, 'Нет ближайших напоминаний'),
                                _buildRemindersList(_allReminders, isSmallScreen, 'У вас пока нет напоминаний'),
                              ],
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isSmallScreen) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red,
          ),
          SizedBox(height: 16),
          Text(
            _errorMessage,
            style: TextStyle(
              color: Colors.red,
              fontSize: 16,
              fontFamily: 'Gilroy',
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadReminders,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF63A36C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Повторить',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersList(List<Reminder> reminders, bool isSmallScreen, String emptyMessage) {
    if (reminders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_outlined,
              size: 48,
              color: Color(0xFF63A36C).withOpacity(0.5),
            ),
            SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                color: Color(0xFF63A36C),
                fontSize: 16,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Создайте напоминания для ухода\nза вашими растениями',
              style: TextStyle(
                color: Color(0xFF63A36C).withOpacity(0.7),
                fontSize: 14,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReminders,
      color: Color(0xFF63A36C),
      child: ListView.builder(
        itemCount: reminders.length,
        itemBuilder: (context, index) {
          final reminder = reminders[index];
          return _buildReminderItem(reminder, isSmallScreen);
        },
      ),
    );
  }

  Widget _buildReminderItem(Reminder reminder, bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: reminder.isActive ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: reminder.isActive ? Color(0xFF63A36C).withOpacity(0.2) : Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: reminder.isActive ? [
          BoxShadow(
            color: Color(0x1031873F),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок с переключателем
          Row(
            children: [
              // Иконка типа напоминания
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getReminderTypeColor(reminder.type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    _getReminderTypeIcon(reminder.type, note: reminder.note),
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ),
              
              SizedBox(width: 12),
              
              // Информация о напоминании
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getReminderTypeName(reminder.type, note: reminder.note),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Gilroy',
                        color: reminder.isActive ? Color(0xFF1F2024) : Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 2),
                    if (reminder.plant?.name != null)
                      Text(
                        reminder.plant!.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Gilroy',
                          color: reminder.isActive ? Color(0xFF63A36C) : Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
              
              // Двойная функциональность: переключатель активности + кнопка выполнения
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Переключатель активности напоминания
                  Switch(
                    value: reminder.isActive,
                    onChanged: (value) => _toggleReminderActive(reminder),
                    activeColor: Color(0xFF63A36C),
                  ),
                  
                  SizedBox(height: 4),
                  
                  // Кнопка выполнения действия (только для сегодняшних)
                  if (_isFromTodayTab())
                    Container(
                      width: 50,
                      height: 24,
                      child: ElevatedButton(
                        onPressed: () => reminder.isCompleted 
                            ? _uncompleteReminder(reminder)
                            : _completeReminder(reminder),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: reminder.isCompleted 
                              ? Color(0xFF4CAF50) 
                              : Color(0xFFE0E0E0),
                          foregroundColor: reminder.isCompleted 
                              ? Colors.white 
                              : Color(0xFF666666),
                          padding: EdgeInsets.zero,
                          minimumSize: Size(50, 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          reminder.isCompleted ? '✓' : '○',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          // Детали напоминания
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: reminder.isActive ? Color(0xFFF0F8EC) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Время
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: reminder.isActive ? Color(0xFF63A36C) : Colors.grey.shade500,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '${_formatTime(reminder.getEffectiveDateTime())} (${_getTimeOfDayName(reminder.timeOfDay)})',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Gilroy',
                        color: reminder.isActive ? Color(0xFF555555) : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 6),
                
                // Дни недели или частота
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: reminder.isActive ? Color(0xFF63A36C) : Colors.grey.shade500,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _getRepeatText(reminder, isUpcoming: _isUpcomingReminder(reminder)),
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Gilroy',
                          color: reminder.isActive ? Color(0xFF555555) : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Заметка, если есть (очищенная от маркеров)
                if (reminder.note != null && reminder.note!.isNotEmpty) ...[
                  () {
                    final cleanedNote = _cleanNoteText(reminder.note);
                    if (cleanedNote.isEmpty) return SizedBox.shrink();
                    
                    return Column(
                      children: [
                        SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.note_outlined,
                              size: 16,
                              color: reminder.isActive ? Color(0xFF63A36C) : Colors.grey.shade500,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                cleanedNote,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'Gilroy',
                                  color: reminder.isActive ? Color(0xFF555555) : Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }(),
                ],
              ],
            ),
          ),
          
          SizedBox(height: 8),
          
          // Кнопка удаления
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showDeleteConfirmation(reminder),
                icon: Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: Colors.red,
                ),
                label: Text(
                  'Удалить',
                  style: TextStyle(
                    color: Colors.red,
                    fontFamily: 'Gilroy',
                    fontSize: 12,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getReminderTypeName(String type, {String? note}) {
    // Проверяем маркеры в note для определения реального типа
    if (note != null) {
      if (note.startsWith('[ROTATION]')) {
        return 'Вращение';
      } else if (note.startsWith('[CUSTOM_TASK]')) {
        return 'Моя задача';
      }
    }
    
    return ReminderTypes.typeNames[type] ?? type;
  }

  String _getReminderTypeIcon(String type, {String? note}) {
    // Проверяем маркеры в note для определения реального типа
    if (note != null) {
      if (note.startsWith('[ROTATION]')) {
        return '🔄';
      } else if (note.startsWith('[CUSTOM_TASK]')) {
        return '📋';
      }
    }
    
    return ReminderTypes.typeIcons[type] ?? '📋';
  }

  Color _getReminderTypeColor(String type) {
    switch (type) {
      case ReminderTypes.watering:
        return Colors.blue;
      case ReminderTypes.spraying:
        return Colors.green;
      case ReminderTypes.fertilizing:
        return Colors.orange;
      case ReminderTypes.transplanting:
        return Colors.brown;
      case ReminderTypes.pruning:
        return Colors.purple;
      case ReminderTypes.pestControl:
        return Colors.red;
      case ReminderTypes.diseaseControl:
        return Colors.amber;
      case ReminderTypes.rotation:
        return Colors.teal;
      case ReminderTypes.customTask:
        return Colors.indigo;
      default:
        return Color(0xFF63A36C);
    }
  }

  String _getTimeOfDayName(String timeOfDay) {
    const timeNames = {
      'morning': 'Утром',
      'afternoon': 'Днем', 
      'evening': 'Вечером',
    };
    return timeNames[timeOfDay] ?? timeOfDay;
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  bool _isUpcomingReminder(Reminder reminder) {
    return _upcomingReminders.any((r) => r.id == reminder.id);
  }

  String _getRepeatText(Reminder reminder, {bool isUpcoming = false}) {
    // Для ближайших напоминаний показываем конкретную дату
    if (isUpcoming) {
      final now = DateTime.now();
      final reminderDate = reminder.date;
      
      // Если дата в пределах недели, показываем день недели и дату
      final difference = reminderDate.difference(now).inDays;
      
      if (difference == 0) {
        return 'Сегодня';
      } else if (difference == 1) {
        return 'Завтра';
      } else if (difference <= 7) {
        final dayNames = ['Воскресенье', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];
        final dayName = dayNames[reminderDate.weekday % 7];
        return '$dayName, ${reminderDate.day}.${reminderDate.month.toString().padLeft(2, '0')}';
      } else {
        return '${reminderDate.day}.${reminderDate.month.toString().padLeft(2, '0')}.${reminderDate.year}';
      }
    }
    
    // Стандартная логика для повторяющихся напоминаний
    if (reminder.repeatWeekly) {
      return 'Еженедельно';
    } else if (reminder.daysOfWeek.length == 7) {
      return 'Ежедневно';
    } else if (reminder.daysOfWeek.length == 1) {
      final dayNames = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
      final dayName = dayNames[reminder.daysOfWeek.first];
      return 'Каждый $dayName';
    } else {
      final dayNames = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
      final selectedDays = reminder.daysOfWeek.map((day) => dayNames[day]).join(', ');
      return selectedDays;
    }
  }
} 