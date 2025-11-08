import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';
import '../services/api/reminder_service.dart';
import '../widgets/reminder_management_dialog.dart';
import '../plant_result/set_reminder_screen.dart';

class DayDetailPage extends StatefulWidget {
  final DateTime selectedDate;
  
  const DayDetailPage({Key? key, required this.selectedDate}) : super(key: key);

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<DayDetailPage> {
  static const String baseUrl = 'http://89.110.92.227:3002';
  
  final ReminderService _reminderService = ReminderService();
  List<Reminder> _dayReminders = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeDateFormatting();
    _loadDayReminders();
  }
  
  Future<void> _initializeDateFormatting() async {
    await initializeDateFormatting('ru_RU', null);
  }

  String _convertToFullUrl(String imageUrl) {
    if (imageUrl.isEmpty) return '';
    
    if (imageUrl.startsWith('/uploads/')) {
      return '$baseUrl$imageUrl';
    }
    
    return imageUrl;
  }

  String? _getPlantImageUrl(Reminder reminder) {
    if (reminder.plant?.images.isNotEmpty == true) {
      final images = reminder.plant!.images;
      final imageKeys = ['photo', 'user_image', 'original', 'main_image', 'thumbnail', 'image', 'picture'];
      
      for (String key in imageKeys) {
        if (images[key] != null && images[key]!.isNotEmpty) {
          return _convertToFullUrl(images[key]!);
        }
      }
      
      for (var entry in images.entries) {
        if (entry.value.isNotEmpty) {
          return _convertToFullUrl(entry.value);
        }
      }
    }
    
    return null;
  }

