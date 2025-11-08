import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api/scan_service.dart';
import '../services/api/reminder_service.dart';
import '../models/plant_info.dart';
import '../models/reminder.dart';
import '../services/achievement_manager.dart';
import '../services/plant_events.dart';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import '../scanner/scanner_screen.dart';
import '../homepage/home_screen.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/treatment_recommendations_widget.dart';
import '../services/api/treatment_service.dart';

// Цвета и константы
const Color _black = Colors.black;
const Color _white = Colors.white;
const Color _lightGreenBg = Color(0xFFEBF5DB);
const Color _greenAccent = Color(0xFF63A36C);
const Color _shadowColor = Color(0x1931873F);
const String _fontFamily = 'Gilroy';

/// Экран установки напоминания
class SetReminderScreen extends StatefulWidget {
  final dynamic plantData; // Данные растения для добавления в коллекцию
  final bool isPlantAlreadyInCollection; // Флаг: растение уже в коллекции
  final bool forceAddMode; // Принудительный режим добавления (не проверять существующие)
  final bool openFromWatering; // Новый параметр: пришли ли из кнопки полива
  final bool fromScanHistory; // Новый параметр: пришли ли из истории сканирования
  final bool fromReminderEdit; // Новый параметр: пришли ли из редактирования напоминания
  final Reminder? reminderToEdit; // Напоминание для редактирования
  // НОВОЕ: скрывать ли кнопку лайка в нижней панели
  final bool hideLikeButton;
  
  const SetReminderScreen({
    Key? key, 
    this.plantData, 
    this.isPlantAlreadyInCollection = false, 
    this.forceAddMode = false,
    this.openFromWatering = false, // По умолчанию false
    this.fromScanHistory = false, // По умолчанию false (значит пришли после сканирования)
    this.fromReminderEdit = false, // По умолчанию false
    this.reminderToEdit, // Напоминание для редактирования
    this.hideLikeButton = false, // По умолчанию показываем лайк
  }) : super(key: key);

  @override
  State<SetReminderScreen> createState() => _SetReminderScreenState();
}

class _SetReminderScreenState extends State<SetReminderScreen> {
  bool _showPlantDropdown = false;
  String _selectedPlant = '';
  final List<String> _plants = [];
  bool _showReminderDropdown = false; // Будет установлен в initState
  String _selectedReminderType = 'Полив';
  bool _showRepeatDropdown = false;
  String _selectedRepeatValue = '1'; // Начинаем с 1
  String _selectedRepeatUnit = 'дней';
  final List<String> _repeatValues = List.generate(31, (index) => (index + 1).toString()); // От 1 до 31
  final List<String> _repeatUnits = ['дней', 'недель', 'месяцев'];
  int _selectedValueIndex = 0; // Индекс для '1'
  int _selectedUnitIndex = 0; // Индекс для 'дней'

  // Переменные для проверки существующих напоминаний
  bool _isCheckingReminders = false;
  List<Reminder> _existingReminders = [];
  Reminder? _currentReminder; // Текущее редактируемое напоминание

  // Новые переменные для времени
  bool _showTimeDropdown = false;
  String _selectedHour = '09';
  String _selectedMinute = '41';
  final List<String> _hours =
      List.generate(24, (index) => index.toString().padLeft(2, '0'));
  final List<String> _minutes =
      List.generate(60, (index) => index.toString().padLeft(2, '0'));
  int _selectedHourIndex = 9; // Индекс для '09'
  int _selectedMinuteIndex = 41; // Индекс для '41'

  // Новые переменные для предыдущего полива
  bool _showLastWateringDropdown = false;
  String _selectedLastWateringPeriod = '1 неделю назад';
  final List<String> _lastWateringPeriods = [
    'Вчера',
    '1 неделю назад',
    '2 недели назад',
    '3 недели назад',
    '1 месяц назад',
    '2 месяца назад'
  ];
  int _selectedLastWateringPeriodIndex = 1; // Индекс для '1 неделю назад'

  // Контроллер для пользовательской задачи
  final TextEditingController _customTaskController = TextEditingController();
  bool _showCustomTaskInput = false;
  
  // Контроллер для скролла и ключ для карточки напоминания
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _reminderCardKey = GlobalKey();

  // Контроллеры для списков (создаем динамически)
  FixedExtentScrollController? _valueScrollController;
  FixedExtentScrollController? _unitScrollController;

  // Новые контроллеры для времени (создаем динамически)
  FixedExtentScrollController? _hourScrollController;
  FixedExtentScrollController? _minuteScrollController;

  // Новые контроллеры для предыдущего полива
  final FixedExtentScrollController _lastWateringController =
      FixedExtentScrollController(initialItem: 1);

  // ==== НОВОЕ: данные коллекции пользователя ====
  // Полный JSON каждой записи растения из API /plants
  List<Map<String, dynamic>> _userPlants = [];
  // Выбранное растение (если оно не передано через widget.plantData)
  PlantInfo? _selectedPlantInfo;
  String? _selectedPlantId; // id из /api/plants
  String? _selectedPlantScanId; // scan_id из /api/plants

  @override
  void initState() {
    super.initState();
    _initializePlantName();
    
    // Если передано напоминание для редактирования, загружаем его данные
    if (widget.reminderToEdit != null) {
      _currentReminder = widget.reminderToEdit;
      _loadReminderToForm(widget.reminderToEdit!);
    } else {
      _initializeAutomationData();
    }
    
    // Создаем контроллеры с правильными начальными значениями ПОСЛЕ загрузки данных
    _initializeScrollControllers();
    
    _initializeReminderDropdown(); // Новый метод для инициализации состояния блока
    
    // Если передано напоминание для редактирования, настраиваем режим редактирования
    if (widget.reminderToEdit != null) {
      _existingReminders = [widget.reminderToEdit!]; // Добавляем в список существующих напоминаний
    } else {
      _checkExistingReminders(); // Проверяем существующие напоминания
    }
    
    // Загружаем коллекцию пользователя, чтобы позволить выбор растения
    _fetchUserPlants();
  }

  // Новый метод для инициализации контроллеров скролла
  void _initializeScrollControllers() {
    // Контроллеры для повторения
    _valueScrollController = FixedExtentScrollController(initialItem: _selectedValueIndex);
    _unitScrollController = FixedExtentScrollController(initialItem: _selectedUnitIndex);
    
    // Контроллеры для времени
    _hourScrollController = FixedExtentScrollController(initialItem: _selectedHourIndex);
    _minuteScrollController = FixedExtentScrollController(initialItem: _selectedMinuteIndex);
    
    print('🎛️ Контроллеры инициализированы:');
    print('  Value: $_selectedValueIndex ($_selectedRepeatValue)');
    print('  Unit: $_selectedUnitIndex ($_selectedRepeatUnit)');
    print('  Hour: $_selectedHourIndex ($_selectedHour)');
    print('  Minute: $_selectedMinuteIndex ($_selectedMinute)');
  }

  // Новый метод для инициализации состояния блока "Напомни мне"
  void _initializeReminderDropdown() {
    // Если НЕ пришли из кнопки полива - открываем блок сразу
    if (!widget.openFromWatering) {
      _showReminderDropdown = true;
    }
  }

  // Инициализация названия растения
  void _initializePlantName() {
    if (widget.plantData != null && widget.plantData is PlantInfo) {
      final plantInfo = widget.plantData as PlantInfo;
      _selectedPlant = plantInfo.name;
    } else {
      _selectedPlant = 'Растение';
    }
  }

