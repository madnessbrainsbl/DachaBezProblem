import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';
import '../services/api/reminder_service.dart';
import '../services/logger.dart';
import '../services/plant_events.dart';
import '../plant_result/set_reminder_screen.dart';

class ReminderManagementDialog extends StatefulWidget {
  final Reminder reminder;
  final DateTime selectedDate;
  final VoidCallback onReminderUpdated;
  final VoidCallback onReminderDeleted;
  final VoidCallback onReminderCompleted;

  const ReminderManagementDialog({
    Key? key,
    required this.reminder,
    required this.selectedDate,
    required this.onReminderUpdated,
    required this.onReminderDeleted,
    required this.onReminderCompleted,
  }) : super(key: key);

  @override
  State<ReminderManagementDialog> createState() => _ReminderManagementDialogState();
}

class _ReminderManagementDialogState extends State<ReminderManagementDialog> {
  final ReminderService _reminderService = ReminderService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    print('🎬 === ИНИЦИАЛИЗАЦИЯ ДИАЛОГА УПРАВЛЕНИЯ НАПОМИНАНИЯМИ ===');
    print('🆔 ID напоминания: ${widget.reminder.id}');
    print('📅 Выбранная дата: ${widget.selectedDate}');
    print('🔧 Тип напоминания: ${widget.reminder.type}');
    print('⏰ Время напоминания: ${widget.reminder.date}');
    print('🌱 Растение: ${widget.reminder.plantId}');
    print('📝 Заметка: ${widget.reminder.note}');
    print('🎬 === КОНЕЦ ИНИЦИАЛИЗАЦИИ ===\n');
  }

  String _getReminderTypeName(String type) {
    // Проверяем маркеры в note для определения реального типа
    if (widget.reminder.note != null) {
      if (widget.reminder.note!.startsWith('[ROTATION]')) {
        return 'Вращение';
      } else if (widget.reminder.note!.startsWith('[CUSTOM_TASK]')) {
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

  String _getReminderTypeIcon(String type) {
    // Проверяем маркеры в note для определения реального типа
    if (widget.reminder.note != null) {
      if (widget.reminder.note!.startsWith('[ROTATION]')) {
        return '🔄';
      } else if (widget.reminder.note!.startsWith('[CUSTOM_TASK]')) {
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

  String _getTimeOfDayName(String timeOfDay) {
    const timeNames = {
      'morning': 'Утром',
      'afternoon': 'Днём',
      'evening': 'Вечером',
    };
    return timeNames[timeOfDay] ?? timeOfDay;
  }

  String _getRepeatDescription() {
    if (widget.reminder.intervalDays != null && widget.reminder.intervalDays! > 0) {
      return 'Каждые ${widget.reminder.intervalDays} дней';
    } else if (widget.reminder.intervalWeeks != null && widget.reminder.intervalWeeks! > 0) {
      return 'Каждые ${widget.reminder.intervalWeeks} недель';
    } else if (widget.reminder.intervalMonths != null && widget.reminder.intervalMonths! > 0) {
      return 'Каждые ${widget.reminder.intervalMonths} месяцев';
    } else if (widget.reminder.repeatWeekly && widget.reminder.daysOfWeek.isNotEmpty) {
      final weekDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
      final selectedDays = widget.reminder.daysOfWeek.map((day) {
        final adjustedDay = day == 0 ? 6 : day - 1; // API: 0=Вс, 1=Пн -> UI: 0=Пн, 6=Вс
        return weekDays[adjustedDay];
      }).join(', ');
      return 'Еженедельно: $selectedDays';
    } else {
      return 'Однократно';
    }
  }

  Future<void> _handleMarkAsComplete() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        throw Exception('Токен не найден');
      }

      // Выполняем задачу с указанием даты
      final success = await _reminderService.completeReminder(
        token, 
        widget.reminder.id!,
        completionDate: DateFormat('yyyy-MM-dd').format(widget.selectedDate),
      );
      
      if (success) {
        widget.onReminderCompleted();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Задача выполнена!'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Не удалось выполнить задачу');
      }
    } catch (e) {
      AppLogger.error('Ошибка при выполнении задачи: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при выполнении задачи'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDeleteReminder(bool deleteAll) async {
    print('🗑️ === ОБРАБОТКА УДАЛЕНИЯ НАПОМИНАНИЯ ===');
    print('🔧 Удалить все: $deleteAll');
    print('🆔 ID напоминания: ${widget.reminder.id}');
    
    // Проверяем наличие ID
    if (widget.reminder.id == null || widget.reminder.id!.isEmpty) {
      print('⚠️ ОШИБКА: ID напоминания отсутствует');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Невозможно удалить: ID напоминания отсутствует'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Показываем подтверждение
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          deleteAll ? 'Удалить все повторения?' : 'Удалить только эту задачу?',
          style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.bold),
        ),
        content: Text(
          deleteAll 
            ? 'Это действие удалит задачу во всех днях, включая будущие. Если вы просто выполнили задачу, лучше нажать "Готово".'
            : 'Будет удалена только задача на ${DateFormat('dd.MM.yyyy').format(widget.selectedDate)}.',
          style: TextStyle(fontFamily: 'Gilroy'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Отмена',
              style: TextStyle(fontFamily: 'Gilroy', color: Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(
              'Удалить',
              style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        throw Exception('Токен не найден');
      }

      if (deleteAll) {
        print('🗑️ Удаление всех повторений напоминания ${widget.reminder.id}');
        // Удаляем напоминание полностью
        final success = await _reminderService.deleteReminder(token, widget.reminder.id!);
        
        if (success) {
          print('✅ Напоминание успешно удалено');
          widget.onReminderDeleted();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Задача удалена полностью'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          throw Exception('Не удалось удалить задачу');
        }
      } else {
        print('🗑️ Удаление напоминания только для ${widget.selectedDate}');
        // Создаем исключение для конкретной даты
        final success = await _reminderService.deleteReminderForSpecificDay(
          token, 
          widget.reminder.id!,
          widget.selectedDate,
        );
        
        if (success) {
          print('✅ Напоминание успешно удалено для конкретного дня');
          widget.onReminderDeleted();
          
          // Уведомляем календарь об удалении
          PlantEvents().notifyReminderDeleted(
            widget.reminder.id!,
            plantId: widget.reminder.plantId,
          );
          
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Задача удалена только для ${DateFormat('dd.MM.yyyy').format(widget.selectedDate)}'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          throw Exception('Не удалось удалить задачу для конкретного дня');
        }
      }
    } catch (e) {
      print('❌ Ошибка при удалении: $e');
      AppLogger.error('Ошибка при удалении задачи: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при удалении задачи: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
    print('🗑️ === КОНЕЦ ОБРАБОТКИ УДАЛЕНИЯ ===\n');
  }

  void _handleEditReminder(bool editAll) {
    print('🎛️ === ОБРАБОТКА РЕДАКТИРОВАНИЯ НАПОМИНАНИЯ ===');
    print('🔧 Редактировать все: $editAll');
    print('🆔 ID напоминания: ${widget.reminder.id}');
    print('📅 Выбранная дата: ${widget.selectedDate}');
    print('🌱 Данные растения: ${widget.reminder.plant}');
    
    if (editAll) {
      print('📝 Редактирование всех повторений - переход на экран редактирования');
      
      // Проверяем наличие данных растения
      if (widget.reminder.plant == null) {
        print('⚠️ ОШИБКА: Данные растения отсутствуют');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Невозможно редактировать: данные растения отсутствуют'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Редактирование всех повторений - открываем экран редактирования
      Navigator.of(context).pop(); // Закрываем текущий диалог
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SetReminderScreen(
            plantData: widget.reminder.plant!, // Передаем данные растения (проверено выше)
            isPlantAlreadyInCollection: true,  // Растение уже в коллекции
            forceAddMode: false, // Режим редактирования
            fromReminderEdit: true, // НОВЫЙ ПАРАМЕТР: пришли из редактирования
            reminderToEdit: widget.reminder, // Передаем напоминание для редактирования
          ),
        ),
      ).then((_) {
        // После возврата с экрана редактирования обновляем данные
        print('🔄 Возврат с экрана редактирования - обновляем данные');
        widget.onReminderUpdated();
      });
    } else {
      print('📅 Редактирование только этого дня - показываем диалог времени');
      // Редактирование только этого дня - показываем простой диалог с параметрами
      _showEditSingleDayDialog();
    }
    print('🎛️ === КОНЕЦ ОБРАБОТКИ РЕДАКТИРОВАНИЯ ===\n');
  }

  void _showEditSingleDayDialog() {
    print('📅 === ПОКАЗ ДИАЛОГА РЕДАКТИРОВАНИЯ ОДНОГО ДНЯ ===');
    print('📅 Выбранная дата: ${widget.selectedDate}');
    print('⏰ Текущее время напоминания: ${widget.reminder.date}');
    print('🎯 Эффективное время: ${widget.reminder.effectiveTime}');
    print('✏️ Изменено для даты: ${widget.reminder.isModifiedForThisDate}');
    
    // Используем эффективное время, если доступно
    final effectiveDateTime = widget.reminder.getEffectiveDateTime();
    String selectedHour = effectiveDateTime.hour.toString().padLeft(2, '0');
    String selectedMinute = effectiveDateTime.minute.toString().padLeft(2, '0');
    
    print('⏰ Начальные значения - час: $selectedHour, минута: $selectedMinute');
    
    print('🎭 Открываем диалог изменения времени...');
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        print('🎭 Диалог изменения времени строится...');
        return StatefulBuilder(
          builder: (context, setDialogState) {
            print('🎭 StatefulBuilder диалога изменения времени строится...');
            return AlertDialog(
          title: Text(
            'Изменить только этот день',
            style: TextStyle(
              fontFamily: 'Gilroy', 
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Изменить время задачи только для ${DateFormat('dd.MM.yyyy').format(widget.selectedDate)}:',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 20),
                
                // Селектор времени
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Заголовок
                      Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.grey[600], size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Время напоминания:',
                              style: TextStyle(
                                fontFamily: 'Gilroy',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      // Время
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Часы
                              GestureDetector(
                                onTap: () => _showTimePicker(dialogContext, true, selectedHour, selectedMinute, (newHour, newMinute) {
                                  setDialogState(() {
                                    selectedHour = newHour;
                                    selectedMinute = newMinute;
                                  });
                                }),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Text(
                                    selectedHour,
                                    style: TextStyle(
                                      fontFamily: 'Gilroy',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF63A36C),
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                ' : ', 
                                style: TextStyle(
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                )
                              ),
                              // Минуты
                              GestureDetector(
                                onTap: () => _showTimePicker(dialogContext, false, selectedHour, selectedMinute, (newHour, newMinute) {
                                  setDialogState(() {
                                    selectedHour = newHour;
                                    selectedMinute = newMinute;
                                  });
                                }),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Text(
                                    selectedMinute,
                                    style: TextStyle(
                                      fontFamily: 'Gilroy',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF63A36C),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Информация о действии
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Это создаст исключение только для выбранного дня. Основное расписание останется без изменений.',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Отмена',
                style: TextStyle(
                  fontFamily: 'Gilroy', 
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                print('💾 === НАЖАТА КНОПКА СОХРАНИТЬ ===');
                print('⏰ Выбранное время: $selectedHour:$selectedMinute');
                print('📅 Дата для изменения: ${widget.selectedDate}');
                print('🆔 ID напоминания: ${widget.reminder.id}');
                print('🚀 Вызываем _createSingleDayException...');
                _createSingleDayException(dialogContext, selectedHour, selectedMinute);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF63A36C),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Сохранить',
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
          },
        );
      },
    ).then((_) {
      print('🎭 Диалог изменения времени закрыт');
    });
    print('📅 === КОНЕЦ ПОКАЗА ДИАЛОГА РЕДАКТИРОВАНИЯ ===\n');
  }
  
  // Метод для показа селектора времени
  void _showTimePicker(BuildContext context, bool isHour, String currentHour, String currentMinute, Function(String, String) onTimeChanged) {
    print('⏰ === ПОКАЗ СЕЛЕКТОРА ВРЕМЕНИ ===');
    print('🔧 Редактируем: ${isHour ? "час" : "минуты"}');
    print('⏰ Текущее время: $currentHour:$currentMinute');
    
    final List<String> hours = List.generate(24, (index) => index.toString().padLeft(2, '0'));
    final List<String> minutes = List.generate(60, (index) => index.toString().padLeft(2, '0'));
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: 250,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              child: Text(
                isHour ? 'Выберите час' : 'Выберите минуты',
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ListWheelScrollView.useDelegate(
                itemExtent: 50,
                diameterRatio: 1.5,
                controller: FixedExtentScrollController(
                  initialItem: isHour 
                    ? hours.indexOf(currentHour)
                    : minutes.indexOf(currentMinute),
                ),
                childDelegate: ListWheelChildBuilderDelegate(
                  builder: (context, index) {
                    final items = isHour ? hours : minutes;
                    if (index < 0 || index >= items.length) return null;
                    
                    return Center(
                      child: Text(
                        items[index],
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                  childCount: isHour ? hours.length : minutes.length,
                ),
                onSelectedItemChanged: (index) {
                  final items = isHour ? hours : minutes;
                  if (isHour) {
                    onTimeChanged(items[index], currentMinute);
                  } else {
                    onTimeChanged(currentHour, items[index]);
                  }
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF63A36C),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Готово',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Метод для создания исключения на один день
  void _createSingleDayException(BuildContext dialogContext, String hour, String minute) async {
    print('🔧 === НАЧАЛО СОЗДАНИЯ ИСКЛЮЧЕНИЯ НА ОДИН ДЕНЬ ===');
    print('📅 Выбранная дата: ${widget.selectedDate}');
    print('⏰ Выбранное время: $hour:$minute');
    print('🆔 ID напоминания: ${widget.reminder.id}');
    
    try {
      setState(() => _isLoading = true);
      print('⏳ Установлен флаг загрузки');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      print('🔑 Получен токен авторизации: ${token.isNotEmpty ? "✅ Есть" : "❌ Отсутствует"}');
      
      if (token.isEmpty) {
        throw Exception('Токен авторизации отсутствует');
      }
      
      final reminderService = ReminderService();
      print('🔧 Создан экземпляр ReminderService');
      
      // Создаем новое время для исключения
      final exceptionDate = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        int.parse(hour),
        int.parse(minute),
      );
      print('📅 Сформирована дата исключения: $exceptionDate');
      
      final modifiedData = {
        'time': '$hour:$minute',
        'date': DateFormat('yyyy-MM-dd').format(exceptionDate),
      };
      print('📝 Данные для модификации: $modifiedData');
      
      print('🚀 Вызываем API createReminderException...');
      
      // Вызываем метод API для создания исключения на один день
      final success = await reminderService.createReminderException(
        token,
        widget.reminder.id!,
        exceptionDate: exceptionDate,
        type: 'modified',
        modifiedData: modifiedData,
        reason: 'Пользователь изменил время для конкретного дня',
      );
      
      print('📊 Результат API вызова: $success');
      print('📊 Результат API вызова: $success');
      
      if (success) {
        print('✅ Исключение успешно создано');
        Navigator.of(dialogContext).pop(); // Закрываем диалог
        print('🔄 Закрыт диалог изменения времени');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Время изменено для ${DateFormat('dd.MM.yyyy').format(widget.selectedDate)} на $hour:$minute',
              style: TextStyle(fontFamily: 'Gilroy'),
            ),
            backgroundColor: Color(0xFF63A36C),
            duration: Duration(seconds: 3),
          ),
        );
        print('📢 Показано уведомление об успехе');
        
        // Обновляем родительский экран
        print('🔄 Вызываем onReminderUpdated...');
        widget.onReminderUpdated();
        print('✅ onReminderUpdated выполнен');
        
        // Закрываем основной диалог
        print('🔄 Закрываем основной диалог...');
        Navigator.of(context).pop();
        print('✅ Основной диалог закрыт');
        
      } else {
        print('❌ API вернул неуспешный результат');
        throw Exception('Не удалось создать исключение - API вернул false');
      }
    } catch (e) {
      print('🚨 === ОШИБКА ПРИ СОЗДАНИИ ИСКЛЮЧЕНИЯ ===');
      print('❌ Тип ошибки: ${e.runtimeType}');
      print('❌ Сообщение об ошибке: $e');
      print('❌ Стек ошибки: ${StackTrace.current}');
      
      AppLogger.error('Ошибка при создании исключения на один день: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при изменении времени: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      print('🏁 Сброс флага загрузки');
      setState(() => _isLoading = false);
      print('🔧 === КОНЕЦ СОЗДАНИЯ ИСКЛЮЧЕНИЯ НА ОДИН ДЕНЬ ===\n');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🎭 === ПОСТРОЕНИЕ ОСНОВНОГО ДИАЛОГА УПРАВЛЕНИЯ НАПОМИНАНИЯМИ ===');
    print('🆔 ID напоминания: ${widget.reminder.id}');
    print('📅 Выбранная дата: ${widget.selectedDate}');
    print('🔧 Тип напоминания: ${widget.reminder.type}');
    print('⏰ Время напоминания: ${widget.reminder.date}');
    
    // Получаем размеры экрана для адаптивности
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;
    
    print('📱 Размеры экрана: ${screenWidth}x${screenHeight}');
    
    // Определяем максимальные размеры диалога с учетом отступов
    final horizontalPadding = 32.0; // отступы по бокам от края экрана
    final verticalPadding = 60.0;   // отступы сверху и снизу от края экрана
    
    final maxDialogWidth = screenWidth > 600 
        ? 380.0 // на больших экранах фиксированная ширина
        : screenWidth - horizontalPadding; // на маленьких - с отступами
        
    final maxDialogHeight = screenHeight - verticalPadding; // оставляем место сверху и снизу
    
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalPadding / 2, 
        vertical: verticalPadding / 2
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: maxDialogWidth,
        constraints: BoxConstraints(
          maxHeight: maxDialogHeight,
          maxWidth: maxDialogWidth,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок (фиксированный)
            Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: Color(0xFF63A36C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _getReminderTypeIcon(widget.reminder.type),
                        style: TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getReminderTypeName(widget.reminder.type),
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C2C2C),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          widget.reminder.plant?.name ?? 'Растение не указано',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Прокручиваемый контент
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Информация о задаче
                    _buildInfoSection(),
                    
                    SizedBox(height: 20),
                    
                    // Кнопки действий
                    if (!_isLoading) ...[
                      // Кнопка "Готово"
                      if (!widget.reminder.isCompleted) ...[
                        _buildActionButton(
                          icon: Icons.check_circle,
                          label: 'Готово',
                          color: Color(0xFF4CAF50),
                          onTap: _handleMarkAsComplete,
                        ),
                        SizedBox(height: 10),
                      ],
                      
                      // Кнопки редактирования
                      _buildActionButton(
                        icon: Icons.edit,
                        label: 'Изменить все повторения',
                        color: Color(0xFF2196F3),
                        onTap: () => _handleEditReminder(true),
                      ),
                      SizedBox(height: 8),
                      
                      _buildActionButton(
                        icon: Icons.edit_calendar,
                        label: 'Изменить только этот день',
                        color: Color(0xFF2196F3),
                        onTap: () => _handleEditReminder(false),
                      ),
                      SizedBox(height: 12),
                      
                      // Кнопки удаления
                      _buildActionButton(
                        icon: Icons.delete_forever,
                        label: 'Удалить все повторения',
                        color: Colors.red,
                        onTap: () => _handleDeleteReminder(true),
                      ),
                      SizedBox(height: 8),
                      
                      _buildActionButton(
                        icon: Icons.delete_outline,
                        label: 'Удалить только этот день',
                        color: Colors.red,
                        onTap: () => _handleDeleteReminder(false),
                      ),
                      SizedBox(height: 12),
                      
                      // Кнопка закрытия
                      _buildActionButton(
                        icon: Icons.close,
                        label: 'Закрыть',
                        color: Colors.grey[600]!,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ] else ...[
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF63A36C)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Время', _getTimeOfDayName(widget.reminder.timeOfDay)),
          SizedBox(height: 6),
          _buildInfoRow('Повторение', _getRepeatDescription()),
          if (widget.reminder.note?.isNotEmpty == true) ...[
            SizedBox(height: 6),
            _buildInfoRow('Заметка', widget.reminder.note!),
          ],
          SizedBox(height: 6),
          _buildInfoRow('Создано', DateFormat('dd.MM.yyyy').format(widget.reminder.date)),
          if (widget.reminder.isCompleted) ...[
            SizedBox(height: 6),
            _buildInfoRow('Статус', 'Выполнено', isStatus: true),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isStatus = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 13,
              color: isStatus ? Color(0xFF4CAF50) : Color(0xFF2C2C2C),
              fontWeight: isStatus ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        print('🔘 === НАЖАТА КНОПКА ДЕЙСТВИЯ ===');
        print('📝 Название кнопки: $label');
        print('🔧 Иконка: $icon');
        print('🎨 Цвет: $color');
        print('🚀 Вызываем обработчик...');
        onTap();
        print('✅ Обработчик выполнен');
        print('🔘 === КОНЕЦ ОБРАБОТКИ КНОПКИ ===\n');
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