  Future<void> _loadDayReminders() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Необходимо войти в аккаунт';
        });
        return;
      }
      
      // Попробуем получить напоминания через новый API с поддержкой интервалов
      List<Reminder> finalReminders = [];
      
      try {
        final statusReminders = await _reminderService.getRemindersWithStatus(
          token,
          date: DateFormat('yyyy-MM-dd').format(widget.selectedDate),
        );
        
        if (statusReminders.isNotEmpty) {
          finalReminders = statusReminders;
        } else {
          final allReminders = await _reminderService.getReminders(token);
          finalReminders = _filterRemindersForDate(allReminders, widget.selectedDate);
        }
      } catch (e) {
        final allReminders = await _reminderService.getReminders(token);
        finalReminders = _filterRemindersForDate(allReminders, widget.selectedDate);
      }

      // финальная сортировка по времени
      finalReminders.sort((a, b) => a.date.compareTo(b.date));
      
      if (!mounted) return;
      setState(() {
        _dayReminders = finalReminders;
        _isLoading = false;
      });
      
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Не удалось загрузить напоминания';
      });
    }
  }

  Future<void> _toggleReminderCompletion(Reminder reminder) async {
    print('✅ === ПЕРЕКЛЮЧЕНИЕ ВЫПОЛНЕНИЯ НАПОМИНАНИЯ ===');
    print('🆔 ID: ${reminder.id}');
    print('📊 Текущее состояние: ${reminder.isCompleted ? "Выполнено" : "Не выполнено"}');
    print('📅 Дата: ${DateFormat('yyyy-MM-dd').format(widget.selectedDate)}');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty || reminder.id == null) {
        print('❌ Токен или ID отсутствует');
        return;
      }

      print('📤 Отправляем запрос на ${reminder.isCompleted ? "отмену выполнения" : "выполнение"}...');
      final success = reminder.isCompleted 
        ? await _reminderService.uncompleteReminder(
            token, 
            reminder.id!,
            completionDate: DateFormat('yyyy-MM-dd').format(widget.selectedDate),
          )
        : await _reminderService.completeReminder(
            token, 
            reminder.id!,
            note: 'Выполнено из календаря',
            completionDate: DateFormat('yyyy-MM-dd').format(widget.selectedDate),
          );

      print('📥 Результат: ${success ? "Успех" : "Ошибка"}');

      if (success && mounted) {
        print('✅ Успешно, перезагружаем список напоминаний...');
        // Перезагружаем весь список вместо локального обновления
        await _loadDayReminders();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(reminder.isCompleted ? 'Отменено выполнение' : 'Напоминание выполнено!'),
              backgroundColor: Color(0xFF4CAF50),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('❌ Не удалось переключить состояние');
      }
    } catch (e) {
      print('❌ Исключение: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при выполнении напоминания: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
    print('✅ === КОНЕЦ ПЕРЕКЛЮЧЕНИЯ ВЫПОЛНЕНИЯ ===\n');
  }

  void _showReminderManagementDialog(Reminder reminder) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReminderManagementDialog(
          reminder: reminder,
          selectedDate: widget.selectedDate,
          onReminderUpdated: () {
            // Перезагружаем список напоминаний после обновления
            _loadDayReminders();
          },
          onReminderDeleted: () {
            // Перезагружаем список напоминаний после удаления
            _loadDayReminders();
          },
          onReminderCompleted: () {
            // Перезагружаем список напоминаний после выполнения
            _loadDayReminders();
          },
        );
      },
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
    
    const typeNames = {
      'watering': 'Полив',
      'spraying': 'Орошение', 
      'fertilizing': 'Удобрение',
      'transplanting': 'Пересадка',
      'pruning': 'Обрезка',
      'pest_control': 'От вредителей',
      'disease_control': 'От болезней',
      'disease_treatment': 'От болезней',
      'rotation': 'Вращение',
      'custom_task': 'Моя задача',
    };
    return typeNames[type] ?? type;
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
    
    const typeIcons = {
      'watering': '💧',
      'spraying': '🌿',
      'fertilizing': '🌱',
      'transplanting': '🪴',
      'pruning': '✂️',
      'pest_control': '🐛',
      'disease_control': '🏥',
      'disease_treatment': '🏥',
      'rotation': '🔄',
      'custom_task': '📋',
    };
    return typeIcons[type] ?? '📋';
  }

  String _formatDateSafely(DateTime date) {
    try {
      return DateFormat('d MMMM yyyy', 'ru_RU').format(date);
    } catch (e) {
      // Fallback на стандартное форматирование без локализации
      final monthNames = [
        'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
        'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
      ];
      return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F8EC),
      appBar: AppBar(
        title: Text(
          _formatDateSafely(widget.selectedDate),
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: _dayReminders.isNotEmpty 
        ? FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SetReminderScreen(
                    openFromWatering: false,
                    forceAddMode: true,
                    isPlantAlreadyInCollection: true,
                    fromScanHistory: true,
                    hideLikeButton: true,
                  ),
                ),
              );
              _loadDayReminders();
            },
            backgroundColor: Color(0xFF63A36C),
            foregroundColor: Colors.white,
            icon: Image.asset(
              'assets/images/kalendar/plusik.png',
              width: 20,
              height: 20,
              color: Colors.white,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.add, color: Colors.white);
              },
            ),
            label: Text(
              'Новая задача',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        : null,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF63A36C)))
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : _dayReminders.isEmpty
                  ? _buildEmptyDayWidget()
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: _dayReminders.length,
                      itemBuilder: (context, index) {
                        return _buildReminderCard(_dayReminders[index]);
                      },
                    ),
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    final plantImageUrl = _getPlantImageUrl(reminder);
    // Используем эффективное время вместо оригинального
    final DateTime remindTime = reminder.getEffectiveDateTime();
    String timeString = '';
    timeString = '${remindTime.hour.toString().padLeft(2, '0')}:${remindTime.minute.toString().padLeft(2, '0')}';
    
    print('🎯 Отображение времени в карточке: ${reminder.isModifiedForThisDate ? "изменено" : "оригинальное"} время $timeString');

    final bool isCompleted = reminder.isCompleted;

    return GestureDetector(
      onTap: () => _showReminderManagementDialog(reminder),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted ? Color(0xFFF5F5F5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isCompleted ? Color(0x10000000) : Color(0x1931873F),
              blurRadius: 8,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            if (plantImageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  plantImageUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildFallbackIcon(reminder.type, note: reminder.note),
                ),
              )
            else
              _buildFallbackIcon(reminder.type, note: reminder.note),
          
          SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getReminderTypeName(reminder.type, note: reminder.note),
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? Colors.grey[600] : Colors.black,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  reminder.plant?.name ?? 'Растение не указано',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 14,
                    color: isCompleted ? Colors.grey[500] : Colors.grey[700],
                     decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                 SizedBox(height: 4),
                Text(
                  timeString,
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isCompleted ? Colors.grey[500] : Color(0xFF63A36C),
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(width: 12),

          // Кнопки управления
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Кнопка редактирования
              GestureDetector(
                onTap: () => _showReminderManagementDialog(reminder),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Icon(
                    Icons.edit,
                    color: Colors.blue,
                    size: 18,
                  ),
                ),
              ),
              SizedBox(width: 8),
              // Кнопка выполнения
              GestureDetector(
                onTap: () => _toggleReminderCompletion(reminder),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  width: 90,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.white : Color(0xFF63A36C),
                    borderRadius: BorderRadius.circular(20),
                    border: isCompleted ? Border.all(color: Colors.grey[300]!) : null,
                    boxShadow: isCompleted ? [] : [
                      BoxShadow(
                        color: Color(0x2963A36C),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      )
                    ],
                  ),
                  child: Center(
                    child: Text(
                      isCompleted ? '✓ Готово' : 'Готово',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? Colors.grey[600] : Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildFallbackIcon(String type, {String? note}) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          _getReminderTypeIcon(type, note: note),
          style: TextStyle(fontSize: 28),
        ),
      ),
    );
  }

  // Фильтруем напоминания на конкретную дату, учитывая еженедельные повторения
  List<Reminder> _filterRemindersForDate(List<Reminder> reminders, DateTime date) {
    final targetDate = DateTime.utc(date.year, date.month, date.day);
    final List<Reminder> result = [];

    for (final reminder in reminders) {
      if (!reminder.isActive) continue;

      final reminderDate = DateTime.utc(
        reminder.date.year,
        reminder.date.month,
        reminder.date.day,
      );

      // 1) Точное совпадение даты
      if (reminderDate == targetDate) {
        result.add(reminder);
        continue;
      }

      // 2) Еженедельные повторения (старая система)
      if (reminder.repeatWeekly && reminder.daysOfWeek.isNotEmpty) {
        if (targetDate.isAfter(reminderDate) || targetDate == reminderDate) {
          final targetWeekday = targetDate.weekday; // 1=Пн, 7=Вс
          final apiWeekday = targetWeekday == 7 ? 0 : targetWeekday; // 0=Пн в API

          if (reminder.daysOfWeek.contains(apiWeekday)) {
            result.add(reminder);
          }
        }
      }

      // 3) НОВАЯ ЛОГИКА: Интервальные напоминания
      if (reminder.intervalDays != null && reminder.intervalDays! > 0) {
        // Каждые N дней
        if (targetDate.isAfter(reminderDate) || targetDate == reminderDate) {
          final daysDiff = targetDate.difference(reminderDate).inDays;
          if (daysDiff % reminder.intervalDays! == 0) {
            result.add(reminder);
  
          }
        }
      } else if (reminder.intervalWeeks != null && reminder.intervalWeeks! > 0) {
        // Каждые N недель (в тот же день недели)
        if (targetDate.isAfter(reminderDate) || targetDate == reminderDate) {
          final daysDiff = targetDate.difference(reminderDate).inDays;
          final weeksDiff = (daysDiff / 7).floor();
          
          if (weeksDiff % reminder.intervalWeeks! == 0 && daysDiff % 7 == 0) {
            result.add(reminder);
  
          }
        }
      } else if (reminder.intervalMonths != null && reminder.intervalMonths! > 0) {
        // Каждые N месяцев (в тот же день месяца)
        if (targetDate.isAfter(reminderDate) || targetDate == reminderDate) {
          final monthsDiff = (targetDate.year - reminderDate.year) * 12 + 
                            (targetDate.month - reminderDate.month);
          
          if (monthsDiff % reminder.intervalMonths! == 0 && 
              targetDate.day == reminderDate.day) {
            result.add(reminder);
  
          }
        }
      }
    }

    // Сортируем по времени напоминания (если присутствует)
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  Widget _buildEmptyDayWidget() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Иконка календаря
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Color(0xFF63A36C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.event_available,
                size: 40,
                color: Color(0xFF63A36C),
              ),
            ),
            
            SizedBox(height: 24),
            
            // Текст сообщения
            Text(
              'На этот день нет запланированных работ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            
            SizedBox(height: 32),
            
            // Кнопка "Новая задача"
            ElevatedButton(
              onPressed: () async {
                // Переходим к экрану создания напоминания
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SetReminderScreen(
                      openFromWatering: false,
                      forceAddMode: true,
                      isPlantAlreadyInCollection: true,
                      fromScanHistory: true,
                      hideLikeButton: true,
                      // Можно передать выбранную дату для установки времени
                    ),
                  ),
                );
                
                // После возврата обновляем список напоминаний
                _loadDayReminders();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF63A36C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
                padding: EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 25,
                ),
                elevation: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Новая задача',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Gilroy',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 10),
                  Image.asset(
                    'assets/images/kalendar/plusik.png',
                    width: 20,
                    height: 20,
                    color: Colors.white,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback иконка, если изображение не найдено
                      return Icon(
                        Icons.add_circle_outline,
                        size: 20,
                        color: Colors.white,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 