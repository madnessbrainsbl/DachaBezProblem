import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Для форматирования дат
import 'package:intl/date_symbol_data_local.dart'; // Для инициализации локализации
import 'package:table_calendar/table_calendar.dart'; // Пакет календаря
import 'dart:math'; // Для случайных маркеров
import 'dart:async';

import '../models/reminder.dart';
import '../services/api/reminder_service.dart';
import '../services/plant_events.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'day_detail_page.dart';
import '../plant_result/set_reminder_screen.dart';
import '../widgets/safe_asset_icon.dart';

// Модель для обозначения событий календаря
class CalendarEvent {
  final String title;
  final Color color;
  final IconData icon;
  final String? iconPath; // Путь к PNG иконке
  final Reminder? reminder;

  CalendarEvent({
    required this.title,
    required this.color,
    required this.icon,
    this.iconPath,
    this.reminder,
  });
}

// Функция для генерации событий календаря из напоминаний (группировка по категориям)
List<CalendarEvent> generateEventsFromReminders(List<Reminder> reminders) {
  if (reminders.isEmpty) return [];
  
  // Группируем напоминания по категориям
  final Set<String> categories = {};
  
  for (final reminder in reminders) {
    String category = _getReminderCategory(reminder.type, note: reminder.note);
    categories.add(category);
  }
  
  // Создаем события для каждой категории (максимум 3)
  return categories.map((category) {
    Color eventColor;
    String eventTitle = category;
    String? iconPath; // Используем PNG иконки как в легенде
    
    switch (category) {
      case 'Аграрные работы':
        eventColor = Colors.green;
        iconPath = 'assets/images/kalendar/zelenii_cvetok.png';
        break;
      case 'Обработка от вредителей':
        eventColor = Colors.red;
        iconPath = 'assets/images/kalendar/krasniy_cvetok.png.png';
        break;
      case 'Обработка от болезней':
        eventColor = Colors.orange;
        iconPath = 'assets/images/kalendar/zheltiy_cvetok.png';
        break;
      default:
        eventColor = Colors.grey;
        iconPath = null;
    }
    
    return CalendarEvent(
      title: eventTitle,
      color: eventColor,
      icon: Icons.circle, // Fallback иконка
      iconPath: iconPath, // Добавляем путь к PNG иконке
    );
  }).toList();
}

// Функция для получения русского названия типа напоминания
String _getReminderTypeDisplayName(String type, {String? note}) {
  // Проверяем маркеры в note для определения реального типа
  if (note != null) {
    if (note.startsWith('[ROTATION]')) {
      return 'Вращение';
    } else if (note.startsWith('[CUSTOM_TASK]')) {
      return 'Моя задача';
    }
  }
  
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
    case 'disease_control':
      return 'Обработка от болезней';
    case 'rotation':
      return 'Вращение';
    case 'custom_task':
      return 'Моя задача';
    default:
      return type.isNotEmpty ? type : 'Напоминание';
  }
}

// Определяем категорию напоминания
String _getReminderCategory(String reminderType, {String? note}) {
  // Проверяем маркеры в note для определения реального типа
  if (note != null) {
    if (note.startsWith('[ROTATION]') || note.startsWith('[CUSTOM_TASK]')) {
      return 'Аграрные работы';
    }
  }
  
  switch (reminderType) {
    case ReminderTypes.watering:
    case ReminderTypes.spraying:
    case ReminderTypes.fertilizing:
    case ReminderTypes.transplanting:
    case ReminderTypes.pruning:
    case ReminderTypes.rotation:
    case ReminderTypes.customTask:
    case 'watering':
    case 'spraying':
    case 'fertilizing':
    case 'transplanting':
    case 'pruning':
    case 'rotation':
    case 'custom_task':
      return 'Аграрные работы';
    case ReminderTypes.pestControl:
    case 'pest_control':
      return 'Обработка от вредителей';
    case ReminderTypes.diseaseControl:
    case 'disease_treatment':
    case 'disease_control':
      return 'Обработка от болезней';
    default:
      return 'Аграрные работы'; // По умолчанию
  }
}