  // Умная навигация в зависимости от контекста
  void _navigateBack() {
    if (widget.fromScanHistory || widget.fromReminderEdit) {
      // Если пришли из истории сканирования или редактирования напоминания - возвращаемся назад
      Navigator.of(context).pop();
    } else {
      // Если пришли после сканирования - переходим на главный экран
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => HomeScreen(initialIndex: 0),
        ),
        (route) => false,
      );
    }
  }

  // ==== ЗАГРУЗКА КОЛЛЕКЦИИ РАСТЕНИЙ ПОЛЬЗОВАТЕЛЯ ====
  Future<void> _fetchUserPlants() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isEmpty) return;

      final scanService = ScanService();
      final collection = await scanService.getUserPlantCollection(token);

      if (!mounted) return;
      setState(() {
        _userPlants = List<Map<String, dynamic>>.from(collection);
      });

      // Если открыто из календаря (нет выбранного растения) – сразу показываем выбор
      if (_selectedPlant == 'Растение' && _userPlants.isNotEmpty) {
        // Небольшая задержка, чтобы сначала построился экран
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openPlantSelectionDialog();
        });
      }
    } catch (e) {
      print('Ошибка при загрузке коллекции растений: $e');
    }
  }

  // ==== МОДАЛЬНОЕ ОКНО ВЫБОРА РАСТЕНИЯ ====
  void _openPlantSelectionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.6,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==== РУЧКА ДЛЯ ПЕРЕТАЩКИ ====
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // ==== ЗАГОЛОВОК ====
                Text(
                  'Выберите растение',
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _black,
                  ),
                ),
                const SizedBox(height: 6),
                // ==== ПОДЗАГОЛОВОК ====
                Text(
                  'Это обязательный шаг. Пожалуйста, укажите растение, для которого хотите установить напоминание.',
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                // ==== СПИСОК ====
                Expanded(
                  child: ListView.separated(
                    itemCount: _userPlants.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final plant = _userPlants[index];
                      final name = plant['name']?.toString() ?? 'Без названия';
                      String? imageUrl;
                      if (plant['images'] is Map && plant['images']['thumbnail'] != null) {
                        imageUrl = plant['images']['thumbnail'].toString();
                      }

                      return ListTile(
                        leading: imageUrl != null && imageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  imageUrl,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Text('🌱', style: TextStyle(fontSize: 24)),
                                ),
                              )
                            : const Text('🌱', style: TextStyle(fontSize: 24)),
                        title: Text(name, style: const TextStyle(fontFamily: _fontFamily)),
                        onTap: () {
                          setState(() {
                            _selectedPlant = name;
                            _selectedPlantInfo = PlantInfo.fromJson(plant);
                            _selectedPlantId = plant['id'] ?? plant['_id'];
                            _selectedPlantScanId = plant['scan_id']?.toString();
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
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
  void dispose() {
    _valueScrollController?.dispose();
    _unitScrollController?.dispose();
    _hourScrollController?.dispose();
    _minuteScrollController?.dispose();
    _lastWateringController.dispose();
    _customTaskController.dispose(); // Не забываем dispose контроллера
    _scrollController.dispose(); // Не забываем dispose скролл контроллера
    super.dispose();
  }

  // Метод для получения рекомендаций по поливу из данных растения
  String _getWateringRecommendations() {
    print('💧 === ПОЛУЧЕНИЕ РЕКОМЕНДАЦИЙ ПО ПОЛИВУ ===');
    
    if (widget.plantData != null && widget.plantData is PlantInfo) {
      final plantInfo = widget.plantData as PlantInfo;
      
      print('🌱 Растение: ${plantInfo.name}');
      print('📊 careInfo ключи: ${plantInfo.careInfo.keys.join(", ")}');
      
      // Новая структура: ищем в care_info.watering.description
      if (plantInfo.careInfo.containsKey('watering') && plantInfo.careInfo['watering'] is Map) {
        final watering = plantInfo.careInfo['watering'] as Map<String, dynamic>;
        print('✅ Найден блок watering: ${watering.keys.join(", ")}');
        
        // Получаем описание для пользователя
        if (watering.containsKey('description') && watering['description'] != null) {
          final description = watering['description'].toString();
          if (description.isNotEmpty && description != 'data_not_available') {
            print('✅ Найдено описание полива: $description');
            return description;
          }
        }
        
        // Если есть automation данные, формируем описание из них
        if (watering.containsKey('automation') && watering['automation'] is Map) {
          final automation = watering['automation'] as Map<String, dynamic>;
          print('🤖 Найдены automation данные: $automation');
          
          String autoDescription = _generateWateringDescriptionFromAutomation(automation);
          if (autoDescription.isNotEmpty) {
            print('✅ Сформировано описание из automation: $autoDescription');
            return autoDescription;
          }
        }
      }
      
      // Проверяем старую структуру для совместимости
      final careInfo = plantInfo.careInfo;
      String? wateringInfo;
      
      // Проверяем специфические ключи для полива (старая структура)
      wateringInfo ??= _extractCleanText(careInfo['полив']);
      wateringInfo ??= _extractCleanText(careInfo['Полив']);
      wateringInfo ??= _extractCleanText(careInfo['water']);
      wateringInfo ??= _extractCleanText(careInfo['водный_режим']);
      
      if (wateringInfo != null && wateringInfo.isNotEmpty) {
        print('✅ Найдена информация о поливе (старая структура): $wateringInfo');
        return wateringInfo;
      }
      
      // Если нет информации в careInfo, проверяем description
      final description = plantInfo.description;
      if (description.isNotEmpty && description != 'data_not_available') {
        if (description.toLowerCase().contains('полив') || 
            description.toLowerCase().contains('влаг') ||
            description.toLowerCase().contains('воды') ||
            description.toLowerCase().contains('water')) {
          print('✅ Найдена информация в описании растения: $description');
          return description;
        }
      }
      
      print('❌ Специфическая информация о поливе не найдена');
    } else {
      print('❌ plantData отсутствует или неверный тип');
    }
    
    print('🔄 Используем общие рекомендации по поливу');
    print('💧 === КОНЕЦ ПОЛУЧЕНИЯ РЕКОМЕНДАЦИЙ ===\n');
    
    // Возвращаем общие рекомендации если нет данных о конкретном растении
    return 'Поливайте растение умеренно, избегая переувлажнения почвы. Проверяйте влажность земли перед поливом. В зимний период сократите частоту полива. Используйте воду комнатной температуры.';
  }

  // Новый метод для формирования описания из automation данных
  String _generateWateringDescriptionFromAutomation(Map<String, dynamic> automation) {
    print('🤖 Формирование описания из automation данных');
    
    List<String> parts = [];
    
    // Интервал полива
    if (automation.containsKey('interval_days') && automation['interval_days'] != null) {
      final intervalDays = automation['interval_days'];
      if (intervalDays is int && intervalDays > 0) {
        if (intervalDays == 1) {
          parts.add('Поливайте ежедневно');
        } else if (intervalDays == 7) {
          parts.add('Поливайте раз в неделю');
        } else if (intervalDays == 14) {
          parts.add('Поливайте раз в две недели');
        } else {
          parts.add('Поливайте каждые $intervalDays дней');
        }
      }
    }
    
    // Время полива
    if (automation.containsKey('time_of_day') && automation['time_of_day'] != null) {
      final timeOfDay = automation['time_of_day'].toString();
      if (timeOfDay != 'data_not_available') {
        switch (timeOfDay) {
          case 'morning':
            parts.add('утром');
            break;
          case 'evening':
            parts.add('вечером');
            break;
          case 'afternoon':
            parts.add('днем');
            break;
        }
      }
    }
    
    // Количество воды
    if (automation.containsKey('amount') && automation['amount'] != null) {
      final amount = automation['amount'].toString();
      if (amount != 'data_not_available' && amount.isNotEmpty) {
        parts.add('используя $amount');
      }
    }
    
    // Тип воды
    if (automation.containsKey('water_type') && automation['water_type'] != null) {
      final waterType = automation['water_type'].toString();
      if (waterType != 'data_not_available' && waterType.isNotEmpty) {
        parts.add('$waterType воду');
      }
    }
    
    String result = parts.join(', ');
    if (result.isNotEmpty) {
      result = result[0].toUpperCase() + result.substring(1) + '.';
    }
    
    print('✅ Сформированное описание: $result');
    return result;
  }

  // Метод для получения automation данных и настройки интерфейса
  void _initializeAutomationData() {
    print('🤖 === ИНИЦИАЛИЗАЦИЯ AUTOMATION ДАННЫХ ===');
    
    if (widget.plantData != null && widget.plantData is PlantInfo) {
      final plantInfo = widget.plantData as PlantInfo;
      
      // Получаем automation данные для полива
      final wateringAutomation = plantInfo.getWateringAutomation();
      if (wateringAutomation != null) {
        print('✅ Найдены automation данные для полива');
        
        // Устанавливаем интервал
        if (wateringAutomation.containsKey('interval_days') && wateringAutomation['interval_days'] != null) {
          final intervalDays = wateringAutomation['interval_days'];
          if (intervalDays is int && intervalDays > 0) {
            _selectedRepeatValue = intervalDays.toString();
            _selectedRepeatUnit = 'дней';
            
            // Находим индекс в списке значений
            final valueIndex = _repeatValues.indexOf(_selectedRepeatValue);
            if (valueIndex != -1) {
              _selectedValueIndex = valueIndex;
            }
            
            print('📅 Установлен интервал: $_selectedRepeatValue $_selectedRepeatUnit');
          }
        }
        
        // Устанавливаем время полива
        if (wateringAutomation.containsKey('time_of_day') && wateringAutomation['time_of_day'] != null) {
          final timeOfDay = wateringAutomation['time_of_day'].toString();
          switch (timeOfDay) {
            case 'morning':
              _selectedHour = '09';
              _selectedMinute = '00';
              _selectedHourIndex = 9;
              _selectedMinuteIndex = 0;
              break;
            case 'evening':
              _selectedHour = '18';
              _selectedMinute = '00';
              _selectedHourIndex = 18;
              _selectedMinuteIndex = 0;
              break;
            case 'afternoon':
              _selectedHour = '14';
              _selectedMinute = '00';
              _selectedHourIndex = 14;
              _selectedMinuteIndex = 0;
              break;
          }
          print('⏰ Установлено время: $_selectedHour:$_selectedMinute (${timeOfDay})');
        }
      } else {
        print('❌ Automation данные для полива не найдены, используем значения по умолчанию');
      }
    }
    
    print('🤖 === КОНЕЦ ИНИЦИАЛИЗАЦИИ AUTOMATION ===\n');
  }

  // Метод для создания или обновления напоминания через API
  Future<void> _createReminder() async {
    final isUpdating = _currentReminder != null;
    print('==== SetReminderScreen: ${isUpdating ? "ОБНОВЛЕНИЕ" : "СОЗДАНИЕ"} НАПОМИНАНИЯ ====');
    print('Тип напоминания: $_selectedReminderType');
    print('Время: $_selectedHour:$_selectedMinute');
    print('Интервал: $_selectedRepeatValue $_selectedRepeatUnit');
    if (isUpdating) {
      print('Редактируем существующее напоминание ID: ${_currentReminder!.id}');
    }
    
    // Проверяем, выбрано ли растение либо передано через параметр
    if ((widget.plantData == null || !(widget.plantData is PlantInfo)) && _selectedPlantInfo == null) {
      print('⚠️ Растение не выбрано');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите растение для создания напоминания')),
      );
      return;
    }

    // Запрашиваем разрешения для пуш-уведомлений (только при создании нового)
    if (!isUpdating) {
      await _requestNotificationPermissions();
      // Если пользователь отказал, просто продолжаем без дополнительных сообщений.
    }
    
    try {
      // Показываем индикатор загрузки
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: _greenAccent),
        ),
      );
      
      // Получаем токен
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      if (token.isEmpty) {
        throw Exception('Нет токена авторизации');
      }
      
      final PlantInfo plantInfo = widget.plantData != null && widget.plantData is PlantInfo
          ? widget.plantData as PlantInfo
          : _selectedPlantInfo!;
      
      // Определяем правильный scan_id для бэкенда
      String plantIdForBackend;
      if (widget.plantData != null && widget.plantData is PlantInfo) {
        // Если растение передано через параметр
        plantIdForBackend = (widget.plantData as PlantInfo).scanId;
      } else if (_selectedPlantScanId != null && _selectedPlantScanId!.isNotEmpty) {
        // Если растение выбрано из списка
        plantIdForBackend = _selectedPlantScanId!;
      } else {
        throw Exception('Не удалось определить ID растения для создания напоминания');
      }
      
      print('🔍 plantIdForBackend: $plantIdForBackend');
      
      // Определяем тип напоминания на английском для API
      String reminderType;
      String? customReminderType; // Для хранения оригинального типа
      
      switch (_selectedReminderType) {
        case 'Полив':
          reminderType = ReminderTypes.watering;
          break;
        case 'Орошение':
          reminderType = ReminderTypes.spraying;
          break;
        case 'Удобрение':
          reminderType = ReminderTypes.fertilizing;
          break;
        case 'Пересадка':
          reminderType = ReminderTypes.transplanting;
          break;
        case 'Обрезка':
          reminderType = ReminderTypes.pruning;
          break;
        case 'Обработка от вредителей':
          reminderType = ReminderTypes.pestControl;
          break;
        case 'Обработка от болезней':
          reminderType = ReminderTypes.diseaseControl;
          break;
        case 'Вращение':
          // ВРЕМЕННОЕ РЕШЕНИЕ: используем pruning (обрезка) как базовый тип
          // но сохраняем оригинальный тип в note для правильного отображения
          reminderType = ReminderTypes.pruning;
          customReminderType = 'rotation';
          break;
        case 'Моя задача':
          // ВРЕМЕННОЕ РЕШЕНИЕ: используем pruning как базовый тип
          // но сохраняем оригинальный тип в note для правильного отображения
          reminderType = ReminderTypes.pruning;
          customReminderType = 'custom_task';
          break;
        default:
          reminderType = ReminderTypes.watering;
      }
      
      // Определяем время дня
      String timeOfDay;
      final hour = int.parse(_selectedHour);
      if (hour >= 6 && hour < 12) {
        timeOfDay = 'morning';
      } else if (hour >= 12 && hour < 18) {
        timeOfDay = 'afternoon';
      } else {
        timeOfDay = 'evening';
      }
      
      // Создаем правильную логику дней недели и времени
      final now = DateTime.now();
      final selectedHour = int.parse(_selectedHour);
      final selectedMinute = int.parse(_selectedMinute);
      
      // Создаем время напоминания
      DateTime reminderDate;
      List<int> daysOfWeek = [];
      
      final intervalValue = int.parse(_selectedRepeatValue);
      final todayAtSelectedTime = DateTime(now.year, now.month, now.day, selectedHour, selectedMinute);
      
      // ИСПРАВЛЕНИЕ: Разная логика для создания и редактирования напоминаний
      if (isUpdating && _currentReminder != null) {
        // ПРИ РЕДАКТИРОВАНИИ: используем исходную дату как базовую
        final originalDate = _currentReminder!.date;
        final baseDate = DateTime(originalDate.year, originalDate.month, originalDate.day, selectedHour, selectedMinute);
        
        print('🔄 Редактирование: базовая дата ${baseDate.day}.${baseDate.month}.${baseDate.year}');
        reminderDate = baseDate; // Ключевой день остается тем же
        daysOfWeek = []; // Интервальные напоминания
        
      } else {
        // ПРИ СОЗДАНИИ: обычная логика
        
        // Универсальная логика для всех единиц времени
        if (_selectedRepeatUnit == 'дней') {
          // Интервальные напоминания в днях
          daysOfWeek = []; // Не используем daysOfWeek для интервальных напоминаний
          
          if (now.isBefore(todayAtSelectedTime)) {
            // Время ещё не прошло - первое напоминание сегодня
            reminderDate = todayAtSelectedTime;
          } else {
            // Время уже прошло - первое напоминание завтра
            reminderDate = todayAtSelectedTime.add(Duration(days: 1));
          }
          
        } else if (_selectedRepeatUnit == 'недель') {
          // Интервальные напоминания в неделях
          daysOfWeek = []; // Не используем daysOfWeek для интервальных напоминаний
          
          if (now.isBefore(todayAtSelectedTime)) {
            // Время ещё не прошло - первое напоминание сегодня
            reminderDate = todayAtSelectedTime;
          } else {
            // Время уже прошло - первое напоминание завтра
            reminderDate = todayAtSelectedTime.add(Duration(days: 1));
          }
          
        } else if (_selectedRepeatUnit == 'месяцев') {
          // Интервальные напоминания в месяцах
          daysOfWeek = []; // Не используем daysOfWeek для интервальных напоминаний
          
          if (now.isBefore(todayAtSelectedTime)) {
            // Время ещё не прошло - первое напоминание сегодня
            reminderDate = todayAtSelectedTime;
          } else {
            // Время уже прошло - первое напоминание завтра
            reminderDate = todayAtSelectedTime.add(Duration(days: 1));
          }
        } else {
          // Fallback для неизвестных единиц времени
          daysOfWeek = [];
          reminderDate = todayAtSelectedTime;
        }
      }
      
      // Создаем объект напоминания
      String noteText;
      
      // Если выбрана "Моя задача" и есть пользовательский текст
      if (_selectedReminderType == 'Моя задача' && _customTaskController.text.trim().isNotEmpty) {
        noteText = '[CUSTOM_TASK]${_customTaskController.text.trim()}';
      } else if (_selectedReminderType == 'Вращение') {
        noteText = '[ROTATION]Повернуть растение ${plantInfo.name}';
      } else {
        noteText = 'Автоматическое напоминание: ${_selectedReminderType.toLowerCase()} для ${plantInfo.name}';
      }
      
      final reminder = Reminder(
        id: isUpdating ? _currentReminder!.id : null, // Сохраняем ID при обновлении
        userId: '', // Пустое поле - ID пользователя извлекается из JWT токена на бэкенде
        plantId: plantIdForBackend,
        type: reminderType,
        timeOfDay: timeOfDay,
        daysOfWeek: daysOfWeek,
        repeatWeekly: false, // Убираем старую логику еженедельных напоминаний
        intervalDays: _selectedRepeatUnit == 'дней' ? intervalValue : null,
        intervalWeeks: _selectedRepeatUnit == 'недель' ? intervalValue : null,
        intervalMonths: _selectedRepeatUnit == 'месяцев' ? intervalValue : null,
        date: reminderDate,
        note: noteText, // Используем пользовательский текст для "Моя задача"
        isActive: true,
      );
      
      // Отправляем запрос на создание или обновление напоминания
      final reminderService = ReminderService();
      Reminder? resultReminder;
      
      if (isUpdating && _currentReminder!.id != null) {
        // Обновляем существующее напоминание
        resultReminder = await reminderService.updateReminder(token, _currentReminder!.id!, reminder);
      } else {
        // Создаем новое напоминание
        resultReminder = await reminderService.createReminder(token, reminder);
      }
      
      // Закрываем индикатор загрузки
      Navigator.pop(context);
      
      if (resultReminder != null) {
        // Отправляем событие о создании/обновлении напоминания
        if (isUpdating) {
          PlantEvents().notifyReminderUpdated(resultReminder.id!, plantId: plantIdForBackend);
        } else {
          PlantEvents().notifyReminderCreated(resultReminder.id!, plantId: plantIdForBackend);
        }
        
        // ИСПРАВЛЕНИЕ БАГА: Отправляем событие об обновлении коллекции
        // чтобы MyDachaPage обновил отображение растений
        PlantEvents().notifyUpdate();
        print('🔄 Отправлено событие обновления коллекции после создания/обновления напоминания');
        
        // Успешно создано/обновлено напоминание
        final action = isUpdating ? 'обновлено' : 'создано';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Напоминание "$_selectedReminderType" успешно $action для ${plantInfo.name}!'))
        );
        
        // НОВОЕ: Проверяем достижения после создания напоминания (только при создании нового)
        if (!isUpdating) {
          final achievementManager = AchievementManager();
          await achievementManager.checkReminderAchievements(
            context,
            reminderType: reminderType,
            plantId: plantIdForBackend,
          );
        }
        
        _navigateBack();
      } else {
        throw Exception('Не удалось ${isUpdating ? "обновить" : "создать"} напоминание');
      }
      
    } catch (e) {
      // Закрываем индикатор загрузки если он открыт
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      // Специальная обработка для PlantNotFoundError
      String errorMessage;
      if (e is PlantNotFoundError) {
        errorMessage = 'Растение не найдено или недоступно. Возможно, оно было удалено.';
        print('🚨 PlantNotFoundError: ${e.message}');
      } else {
        errorMessage = 'Ошибка ${isUpdating ? "обновления" : "создания"} напоминания: ${e.toString()}';
        print('Ошибка при ${isUpdating ? "обновлении" : "создании"} напоминания: $e');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage))
      );
    }
    print('==== КОНЕЦ ${isUpdating ? "ОБНОВЛЕНИЯ" : "СОЗДАНИЯ"} НАПОМИНАНИЯ ====');
  }

  // Метод для удаления напоминания
  Future<void> _deleteReminder() async {
    if (_currentReminder == null || _currentReminder!.id == null) {
      return;
    }

    // Показываем диалог подтверждения
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить напоминание?'),
        content: Text('Вы уверены, что хотите удалить напоминание "$_selectedReminderType"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      // Показываем индикатор загрузки
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: _greenAccent),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final reminderService = ReminderService();
      final success = await reminderService.deleteReminder(token, _currentReminder!.id!);

      // Закрываем индикатор загрузки
      Navigator.pop(context);

      if (success) {
        // Отправляем событие об удалении напоминания
        PlantEvents().notifyReminderDeleted(_currentReminder!.id!, plantId: _currentReminder!.plantId);
        
        // ИСПРАВЛЕНИЕ БАГА: Отправляем событие об обновлении коллекции
        // чтобы MyDachaPage обновил отображение растений
        PlantEvents().notifyUpdate();
        print('🔄 Отправлено событие обновления коллекции после удаления напоминания');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Напоминание успешно удалено!'))
        );
        _navigateBack();
      } else {
        throw Exception('Не удалось удалить напоминание');
      }

    } catch (e) {
      // Закрываем индикатор загрузки если он открыт
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      print('Ошибка при удалении напоминания: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка удаления напоминания: ${e.toString()}'))
      );
    }
  }

  // Метод для добавления растения в коллекцию
  Future<void> _addPlantToCollection({bool withReminder = false}) async {
    print('==== SetReminderScreen: ДОБАВЛЕНИЕ РАСТЕНИЯ ====');
    print('withReminder: $withReminder');
    print('plantData: ${widget.plantData}');
    
    // Определяем источник данных растения
    PlantInfo? plantInfo;
    if (widget.plantData != null && widget.plantData is PlantInfo) {
      plantInfo = widget.plantData as PlantInfo;
    } else if (_selectedPlantInfo != null) {
      plantInfo = _selectedPlantInfo;
    }

    if (plantInfo == null) {
      print('⚠️ Нет данных о растении для добавления');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выберите растение')),
      );
      return;
    }
    
    try {
      // Показываем индикатор загрузки
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: _greenAccent),
        ),
      );
      
      // Получаем токен
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      final scanService = ScanService();
      
      // Выбираем метод добавления в зависимости от наличия scanId
      Map<String, dynamic> result;
      if (plantInfo is PlantInfo) {
        if (plantInfo.scanId.isNotEmpty) {
          print('Добавляем через scanId: ${plantInfo.scanId}');
          result = await scanService.addPlantToCollection(plantInfo.scanId, token, plantInfo);
        } else {
          print('Добавляем по полным данным');
          result = await scanService.addPlantToCollection('', token, plantInfo);
        }
      } else {
        print('❌ plantData не является PlantInfo');
        throw Exception('Неверный тип данных растения');
      }
      
      // Закрываем индикатор загрузки
      Navigator.pop(context);
      
      if (result['success'] == true) {
        if (withReminder) {
          // Растение добавлено, теперь создаем напоминание
          print('Растение добавлено успешно, создаем напоминание...');
          await _createReminder();
          // Сообщение об успехе показывается в _createReminder()
        } else {
          // Показываем сообщение об успешном добавлении без напоминания
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Растение добавлено в коллекцию!'))
          );
          // Используем умную навигацию
          _navigateBack();
        }
      } else if (result['already_exists'] == true) {
        // Растение уже существует в коллекции
        print('🔄 Растение уже в коллекции, обрабатываем соответственно...');
        if (withReminder) {
          // Растение уже в коллекции, просто создаем напоминание
          print('Растение уже в коллекции, создаем напоминание...');
          await _createReminder();
          // Сообщение об успехе показывается в _createReminder()
        } else {
          // Уведомляем пользователя что растение уже в коллекции
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Растение уже есть в вашей коллекции'))
          );
          // Используем умную навигацию
          _navigateBack();
        }
      } else {
        // Показываем ошибку
        String errorMessage = result['message'] ?? 'Ошибка при добавлении растения';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage))
        );
      }
    } catch (e) {
      // Закрываем индикатор загрузки если он открыт
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      print('Ошибка при добавлении растения: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: ${e.toString()}'))
      );
    }
    print('==== КОНЕЦ ДОБАВЛЕНИЯ РАСТЕНИЯ ====');
  }

  final List<Map<String, String>> _reminderOptions = [
    {
      'asset': 'assets/images/screen_napominanie/rek_poliv.svg',
      'label': 'Полив'
    },
    {
      'asset': 'assets/images/screen_napominanie/oroshenie.svg',
      'label': 'Орошение'
    },
    {
      'asset': 'assets/images/screen_napominanie/udobrenie.svg',
      'label': 'Удобрение'
    },
    {
      'asset': 'assets/images/screen_napominanie/udobrenie.svg',
      'label': 'Обработка от вредителей'
    },
    {
      'asset': 'assets/images/screen_napominanie/udobrenie.svg',
      'label': 'Обработка от болезней'
    },
    {
      'asset': 'assets/images/screen_napominanie/vrashat.svg',
              'label': 'Вращение'
    },
    {
      'asset': 'assets/images/screen_napominanie/moya_zadacha.svg',
      'label': 'Моя задача'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      resizeToAvoidBottomInset: true, // Важно для работы с клавиатурой
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(0.00, -1.00),
            end: Alignment(0, 1),
            colors: [_white, _lightGreenBg],
          ),
        ),
        child: Column(
          children: [
            // Основная область с прокруткой
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController, // Добавляем контроллер скролла
                padding: EdgeInsets.only(
                  bottom: 20, // Убираем большой отступ снизу
                ),
                child: Column(
                  children: [
                    _buildHeader(context, screenWidth),
                    const SizedBox(height: 15),
                    _buildCards(context, screenWidth),
                    SizedBox(height: screenWidth * 0.05),
                  ],
                ),
              ),
            ),
            // Нижняя навигация (теперь фиксированная внизу)
            _buildBottomNavBar(context),
          ],
        ),
      ),
    );
  }

  // Шапка экрана
  Widget _buildHeader(BuildContext context, double screenWidth) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + screenWidth * 0.04,
        left: screenWidth * 0.05,
        right: screenWidth * 0.05,
        bottom: screenWidth * 0.03,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => _navigateBack(),
            child: SizedBox(
              width: screenWidth * 0.06,
              height: screenWidth * 0.06,
              child: SvgPicture.asset(
                'assets/images/plant_result_zdorovoe/Group 63.svg', // крестик
                colorFilter:
                    const ColorFilter.mode(_greenAccent, BlendMode.srcIn),
              ),
            ),
          ),
          const Spacer(),
          Text(
            _existingReminders.isNotEmpty ? 'Изменить напоминание' : 'Установить напоминание',
            style: TextStyle(
              color: const Color(0xFF1F2024),
              fontSize: screenWidth * 0.045,
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  // Карточка выбора растения (кликабельная для выбора из коллекции)
  Widget _buildPlantCard(double screenWidth) {
    final cardWidth = screenWidth - screenWidth * 0.10;
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05, vertical: screenWidth * 0.02),
      child: InkWell(
        onTap: () {
          if (_userPlants.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Сначала добавьте растение в коллекцию')),
            );
          } else {
            _openPlantSelectionDialog();
          }
        },
        child: Container(
          width: cardWidth,
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: _shadowColor,
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            height: 65,
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/images/screen_napominanie/rastenie.svg',
                  width: screenWidth * 0.06,
                  height: screenWidth * 0.06,
                ),
                SizedBox(width: screenWidth * 0.04),
                Text(
                  'Растение',
                  style: TextStyle(
                    color: _black,
                    fontSize: screenWidth * 0.04,
                    fontFamily: _fontFamily,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  _selectedPlant,
                  style: TextStyle(
                    color: _black,
                    fontSize: screenWidth * 0.03,
                    fontFamily: _fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Центральные карточки
  Widget _buildCards(BuildContext context, double screenWidth) {
    final cardWidth = screenWidth - screenWidth * 0.10;
    return Column(
      children: [
        _buildPlantCard(screenWidth),
        const SizedBox(height: 8),
        _buildReminderCard(screenWidth),
        // Повторить
        _buildRepeatCard(screenWidth),
        // Рекомендации по поливу
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05, vertical: screenWidth * 0.02),
          child: Container(
            width: cardWidth,
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: _shadowColor,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SvgPicture.asset(
                      'assets/images/screen_napominanie/rek_poliv.svg',
                      width: screenWidth * 0.06,
                      height: screenWidth * 0.06,
                    ),
                    SizedBox(width: screenWidth * 0.04),
                    Text(
                      'Рекомендации по поливу',
                      style: TextStyle(
                        color: _black,
                        fontSize: screenWidth * 0.04,
                        fontFamily: _fontFamily,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: screenWidth * 0.02),
                Text(
                  _getWateringRecommendations(),
                  style: TextStyle(
                    color: _black,
                    fontSize: screenWidth * 0.03,
                    fontFamily: _fontFamily,
                    height: 1.4,
                  ),
                ),
                // Убираем некликабельную кнопку "Добавить" согласно претензии клиента
                SizedBox(height: screenWidth * 0.02),
              ],
            ),
          ),
        ),
        // Время
        _buildTimeCard(screenWidth),
        // Предыдущий полив
        _buildLastWateringCard(screenWidth),
        // Рекомендации препаратов ИИ (показываем только для обработки от болезней/вредителей)
        if (_selectedReminderType == 'Обработка от болезней' || 
            _selectedReminderType == 'Обработка от вредителей') ...[
          _buildTreatmentRecommendationsCard(screenWidth),
        ],
      ],
    );
  }

  // Карточка выбора действия "Напомни мне"
  Widget _buildReminderCard(double screenWidth) {
    final cardWidth = screenWidth - screenWidth * 0.10;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: Container(
        key: _reminderCardKey, // Добавляем ключ для прокрутки
        width: cardWidth,
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: _shadowColor, blurRadius: 20, offset: Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => setState(
                  () => _showReminderDropdown = !_showReminderDropdown),
              child: Container(
                height: 65,
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: _showReminderDropdown
                        ? Radius.zero
                        : Radius.circular(18),
                    bottomRight: _showReminderDropdown
                        ? Radius.zero
                        : Radius.circular(18),
                  ),
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      _reminderOptions.firstWhere(
                          (o) => o['label'] == _selectedReminderType)['asset']!,
                      width: screenWidth * 0.06,
                      height: screenWidth * 0.06,
                    ),
                    SizedBox(width: screenWidth * 0.04),
                    Text('Напомни мне',
                        style: TextStyle(
                            color: _black,
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.w600,
                            fontFamily: _fontFamily)),
                    const Spacer(),
                    Text(_selectedReminderType,
                        style: TextStyle(
                            color: _black,
                            fontSize: screenWidth * 0.03,
                            fontFamily: _fontFamily)),
                  ],
                ),
              ),
            ),
            if (_showReminderDropdown)
              Padding(
                padding: EdgeInsets.all(screenWidth * 0.02),
                child: Column(
                  children: [
                    // Список опций напоминаний
                    ..._reminderOptions
                        .map((opt) => GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedReminderType = opt['label']!;
                                  // Показываем поле ввода только для "Моя задача"
                                  _showCustomTaskInput = opt['label']! == 'Моя задача';
                                });
                                
                                // Если выбрана "Моя задача", прокручиваем к полю ввода
                                if (opt['label']! == 'Моя задача') {
                                  _scrollToReminderCard();
                                }
                              },
                              child: Container(
                                height: 48,
                                margin: EdgeInsets.symmetric(vertical: 4),
                                padding: EdgeInsets.symmetric(
                                    horizontal: screenWidth * 0.03),
                                decoration: BoxDecoration(
                                    color: _selectedReminderType == opt['label']!
                                        ? Color(0xFFF4F6F5)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6)),
                                child: Row(
                                  children: [
                                    SvgPicture.asset(opt['asset']!,
                                        width: screenWidth * 0.05,
                                        height: screenWidth * 0.05),
                                    SizedBox(width: screenWidth * 0.03),
                                    Text(opt['label']!,
                                        style: TextStyle(
                                            color: _black,
                                            fontSize: screenWidth * 0.035,
                                            fontFamily: _fontFamily)),
                                  ],
                                ),
                              ),
                            ))
                        .toList(),
                    
                    // Поле ввода для пользовательской задачи
                    if (_showCustomTaskInput && _selectedReminderType == 'Моя задача')
                      Container(
                        margin: EdgeInsets.only(top: 12),
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.03,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _greenAccent.withOpacity(0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _greenAccent.withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _customTaskController,
                          autofocus: true, // Автофокус для удобства пользователя
                          maxLines: 3, // Увеличиваем количество строк
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            hintText: 'Опишите вашу задачу для растения...',
                            hintStyle: TextStyle(
                              color: Colors.grey[500],
                              fontSize: screenWidth * 0.032,
                              fontFamily: _fontFamily,
                              height: 1.4,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: TextStyle(
                            color: _black,
                            fontSize: screenWidth * 0.035,
                            fontFamily: _fontFamily,
                            height: 1.4,
                          ),
                          onSubmitted: (value) {
                            // При нажатии "Готово" убираем фокус
                            FocusScope.of(context).unfocus();
                          },
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Карточка настройки повторения
  Widget _buildRepeatCard(double screenWidth) {
    final cardWidth = screenWidth - screenWidth * 0.10;
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05, vertical: screenWidth * 0.02),
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: _shadowColor,
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _showRepeatDropdown = !_showRepeatDropdown;
                });
              },
              child: Container(
                height: 65,
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft:
                        _showRepeatDropdown ? Radius.zero : Radius.circular(18),
                    bottomRight:
                        _showRepeatDropdown ? Radius.zero : Radius.circular(18),
                  ),
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/images/screen_napominanie/povtorit.svg',
                      width: screenWidth * 0.06,
                      height: screenWidth * 0.06,
                    ),
                    SizedBox(width: screenWidth * 0.04),
                    Text(
                      'Повторить',
                      style: TextStyle(
                        color: _black,
                        fontSize: screenWidth * 0.04,
                        fontFamily: _fontFamily,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Каждые $_selectedRepeatValue $_selectedRepeatUnit',
                      style: TextStyle(
                        color: _black,
                        fontSize: screenWidth * 0.03,
                        fontFamily: _fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showRepeatDropdown)
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.03,
                    vertical: screenWidth * 0.02),
                child: Column(
                  children: [
                    // Контейнер для колеса прокрутки с градиентами
                    Container(
                      height: 110,
                      decoration: BoxDecoration(
                        color: _white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            // Градиент сверху
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      _white,
                                      _white.withOpacity(0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Градиент снизу
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      _white,
                                      _white.withOpacity(0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Центральная элегантная полоска
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  height: 28,
                                  margin: EdgeInsets.symmetric(horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFE6E8E7).withOpacity(0.65),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            // Колесо прокрутки
                            Row(
                              children: [
                                // Колесо для числа
                                Expanded(
                                  flex: 1,
                                  child: ListWheelScrollView.useDelegate(
                                    controller: _valueScrollController!,
                                    itemExtent: 35,
                                    diameterRatio: 1.8,
                                    perspective: 0.005,
                                    squeeze: 0.95,
                                    physics: const FixedExtentScrollPhysics(),
                                    onSelectedItemChanged: (int index) {
                                      setState(() {
                                        _selectedValueIndex = index;
                                        _selectedRepeatValue =
                                            _repeatValues[index];
                                      });
                                    },
                                    childDelegate:
                                        ListWheelChildBuilderDelegate(
                                      childCount: _repeatValues.length,
                                      builder: (context, index) {
                                        return Center(
                                          child: Text(
                                            _repeatValues[index],
                                            style: TextStyle(
                                              color:
                                                  _selectedValueIndex == index
                                                      ? _greenAccent
                                                      : Colors.grey,
                                              fontSize:
                                                  _selectedValueIndex == index
                                                      ? screenWidth * 0.052
                                                      : screenWidth * 0.042,
                                              fontWeight:
                                                  _selectedValueIndex == index
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                              fontFamily: _fontFamily,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                // Колесо для единицы измерения
                                Expanded(
                                  flex: 2,
                                  child: ListWheelScrollView.useDelegate(
                                    controller: _unitScrollController!,
                                    itemExtent: 35,
                                    diameterRatio: 1.8,
                                    perspective: 0.005,
                                    squeeze: 0.95,
                                    physics: const FixedExtentScrollPhysics(),
                                    onSelectedItemChanged: (int index) {
                                      setState(() {
                                        _selectedUnitIndex = index;
                                        _selectedRepeatUnit =
                                            _repeatUnits[index];
                                      });
                                    },
                                    childDelegate:
                                        ListWheelChildBuilderDelegate(
                                      childCount: _repeatUnits.length,
                                      builder: (context, index) {
                                        return Center(
                                          child: Text(
                                            _repeatUnits[index],
                                            style: TextStyle(
                                              color: _selectedUnitIndex == index
                                                  ? _greenAccent
                                                  : Colors.grey,
                                              fontSize:
                                                  _selectedUnitIndex == index
                                                      ? screenWidth * 0.042
                                                      : screenWidth * 0.032,
                                              fontWeight:
                                                  _selectedUnitIndex == index
                                                      ? FontWeight.w500
                                                      : FontWeight.normal,
                                              fontFamily: _fontFamily,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
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
      ),
    );
  }

  // Добавляем новый метод для карточки времени
  Widget _buildTimeCard(double screenWidth) {
    final cardWidth = screenWidth - screenWidth * 0.10;
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05, vertical: screenWidth * 0.02),
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: _shadowColor,
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _showTimeDropdown = !_showTimeDropdown;
                });
              },
              child: Container(
                height: 65,
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft:
                        _showTimeDropdown ? Radius.zero : Radius.circular(18),
                    bottomRight:
                        _showTimeDropdown ? Radius.zero : Radius.circular(18),
                  ),
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/images/screen_napominanie/vremya.svg',
                      width: screenWidth * 0.06,
                      height: screenWidth * 0.06,
                    ),
                    SizedBox(width: screenWidth * 0.04),
                    Text(
                      'Время напоминания',
                      style: TextStyle(
                        color: _black,
                        fontSize: screenWidth * 0.04,
                        fontFamily: _fontFamily,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$_selectedHour:$_selectedMinute',
                      style: TextStyle(
                        color: _greenAccent,
                        fontSize: screenWidth * 0.05,
                        fontFamily: _fontFamily,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showTimeDropdown)
              Container(
                height: 135,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: Stack(
                  children: [
                    // Затемнение сверху
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white,
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Затемнение снизу
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.white,
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Центральная полоска
                    Positioned(
                      left: 30,
                      right: 30,
                      top: 55,
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(0xFFEEF1EE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),

                    // Выбор времени
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Колесо для часов
                        Expanded(
                          flex: 1,
                          child: ListWheelScrollView.useDelegate(
                            controller: _hourScrollController!,
                            itemExtent: 45,
                            diameterRatio: 1.8,
                            perspective: 0.005,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (int index) {
                              setState(() {
                                _selectedHourIndex = index;
                                _selectedHour = _hours[index];
                              });
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: _hours.length,
                              builder: (context, index) {
                                return Center(
                                  child: Text(
                                    _hours[index],
                                    style: TextStyle(
                                      color: _selectedHourIndex == index
                                          ? _greenAccent
                                          : Colors.grey[400],
                                      fontSize: _selectedHourIndex == index
                                          ? screenWidth * 0.048
                                          : screenWidth * 0.038,
                                      fontWeight: _selectedHourIndex == index
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      fontFamily: _fontFamily,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // Разделитель
                        Container(
                          child: Text(
                            ":",
                            style: TextStyle(
                              color: _greenAccent,
                              fontSize: screenWidth * 0.06,
                              fontWeight: FontWeight.bold,
                              fontFamily: _fontFamily,
                            ),
                          ),
                        ),

                        // Колесо для минут
                        Expanded(
                          flex: 1,
                          child: ListWheelScrollView.useDelegate(
                            controller: _minuteScrollController!,
                            itemExtent: 45,
                            diameterRatio: 1.8,
                            perspective: 0.005,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (int index) {
                              setState(() {
                                _selectedMinuteIndex = index;
                                _selectedMinute = _minutes[index];
                              });
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: _minutes.length,
                              builder: (context, index) {
                                return Center(
                                  child: Text(
                                    _minutes[index],
                                    style: TextStyle(
                                      color: _selectedMinuteIndex == index
                                          ? _greenAccent
                                          : Colors.grey[400],
                                      fontSize: _selectedMinuteIndex == index
                                          ? screenWidth * 0.048
                                          : screenWidth * 0.038,
                                      fontWeight: _selectedMinuteIndex == index
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      fontFamily: _fontFamily,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Добавляем новый метод для карточки предыдущего полива
  Widget _buildLastWateringCard(double screenWidth) {
    final cardWidth = screenWidth - screenWidth * 0.10;
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05, vertical: screenWidth * 0.02),
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: _shadowColor,
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _showLastWateringDropdown = !_showLastWateringDropdown;
                });
              },
              child: Container(
                height: 65,
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: _showLastWateringDropdown
                        ? Radius.zero
                        : Radius.circular(18),
                    bottomRight: _showLastWateringDropdown
                        ? Radius.zero
                        : Radius.circular(18),
                  ),
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/images/screen_napominanie/rek_poliv.svg',
                      width: screenWidth * 0.06,
                      height: screenWidth * 0.06,
                    ),
                    SizedBox(width: screenWidth * 0.04),
                    Text(
                      'Предыдущий полив',
                      style: TextStyle(
                        color: _black,
                        fontSize: screenWidth * 0.04,
                        fontFamily: _fontFamily,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _selectedLastWateringPeriod,
                      style: TextStyle(
                        color: _black,
                        fontSize: screenWidth * 0.03,
                        fontFamily: _fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showLastWateringDropdown)
              Container(
                height: 135,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: Stack(
                  children: [
                    // Затемнение сверху
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white,
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Затемнение снизу
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.white,
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Центральная полоска
                    Positioned(
                      left: 30,
                      right: 30,
                      top: 55,
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(0xFFEEF1EE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),

                    // Выбор периода
                    Center(
                      child: ListWheelScrollView.useDelegate(
                        controller: _lastWateringController,
                        itemExtent: 45,
                        diameterRatio: 1.8,
                        perspective: 0.005,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (int index) {
                          setState(() {
                            _selectedLastWateringPeriodIndex = index;
                            _selectedLastWateringPeriod =
                                _lastWateringPeriods[index];
                          });
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: _lastWateringPeriods.length,
                          builder: (context, index) {
                            return Center(
                              child: Text(
                                _lastWateringPeriods[index],
                                style: TextStyle(
                                  color:
                                      _selectedLastWateringPeriodIndex == index
                                          ? _greenAccent
                                          : Colors.grey[400],
                                  fontSize:
                                      _selectedLastWateringPeriodIndex == index
                                          ? screenWidth * 0.048
                                          : screenWidth * 0.038,
                                  fontWeight:
                                      _selectedLastWateringPeriodIndex == index
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                  fontFamily: _fontFamily,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Простой ряд-карточка с иконкой, заголовком и значением
  Widget _buildSimpleCard(BuildContext context, String asset, String title,
      String value, double screenWidth,
      [bool isClickable = false]) {
    final cardWidth = screenWidth - screenWidth * 0.10;
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05, vertical: screenWidth * 0.02),
      child: Container(
        width: cardWidth,
        height: 65,
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: _shadowColor,
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              asset,
              width: screenWidth * 0.06,
              height: screenWidth * 0.06,
            ),
            SizedBox(width: screenWidth * 0.04),
            Text(
              title,
              style: TextStyle(
                color: _black,
                fontSize: screenWidth * 0.04,
                fontFamily: _fontFamily,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                color: _black,
                fontSize: screenWidth * 0.03,
                fontFamily: _fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Нижняя навигация
  Widget _buildBottomNavBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final buttonHeight = screenWidth * 0.1 < 40 ? 40.0 : screenWidth * 0.1;
    return Container(
      padding: EdgeInsets.only(
        left: screenWidth * 0.04,
        right: screenWidth * 0.04,
        top: 10,
        bottom: bottomPadding + 10,
      ),
      decoration: const BoxDecoration(
        color: _white,
        boxShadow: [
          BoxShadow(
              color: _shadowColor,
              blurRadius: 20,
              offset: Offset(0, -4),
              spreadRadius: 0),
        ],
      ),
      child: Row(
        children: [
          // Иконки слева с обработчиками
          SizedBox(
             width: screenWidth * (widget.hideLikeButton ? 0.22 : 0.3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Поделиться
                InkWell(
                  onTap: () {
                    _sharePlant();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: SvgPicture.asset(
                    'assets/images/plant_result_zdorovoe/Group.svg',
                    width: screenWidth * 0.06,
                    height: screenWidth * 0.06,
                    colorFilter:
                        const ColorFilter.mode(_greenAccent, BlendMode.srcIn),
                  ),
                ),
                SizedBox(width: screenWidth * 0.04),
                if (!widget.hideLikeButton) ...[
                  InkWell(
                    onTap: () {
                      _toggleFavorite();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: SvgPicture.asset(
                      'assets/images/plant_result_zdorovoe/Layer_2_00000154399694884061480560000015505170056280207754_.svg',
                      width: screenWidth * 0.06,
                      height: screenWidth * 0.06,
                      colorFilter:
                          const ColorFilter.mode(_greenAccent, BlendMode.srcIn),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.04),
                ],
                // Камера
                InkWell(
                  onTap: () {
                    _openCamera();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: SvgPicture.asset(
                    'assets/images/plant_result_zdorovoe/Group 117.svg',
                    width: screenWidth * 0.06,
                    height: screenWidth * 0.06,
                    colorFilter:
                        const ColorFilter.mode(_greenAccent, BlendMode.srcIn),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Две кнопки справа
          Row(
            children: [
              // Кнопка "Позже" / "Удалить"
              Container(
                width: screenWidth * 0.2,
                height: buttonHeight,
                decoration: BoxDecoration(
                  color: _existingReminders.isNotEmpty ? Colors.red.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _existingReminders.isNotEmpty ? Colors.red : _greenAccent,
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (_existingReminders.isNotEmpty) {
                        // Есть напоминания - показываем кнопку удаления
                        _deleteReminder();
                      } else {
                        // Кнопка "Позже" - просто закрываем экран (как крестик)
                        print('Нажата кнопка "Позже" - закрываем экран');
                        _navigateBack();
                      }
                    },
                    customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    child: Center(
                      child: Text(
                        _existingReminders.isNotEmpty ? 'Удалить' : 'Позже',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _existingReminders.isNotEmpty ? Colors.red : _greenAccent,
                          fontSize: screenWidth * 0.032,
                          fontFamily: _fontFamily,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: screenWidth * 0.03), // Отступ между кнопками
              // Кнопка "Установить"
              Container(
                width: screenWidth * 0.25,
                height: buttonHeight,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment(0.00, -1.00),
                    end: Alignment(0, 1),
                    colors: [Color(0xFF78B065), Color(0xFF388D78)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                        color: _shadowColor,
                        blurRadius: 20,
                        offset: Offset(0, 4),
                        spreadRadius: 0)
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      // ПРИОРИТЕТ 1: Если растение уже в коллекции или выбрано из списка - просто создаем напоминание
                      if (widget.isPlantAlreadyInCollection || _selectedPlantInfo != null) {
                        print('Нажата кнопка "Установить напоминание" - создаём напоминание');
                        _createReminder();
                      } 
                      // ПРИОРИТЕТ 2: Если растение передано через параметр, но НЕ в коллекции - добавляем + напоминание
                      else if (widget.plantData != null && widget.plantData is PlantInfo) {
                        print('Нажата кнопка "Установить" - добавляем растение с напоминанием');
                        _addPlantToCollection(withReminder: true);
                      }
                      // ПРИОРИТЕТ 3: Нет растения - показываем ошибку
                      else {
                        print('⚠️ Нет растения для создания напоминания');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Выберите растение для создания напоминания')),
                        );
                      }
                    },
                    customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    child: Center(
                      child: _isCheckingReminders 
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(_white),
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            widget.isPlantAlreadyInCollection 
                              ? (widget.forceAddMode ? 'Добавить напоминание' : (_existingReminders.isNotEmpty ? 'Изменить напоминание' : 'Установить напоминание'))
                              : 'Установить',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _white,
                              fontSize: screenWidth * 0.032,
                              fontFamily: _fontFamily,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Метод для проверки существующих напоминаний
  Future<void> _checkExistingReminders() async {
    if (widget.plantData == null || !(widget.plantData is PlantInfo)) {
      return;
    }

    // Если включен принудительный режим добавления - не проверяем существующие напоминания
    if (widget.forceAddMode) {
      print('🎯 Принудительный режим добавления - пропускаем проверку существующих напоминаний');
      setState(() {
        _isCheckingReminders = false;
        _existingReminders = [];
        _currentReminder = null;
      });
      return;
    }

    setState(() {
      _isCheckingReminders = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      if (token.isEmpty) {
        setState(() {
          _isCheckingReminders = false;
        });
        return;
      }

      final plantInfo = widget.plantData as PlantInfo;
      final plantId = plantInfo.scanId.isNotEmpty ? plantInfo.scanId : 'unknown';
      
      final reminderService = ReminderService();
      
      // Получаем все напоминания для этого растения
      final reminders = await reminderService.getReminders(token, plantId: plantId);
      
      setState(() {
        _existingReminders = reminders;
        if (reminders.isNotEmpty) {
          // Берем первое напоминание для редактирования
          _currentReminder = reminders.first;
          _loadReminderToForm(_currentReminder!);
        }
        _isCheckingReminders = false;
      });
      
      print('🔍 Найдено ${reminders.length} напоминаний для растения $plantId');
      
    } catch (e) {
      print('Ошибка при проверке напоминаний: $e');
      setState(() {
        _isCheckingReminders = false;
      });
    }
  }

  // Метод для загрузки данных напоминания в форму
  void _loadReminderToForm(Reminder reminder) {
    print('📝 Загружаем напоминание в форму: ${reminder.type}');
    
    // Проверяем маркеры в note для определения реального типа
    bool isRotation = reminder.note?.startsWith('[ROTATION]') ?? false;
    bool isCustomTask = reminder.note?.startsWith('[CUSTOM_TASK]') ?? false;
    
    // Устанавливаем тип напоминания
    if (isRotation) {
      _selectedReminderType = 'Вращение';
    } else if (isCustomTask) {
      _selectedReminderType = 'Моя задача';
      // Извлекаем текст задачи из note
      if (reminder.note != null) {
        _customTaskController.text = reminder.note!.substring('[CUSTOM_TASK]'.length);
      }
    } else {
      switch (reminder.type) {
        case 'watering':
          _selectedReminderType = 'Полив';
          break;
        case 'spraying':
          _selectedReminderType = 'Орошение';
          break;
        case 'fertilizing':
          _selectedReminderType = 'Удобрение';
          break;
        case 'transplanting':
          _selectedReminderType = 'Пересадка';
          break;
        case 'pruning':
          _selectedReminderType = 'Обрезка';
          break;
        case 'pest_control':
          _selectedReminderType = 'Обработка от вредителей';
          break;
        case 'disease_treatment':
          _selectedReminderType = 'Обработка от болезней';
          break;
        case 'rotation':
          _selectedReminderType = 'Вращение';
          break;
        case 'custom_task':
          _selectedReminderType = 'Моя задача';
          break;
        default:
          // КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: добавляем default case
          print('⚠️ Неизвестный тип напоминания: ${reminder.type}, оставляем как есть');
          // НЕ изменяем _selectedReminderType, оставляем существующий
          break;
      }
    }
    
    // Устанавливаем время
    final time = reminder.date;
    _selectedHour = time.hour.toString().padLeft(2, '0');
    _selectedMinute = time.minute.toString().padLeft(2, '0');
    _selectedHourIndex = time.hour;
    _selectedMinuteIndex = time.minute;
    
    // Устанавливаем интервал повторения
    print('🔄 Загружаем интервал напоминания:');
    print('  intervalDays: ${reminder.intervalDays}');
    print('  intervalWeeks: ${reminder.intervalWeeks}');
    print('  intervalMonths: ${reminder.intervalMonths}');
    print('  repeatWeekly: ${reminder.repeatWeekly}');
    
    if (reminder.intervalDays != null && reminder.intervalDays! > 0) {
      // Интервал в днях
      _selectedRepeatValue = reminder.intervalDays.toString();
      _selectedRepeatUnit = 'дней';
      _selectedValueIndex = _repeatValues.indexOf(_selectedRepeatValue);
      _selectedUnitIndex = 0;
      print('✅ Установлен интервал в днях: $_selectedRepeatValue');
      
    } else if (reminder.intervalWeeks != null && reminder.intervalWeeks! > 0) {
      // Интервал в неделях
      _selectedRepeatValue = reminder.intervalWeeks.toString();
      _selectedRepeatUnit = 'недель';
      _selectedValueIndex = _repeatValues.indexOf(_selectedRepeatValue);
      _selectedUnitIndex = 1;
      print('✅ Установлен интервал в неделях: $_selectedRepeatValue');
      
    } else if (reminder.intervalMonths != null && reminder.intervalMonths! > 0) {
      // Интервал в месяцах
      _selectedRepeatValue = reminder.intervalMonths.toString();
      _selectedRepeatUnit = 'месяцев';
      _selectedValueIndex = _repeatValues.indexOf(_selectedRepeatValue);
      _selectedUnitIndex = 2;
      print('✅ Установлен интервал в месяцах: $_selectedRepeatValue');
      
    } else if (reminder.repeatWeekly) {
      // Старая логика еженедельных напоминаний
      _selectedRepeatValue = '7';
      _selectedRepeatUnit = 'дней';
      _selectedValueIndex = _repeatValues.indexOf('7');
      _selectedUnitIndex = 0;
      print('✅ Установлен еженедельный интервал (7 дней)');
      
    } else {
      // Fallback: если не удалось определить интервал, ставим значения по умолчанию
      print('⚠️ Не удалось определить интервал, используем значения по умолчанию');
      _selectedRepeatValue = '5';
      _selectedRepeatUnit = 'дней';
      _selectedValueIndex = _repeatValues.indexOf('5');
      _selectedUnitIndex = 0;
    }
    
    // Обновляем индексы для правильной инициализации контроллеров
    if (_selectedValueIndex < 0) _selectedValueIndex = 0;
    if (_selectedUnitIndex < 0) _selectedUnitIndex = 0;
    
    print('✅ Напоминание загружено: $_selectedReminderType в $_selectedHour:$_selectedMinute');
  }

  // Новые методы для обработки кнопок нижней панели

  // Метод для функции "Поделиться"
  void _sharePlant() {
    _shareToAppStore();
  }

  void _shareToAppStore() async {
    try {
      String url;
      if (Platform.isIOS) {
        // iOS App Store URL - пока используем заглушку
        url = 'https://apps.apple.com/app/id1643109774';
      } else if (Platform.isAndroid) {
        // Google Play URL с реальным package name
        url = 'https://play.google.com/store/apps/details?id=com.dachaBezProblem.dacha_bez_problem';
      } else {
        // Для других платформ
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Функция "Поделиться" недоступна на данной платформе'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось открыть магазин приложений'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при открытии магазина: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Метод для функции "Лайк"
  void _toggleFavorite() {
    print('❤️ Нажата кнопка "Лайк"');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Функция "Добавить в избранное" будет реализована в следующих версиях'))
    );
  }

  // Метод для функции "Камера"
  void _openCamera() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ScannerScreen(),
      ),
    );
  }

  // Метод для запроса разрешений пуш-уведомлений
  Future<bool> _requestNotificationPermissions() async {
    try {
      print('📱 Проверяем статус разрешения на уведомления...');

      // 1. Проверяем текущий статус
      final status = await Permission.notification.status;

      if (status.isGranted) {
        print('🔔 Разрешение уже предоставлено, повторный запрос не требуется');
        return true;
      }

      if (status.isPermanentlyDenied) {
        print('🚫 Разрешение на уведомления было окончательно отклонено');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Разрешение на уведомления отклонено. Вы можете включить его в настройках системы.'),
            duration: Duration(seconds: 4),
          ),
        );
        return false;
      }

      // 2. Запрашиваем системное разрешение (родной системный диалог)
      final result = await Permission.notification.request();
      final granted = result.isGranted;

      print(granted ? '✅ Пользователь разрешил уведомления' : '❌ Пользователь отклонил уведомления');
      return granted;
    } catch (e) {
      print('Ошибка при запросе разрешений: $e');
      return false;
    }
  }

  // Метод для прокрутки к карточке напоминания
  void _scrollToReminderCard() {
    // Задержка для завершения анимации setState
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_reminderCardKey.currentContext != null) {
        Scrollable.ensureVisible(
          _reminderCardKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  // Вспомогательный метод для извлечения чистого текста (для обратной совместимости)
  String? _extractCleanText(dynamic value) {
    if (value == null) return null;
    
    String text = value.toString().trim();
    
    // Проверяем, не является ли это JSON строкой или служебной информацией
    if (text.isEmpty || text == 'null' || text.startsWith('{') || text.startsWith('[')) {
      return null;
    }
    
    // Убираем служебные префиксы
    if (text.startsWith('description:')) {
      text = text.substring('description:'.length).trim();
    }
    
    // Убираем кавычки если они есть в начале и конце
    if (text.startsWith('"') && text.endsWith('"')) {
      text = text.substring(1, text.length - 1);
    }
    
    // Убираем экранирование
    text = text.replaceAll('\\"', '"');
    text = text.replaceAll('\\n', '\n');
    
    return text.isNotEmpty ? text : null;
  }

  /// Карточка с рекомендациями препаратов ИИ
  Widget _buildTreatmentRecommendationsCard(double screenWidth) {
    final cardWidth = screenWidth - screenWidth * 0.10;
    
    // Проверяем здоровье растения - показываем рекомендации только для больных растений
    bool isHealthy = true;
    dynamic plantDataToCheck = widget.plantData ?? _selectedPlantInfo;
    
    if (plantDataToCheck != null) {
      if (plantDataToCheck is Map) {
        isHealthy = plantDataToCheck['is_healthy'] ?? true;
      } else {
        try {
          isHealthy = plantDataToCheck.isHealthy ?? true;
        } catch (e) {
          isHealthy = true; // По умолчанию считаем здоровым
        }
      }
    }
    
    // Если растение здоровое, не показываем блок рекомендаций
    if (isHealthy) {
      return SizedBox.shrink();
    }
    
    // Извлекаем болезни из данных растения
    final treatmentService = TreatmentService();
    List<String> diseases = [];
    
    if (widget.plantData != null) {
      diseases = treatmentService.extractDiseaseNames(widget.plantData);
    } else if (_selectedPlantInfo != null) {
      diseases = treatmentService.extractDiseaseNames(_selectedPlantInfo);
    }
    
    // Если нет болезней, не показываем карточку
    if (diseases.isEmpty) {
      return SizedBox.shrink();
    }
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05, 
        vertical: screenWidth * 0.02
      ),
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: _shadowColor,
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: TreatmentRecommendationsWidget(
          diseases: diseases,
          maxRecommendations: 4, // Увеличиваем до 4 рекомендаций
          customTitle: _selectedReminderType == 'Обработка от болезней' 
              ? '💊 Препараты от болезней'
              : '🐛 Препараты от вредителей',
          padding: EdgeInsets.all(16),
        ),
      ),
    );
  }
}