/// Страница «Календарь»
class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with WidgetsBindingObserver {
  late final String _locale;
  // Оставляем _focusedDay для начальной фокусировки и заголовка страницы
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Добавляем ScrollController и GlobalKey
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _currentMonthKey = GlobalKey();
  
  // Состояние для напоминаний
  List<Reminder> _allReminders = [];
  Set<String> _deletedReminders = {}; // Сет удаленных напоминаний вида "reminderId_yyyy-MM-dd"
  bool _isLoadingReminders = false;
  
  // Кэш событий календаря для оптимизации
  final Map<String, List<CalendarEvent>> _eventsCache = {};
  
  // Подписка на события для обновления календаря
  StreamSubscription<PlantEventData>? _eventSubscription;
  
  // Таймер для периодического обновления календаря
  Timer? _refreshTimer;
  
  // Оптимизированная проверка попадания напоминания на дату
  bool _reminderMatchesDate(Reminder reminder, DateTime targetDate) {
    if (!reminder.isActive) return false;
    
    final reminderDate = DateTime.utc(
      reminder.date.year,
      reminder.date.month,
      reminder.date.day,
    );
    
    // Точное совпадение даты
    if (reminderDate == targetDate) return true;
    
    // Старая система еженедельных повторений
    if (reminder.repeatWeekly && reminder.daysOfWeek.isNotEmpty) {
      if (targetDate.isAfter(reminderDate) || targetDate == reminderDate) {
        final targetWeekday = targetDate.weekday;
        final apiWeekday = targetWeekday == 7 ? 0 : targetWeekday;
        return reminder.daysOfWeek.contains(apiWeekday);
      }
    }
    
    // Новая система интервалов
    if (targetDate.isBefore(reminderDate)) return false;
    
    final daysDiff = targetDate.difference(reminderDate).inDays;
    
    if (reminder.intervalDays != null && reminder.intervalDays! > 0) {
      return daysDiff % reminder.intervalDays! == 0;
    }
    
    if (reminder.intervalWeeks != null && reminder.intervalWeeks! > 0) {
      final weeksDiff = (daysDiff / 7).floor();
      return weeksDiff % reminder.intervalWeeks! == 0 && daysDiff % 7 == 0;
    }
    
    if (reminder.intervalMonths != null && reminder.intervalMonths! > 0) {
      final monthsDiff = (targetDate.year - reminderDate.year) * 12 + 
                        (targetDate.month - reminderDate.month);
      return monthsDiff % reminder.intervalMonths! == 0 && 
             targetDate.day == reminderDate.day;
    }
    
    return false;
  }
  
  List<CalendarEvent> _getEventsForDay(DateTime day) {
    // Используем кэш для ускорения
    final cacheKey = '${day.year}-${day.month}-${day.day}';
    if (_eventsCache.containsKey(cacheKey)) {
      return _eventsCache[cacheKey]!;
    }
    
    // Получаем напоминания на конкретный день с учетом повторений
    final targetDate = DateTime.utc(day.year, day.month, day.day);
    
    final dayReminders = _allReminders
        .where((reminder) => _reminderMatchesDate(reminder, targetDate))
        .where((reminder) {
          // 🔥 ИСКЛЮЧАЕМ УДАЛЕННЫЕ ДНИ
          if (reminder.isDeletedForDate == true) {
            print('� Календарь: исключаем удаленное напоминание ${reminder.id} на ${DateFormat('dd.MM.yyyy').format(targetDate)}');
            return false;
          }
          return true;
        })
        .toList();

    // Генерируем события и сохраняем в кэш
    final events = generateEventsFromReminders(dayReminders);
    _eventsCache[cacheKey] = events;
    
    return events;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locale = 'ru_RU';
    initializeDateFormatting(_locale);
    _selectedDay =
        DateTime.utc(_focusedDay.year, _focusedDay.month, _focusedDay.day);

    // Загружаем напоминания
    _loadReminders();
    
    // Подписываемся на события создания/обновления напоминаний
    _eventSubscription = PlantEvents().stream.listen((event) {
      if (event.type == PlantEventType.reminderCreated ||
          event.type == PlantEventType.reminderUpdated ||
          event.type == PlantEventType.reminderDeleted) {
        print('📅 CalendarPage: Получено событие ${event.type}, обновляем календарь');
        
        // 🔥 ПРИНУДИТЕЛЬНО ОЧИЩАЕМ КЭШ ПРИ УДАЛЕНИИ
        if (event.type == PlantEventType.reminderDeleted) {
          print('🗑️ Очищаем кэш календаря после удаления напоминания');
          _eventsCache.clear();
        }
        
        // Используем новый метод для принудительного обновления
        forceRefreshCalendar();
      }
    });

    // Прокручиваем к текущему месяцу после отрисовки первого кадра
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentMonthKey.currentContext != null) {
        Scrollable.ensureVisible(
          _currentMonthKey.currentContext!,
          duration: const Duration(milliseconds: 400), // Плавная прокрутка
          curve: Curves.easeInOut,
          alignment: 0.0, // Выравниваем по верху видимой области
        );
      }
    });
    
    // 🔄 Запускаем таймер для периодического обновления календаря (каждые 30 секунд)
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        print('⏰ Плановое обновление календаря');
        forceRefreshCalendar();
      }
    });
  }
  
  // Метод для загрузки напоминаний
  Future<void> _loadReminders() async {
    setState(() {
      _isLoadingReminders = true;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      if (token.isNotEmpty) {
        final reminderService = ReminderService();
        // Просто загружаем все напоминания с повторениями как раньше
        final allReminders = await reminderService.getUpcomingReminders(
          token, 
          days: 60, // Загружаем на 2 месяца вперед для календаря
          timezone: 'Europe/Moscow'
        );
        
        setState(() {
          _allReminders = allReminders;
          _deletedReminders.clear(); // Очищаем, пока не реализуем эффективную проверку
          _eventsCache.clear(); // Очищаем кэш при новых данных
        });
        
        print('📋 Загружено ${allReminders.length} напоминаний для календаря');
        
        // 🔍 Отладочная информация об удаленных напоминаниях
        final deletedCount = allReminders.where((r) => r.isDeletedForDate == true).length;
        if (deletedCount > 0) {
          print('🚫 Из них удаленных для конкретных дат: $deletedCount');
          allReminders.where((r) => r.isDeletedForDate == true).forEach((r) {
            print('   • ${r.id}: ${r.type} удален для своей даты');
          });
        }
        
        // 🔄 Принудительное обновление календаря через небольшую задержку
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              // Пустой setState для принудительного обновления UI
            });
            print('🔄 Календарь принудительно обновлен после загрузки данных');
          }
        });
      }
    } catch (e) {
      print('❌ Ошибка загрузки напоминаний для календаря: $e');
    } finally {
      setState(() {
        _isLoadingReminders = false;
      });
    }
  }
  
  // Метод для принудительного обновления календаря
  void forceRefreshCalendar() {
    print('🔄 Принудительное обновление календаря...');
    _eventsCache.clear();
    _loadReminders();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      print('📱 Приложение возобновлено, обновляем календарь');
      forceRefreshCalendar();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose(); // Не забываем освободить контроллер
    _eventSubscription?.cancel(); // Отменяем подписку на события
    _refreshTimer?.cancel(); // Останавливаем таймер обновления
    super.dispose();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    // Преобразуем selectedDay к UTC для корректного сравнения и хранения
    final selectedDayUtc =
        DateTime.utc(selectedDay.year, selectedDay.month, selectedDay.day);
    if (!isSameDay(_selectedDay, selectedDayUtc)) {
      setState(() {
        _selectedDay = selectedDayUtc;
        // _focusedDay больше не управляет отображаемым месяцем в календаре,
        // но можем оставить его для заголовка или навигации, если нужно.
        // Если нужно, чтобы выбор даты менял главный заголовок:
        // _focusedDay = focusedDay;
      });
    }
    
    // ИСПРАВЛЕНИЕ: Добавляем переход к странице деталей дня
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DayDetailPage(selectedDate: selectedDayUtc),
      ),
    ).then((_) {
      // Обновляем календарь при возврате с DayDetailPage
      print('📅 Возврат с DayDetailPage, обновляем календарь');
      forceRefreshCalendar();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Форматируем дату заголовка страницы (например, "21 апреля 2025")
    final pageHeaderDateFormatter = DateFormat('d MMMM yyyy', _locale);
    final headerDateString = pageHeaderDateFormatter
        .format(_focusedDay); // Используем _focusedDay для заголовка
    final lastSpaceIndex = headerDateString.lastIndexOf(' ');
    final datePart = headerDateString.substring(0, lastSpaceIndex);
    final yearPart = headerDateString.substring(lastSpaceIndex + 1);

    // Форматируем заголовок месяца (например, "Декабрь", "Январь 2025")
    final monthFormatter = DateFormat('LLLL', _locale);
    final monthYearFormatter = DateFormat('LLLL yyyy', _locale);

    // Определяем ТЕКУЩИЙ месяц для центрирования
    final currentMonthBase =
        DateTime.utc(_focusedDay.year, _focusedDay.month, 1);

    // Генерируем список месяцев: 2 назад, текущий, 2 вперед (всего 5)
    final List<DateTime> monthsToDisplay = List.generate(5, (index) {
      int monthOffset = index - 2; // Смещение от -2 до +2
      return DateTime.utc(
          currentMonthBase.year, currentMonthBase.month + monthOffset, 1);
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(0, -1),
            end: Alignment(0, 1),
            colors: [Color(0xFFEAF5DA), Color(0xFFB6DFA3)],
          ),
        ),
        child: SafeArea(
          // Используем Column для разделения скролл-области и фиксированного низа
          child: Column(
            children: [
              // --------------------------------------
              // Заголовок страницы (Дата) - остается сверху
              // --------------------------------------
              Padding(
                padding: const EdgeInsets.only(
                    top: 25.0,
                    bottom: 15.0,
                    left: 29,
                    right: 20.0), // Добавим правый паддинг
                child: Align(
                  // Выравниваем по левому краю явно
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 24,
                          letterSpacing: 0.12),
                      children: [
                        TextSpan(
                            text: '$datePart ',
                            style: const TextStyle(color: Color(0xFF1F2024))),
                        TextSpan(
                            text: yearPart,
                            style: const TextStyle(color: Color(0xFF63A36C))),
                      ],
                    ),
                  ),
                ),
              ),

              // --------------------------------------
              // Блок с календарями - теперь внутри Expanded и с ShaderMask
              // --------------------------------------
              Expanded(
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    // Градиент для эффекта затухания снизу
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white, // Полностью видим сверху
                        Colors.white.withOpacity(0.0) // Прозрачный снизу
                      ],
                      stops: const [
                        0.9,
                        1.0
                      ], // Начинаем затухание с 90% высоты
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn, // Применяем маску
                  child: SingleChildScrollView(
                    controller: _scrollController, // Привязываем контроллер
                    physics: const ClampingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal:
                              20.0), // Паддинг для контента внутри скролла
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Динамически строим календари для каждого месяца в списке
                          ...monthsToDisplay.asMap().entries.map((entry) {
                            int index = entry.key;
                            DateTime monthDate = entry.value;
                            return Padding(
                              // Добавляем отступ *после* каждого календаря
                              padding: const EdgeInsets.only(bottom: 20.0),
                              child: _buildMonthCalendar(
                                // Передаем ключ только для текущего месяца (индекс 2)
                                key: index == 2 ? _currentMonthKey : null,
                                monthDate,
                                monthFormatter,
                                monthYearFormatter,
                              ),
                            );
                          }).toList(),
                          // Отступ после последнего календаря больше не нужен здесь,
                          // так как Padding добавляет его автоматически.
                          // SizedBox(height: 20), был удален
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ------------------------------------------------------------------
              // Нижний блок: Легенда и Кнопка - теперь фиксирован снизу
              // ------------------------------------------------------------------
              Padding(
                padding: const EdgeInsets.only(
                  left:
                      27.0, // Горизонтальные отступы как у календаря + отступ легенды
                  right: 20.0, // Горизонтальные отступы как у календаря
                  top: 20.0, // Отступ сверху от календаря
                  bottom: 20.0, // Отступ снизу
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment
                      .center, // Выравнивание по центру по вертикали
                  children: [
                    // Оборачиваем Колонку с легендой в Flexible
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LegendItem(
                            iconPath:
                                'assets/images/kalendar/zelenii_cvetok.png',
                            text: 'Агротехнические работы',
                          ),
                          const SizedBox(height: 6),
                          _LegendItem(
                            iconPath:
                                'assets/images/kalendar/krasniy_cvetok.png.png',
                            text: 'Обработка от вредителей',
                          ),
                          const SizedBox(height: 6),
                          _LegendItem(
                            iconPath:
                                'assets/images/kalendar/zheltiy_cvetok.png',
                            text: 'Обработка от болезней',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                        width: 10), // Отступ между легендой и кнопкой
                    // Кнопка "Новая задача"
                    ElevatedButton(
                      onPressed: () async {
                        // Ожидаем результата из SetReminderScreen
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SetReminderScreen(
                              openFromWatering: false, // Переходим из календаря
                              forceAddMode: true,      // Всегда создаём новое напоминание
                              isPlantAlreadyInCollection: true, // ИСПРАВЛЕНО: Из календаря всегда работаем с растениями из коллекции
                              fromScanHistory: true,   // Не после сканирования - возвращаемся назад
                              hideLikeButton: true,    // Скрываем сердце только для этого сценария
                            ),
                          ),
                        );
                        // После возврата дополнительно обновляем календарь
                        // (события уже должны сработать, но дублируем для надёжности)
                        print('📅 CalendarPage: Возврат из SetReminderScreen, обновляем календарь');
                        _loadReminders();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF63A36C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 15, horizontal: 25),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Новая задача',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Gilroy',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Image.asset(
                            'assets/images/kalendar/plusik.png',
                            width: 20,
                            height: 20,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Виджет для одного месяца календаря ---
  Widget _buildMonthCalendar(DateTime monthDate, DateFormat monthFormatter,
      DateFormat monthYearFormatter,
      {Key? key} // Добавляем необязательный параметр key
      ) {
    // Форматируем заголовок месяца
    String title;
    if (monthDate.year == _focusedDay.year) {
      title = monthFormatter.format(monthDate); // "Декабрь"
      // Первая буква заглавная
      title = title[0].toUpperCase() + title.substring(1);
    } else {
      title = monthYearFormatter.format(monthDate); // "Январь 2025"
      // Первая буква заглавная
      title = title[0].toUpperCase() + title.substring(1);
    }

    return Column(
      key: key, // Передаем ключ корневому виджету
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок месяца
        Padding(
          padding: const EdgeInsets.only(
              left: 9.0, bottom: 10.0), // Отступ как у заголовка даты
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1F2024),
              fontSize: 16,
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w600, // SemiBold как в макете
              letterSpacing: 0.08,
            ),
          ),
        ),
        // Сам календарь
        TableCalendar<CalendarEvent>(
          locale: _locale,
          // Устанавливаем границы и фокус для этого конкретного месяца
          firstDay: DateTime.utc(monthDate.year, monthDate.month, 1),
          lastDay: DateTime.utc(
              monthDate.year, monthDate.month + 1, 0), // Последний день месяца
          focusedDay: monthDate, // Фокус на первом дне месяца для отображения

          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: CalendarFormat.month, // Всегда формат месяца
          startingDayOfWeek: StartingDayOfWeek.monday,
          eventLoader: _getEventsForDay,
          // Явно указываем, что TableCalendar не должен обрабатывать вертикальные свайпы
          availableGestures: AvailableGestures.horizontalSwipe,

          // --- Стилизация ---
          headerVisible: false, // Скрываем стандартный заголовок TableCalendar
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(
                color: Color(0xFFB0B0B0), fontFamily: 'Gilroy', fontSize: 14),
            weekendStyle: TextStyle(
                color: Color(0xFFB0B0B0), fontFamily: 'Gilroy', fontSize: 14),
          ),
          calendarStyle: CalendarStyle(
            // Добавляем внутренний отступ, чтобы кружок выделения был меньше
            cellPadding: const EdgeInsets.all(4.0),

            defaultTextStyle: const TextStyle(
                color: Color(0xFF1F2024), fontFamily: 'Gilroy', fontSize: 14),
            weekendTextStyle: const TextStyle(
                color: Color(0xFF1F2024), fontFamily: 'Gilroy', fontSize: 14),
            outsideTextStyle: const TextStyle(
                color:
                    Colors.transparent), // Дни другого месяца делаем невидимыми

            selectedDecoration: const BoxDecoration(
              color: Colors.white, // Белый круг для выбранного дня
              shape: BoxShape.circle,
            ),
            selectedTextStyle: const TextStyle(
                color: Color(0xFF1F2024), // Черный жирный текст внутри белого круга
                fontFamily: 'Gilroy',
                fontSize: 14,
                fontWeight: FontWeight.bold),

            todayDecoration: BoxDecoration(
              color: const Color(0xFF63A36C).withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            todayTextStyle: const TextStyle(
                color: Color(0xFF1F2024), fontFamily: 'Gilroy', fontSize: 14),

            markersAlignment: Alignment.bottomCenter,
            markerDecoration: const BoxDecoration(color: Colors.transparent),
            markersMaxCount: 3,
          ),

          // --- Билдеры ---
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              if (events.isEmpty) return const SizedBox();
              
              return Positioned(
                bottom: 5,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: events.take(3).map((event) {
                    // Берем не больше 3х маркеров
                    String iconPath;
                    
                    // Используем новое поле iconPath из события
                    if (event.iconPath != null) {
                      iconPath = event.iconPath!;
                    } else {
                      // Для остальных типов (fertilizing, transplanting, pruning)
                      iconPath = 'assets/images/kalendar/zelenii_cvetok.png'; // ЗЕЛЕНАЯ для агротехники
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.0),
                      child: SafeAssetIcon(assetPath: iconPath, size: 12, fallback: Icon(Icons.square, size: 12, color: Colors.grey)),
                    );
                  }).toList(),
                ),
              );
            },
            // Кастомизация дней другого месяца (делаем их пустыми)
            outsideBuilder: (context, day, focusedDay) {
              return const SizedBox.shrink();
            },
          ),

          // --- Обработчики ---
          onDaySelected: _onDaySelected,
          // Не позволяем TableCalendar менять свой focusedDay при смахивании,
          // т.к. мы управляем отображаемыми месяцами снаружи.
          onPageChanged: (focused) {},
          // Отключаем свайп между месяцами внутри TableCalendar
          pageAnimationEnabled: false,
          pageJumpingEnabled: false,
        ),
      ],
    );
  }
}

// Вспомогательный виджет для элемента легенды
class _LegendItem extends StatelessWidget {
  final String iconPath;
  final String text;

  const _LegendItem({
    required this.iconPath,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SafeAssetIcon(assetPath: iconPath, size: 12, fallback: Icon(Icons.square, size: 12, color: Colors.grey)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF4D4D4D),
              fontFamily: 'Gilroy',
              fontSize: 11,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
