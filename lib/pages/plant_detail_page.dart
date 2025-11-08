import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import '../services/logger.dart';
import '../widgets/favorite_button.dart';
import '../services/api/reminder_service.dart';
import '../services/api/scan_service.dart';
import '../models/reminder.dart';
import '../models/plant_info.dart';
import '../plant_result/set_reminder_screen.dart';
import '../widgets/treatment_recommendations_widget.dart';
import '../services/api/treatment_service.dart';
import '../services/plant_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlantDetailPage extends StatefulWidget {
  final Map<String, dynamic> plant;

  const PlantDetailPage({Key? key, required this.plant}) : super(key: key);

  @override
  State<PlantDetailPage> createState() => _PlantDetailPageState();
}

class _PlantDetailPageState extends State<PlantDetailPage> {
  static const String baseUrl = 'http://89.110.92.227:3002';
  
  PageController _imagePageController = PageController();
  int _currentImageIndex = 0;
  List<String> _availableImages = [];
  
  // Напоминания
  final ReminderService _reminderService = ReminderService();
  List<Reminder> _plantReminders = [];
  bool _isLoadingReminders = true;
  final ScanService _scanService = ScanService();
  
  // Подписка на события
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _loadAvailableImages();
    _loadPlantReminders();
    _subscribeToEvents();
    AppLogger.ui('Открыта детальная страница растения: ${widget.plant['name']}');
  }
  
  void _subscribeToEvents() {
    _eventSubscription = PlantEvents().stream.listen((event) {
      print('🏠 PlantDetailPage: Получено событие ${event.type}');
      
      // Обновляем напоминания при создании, обновлении или удалении
      if (event.type == PlantEventType.reminderCreated ||
          event.type == PlantEventType.reminderUpdated ||
          event.type == PlantEventType.reminderDeleted) {
        print('🔄 PlantDetailPage: Перезагружаем напоминания после события ${event.type}');
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted) {
            _loadPlantReminders();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    _eventSubscription?.cancel();
    super.dispose();
  }

  String _convertToFullUrl(String imageUrl) {
    if (imageUrl.isEmpty) return '';
    
    // Если это относительный путь, добавляем базовый URL
    if (imageUrl.startsWith('/uploads/')) {
      final fullUrl = '$baseUrl$imageUrl';
      AppLogger.ui('PlantDetail: Преобразуем относительный путь в полный URL: $fullUrl');
      return fullUrl;
    }
    
    // Если уже полный URL или локальный asset, возвращаем как есть
    AppLogger.ui('PlantDetail: Используем изображение как есть: $imageUrl');
    return imageUrl;
  }

  void _loadAvailableImages() {
    // Детальное логирование структуры растения
    AppLogger.ui('Анализируем изображения растения: ${widget.plant['name']}');
    AppLogger.ui('Полная структура данных растения: ${widget.plant}');
    
    final images = widget.plant['images'] as Map? ?? {};
    _availableImages = [];
    
    AppLogger.ui('Поле images из API: $images');
    
    // Собираем все доступные изображения из разных возможных полей
    // Приоритет: сначала кроп/thumbnail, затем основные изображения
    final imageKeys = [
      'thumbnail', 'crop', 'main_image', 'user_image', 'original_image', 'scan_image',
      'original', 'main', 'avatar', 'photo', 'picture'
    ];
    
    for (String key in imageKeys) {
      if (images[key] != null && images[key].toString().isNotEmpty) {
        final imageUrl = _convertToFullUrl(images[key].toString());
        AppLogger.ui('Найдено изображение [$key]: $imageUrl');
        _availableImages.add(imageUrl);
      }
    }
    
    // Если в images ничего нет, проверяем другие поля растения
    if (_availableImages.isEmpty) {
      final directImageFields = ['image', 'photo', 'picture', 'avatar'];
      for (String field in directImageFields) {
        if (widget.plant[field] != null && widget.plant[field].toString().isNotEmpty) {
          final imageUrl = _convertToFullUrl(widget.plant[field].toString());
          AppLogger.ui('Найдено прямое изображение [$field]: $imageUrl');
          _availableImages.add(imageUrl);
        }
      }
    }
    
    // Убираем дубликаты
    _availableImages = _availableImages.toSet().toList();
    
    AppLogger.ui('Итого найдено уникальных изображений: ${_availableImages.length}');
    AppLogger.ui('Список изображений: $_availableImages');
  }

  Future<void> _loadPlantReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        setState(() {
          _isLoadingReminders = false;
        });
        return;
      }

      // Получаем различные возможные ID растения
      String? plantCollectionId = widget.plant['id']?.toString() ?? widget.plant['_id']?.toString();
      String? scanId = widget.plant['scan_id']?.toString();
      
      if (plantCollectionId == null) {
        setState(() {
          _isLoadingReminders = false;
        });
        return;
      }

      // Загружаем все напоминания пользователя
      final allReminders = await _reminderService.getRemindersWithStatus(token);
      
      // Фильтруем по ID - ищем по всем возможным вариантам ID растения
      var plantReminders = allReminders.where((reminder) {
        // Получаем все возможные ID для текущего растения
        final possibleIds = <String?>[
          scanId,                                    // scan_id из растения
          plantCollectionId,                         // collection_id (id или _id)
          widget.plant['collection_id']?.toString(), // прямое поле collection_id
          widget.plant['plantId']?.toString(),       // возможное поле plantId
          widget.plant['plant_id']?.toString(),      // возможное поле plant_id
        ].where((id) => id != null && id.isNotEmpty).toSet().toList();
        
        // Проверяем совпадения по любому из возможных ID
        final matches = possibleIds.any((id) => reminder.plantId == id);
        

        print('   � Возможные ID растения: $possibleIds');
        print('   ✅ Совпадает с одним из ID: $matches');
        print('   📝 Тип: ${reminder.type}, Активно: ${reminder.isActive}');
        
        return matches;
      }).toList();
      
      print('✅ Найдено напоминаний для растения: ${plantReminders.length}');
      
      // ПОПЫТКА 2: Если не нашли напоминания, попробуем прямой API запрос с фильтром
      if (plantReminders.isEmpty && scanId != null) {
        print('🔄 Попытка 2: Прямой API запрос с фильтром plantId=$scanId');
        try {
          final directReminders = await _reminderService.getReminders(token, plantId: scanId);
          print('🎯 Прямой запрос вернул: ${directReminders.length} напоминаний');
          if (directReminders.isNotEmpty) {
            plantReminders = directReminders;
          }
        } catch (e) {
          print('❌ Ошибка прямого запроса: $e');
        }
      }
      
      // ПОПЫТКА 3: Если и это не помогло, попробуем с collection_id
      if (plantReminders.isEmpty && plantCollectionId != null && plantCollectionId != scanId) {
        print('🔄 Попытка 3: Прямой API запрос с фильтром plantId=$plantCollectionId');
        try {
          final directReminders = await _reminderService.getReminders(token, plantId: plantCollectionId);
          print('🎯 Прямой запрос вернул: ${directReminders.length} напоминаний');
          if (directReminders.isNotEmpty) {
            plantReminders = directReminders;
          }
        } catch (e) {
          print('❌ Ошибка прямого запроса: $e');
        }
      }
      
      // Выводим подробную информацию о найденных напоминаниях
      print('🎯 === ИТОГОВЫЕ НАПОМИНАНИЯ ДЛЯ РАСТЕНИЯ ===');
      print('🎯 Всего найдено напоминаний: ${plantReminders.length}');
      
      // Анализируем по статусам
      final activeReminders = plantReminders.where((r) => r.isActive).toList();
      final inactiveReminders = plantReminders.where((r) => !r.isActive).toList();
      final completedReminders = plantReminders.where((r) => r.isCompleted).toList();
      final uncompletedReminders = plantReminders.where((r) => !r.isCompleted).toList();
      
      print('🎯 Активные напоминания: ${activeReminders.length}');
      print('🎯 Неактивные напоминания: ${inactiveReminders.length}');
      print('🎯 Выполненные напоминания: ${completedReminders.length}');
      print('🎯 Невыполненные напоминания: ${uncompletedReminders.length}');
      
      for (int i = 0; i < plantReminders.length; i++) {
        final r = plantReminders[i];
        print('🎯 Напоминание #$i: id=${r.id}, type=${r.type}, plantId=${r.plantId}');
        print('   ⏰ Время: ${r.timeOfDay}, Дата: ${r.date}');
        print('   🔄 Активно: ${r.isActive}, Завершено: ${r.isCompleted}');
        print('   📝 Заметка: ${r.note ?? "нет заметки"}');
        if (r.plant != null) {
          print('   🌱 Связанное растение: ${r.plant!.name}');
        }
      }
      print('🎯 === КОНЕЦ ИТОГОВЫХ НАПОМИНАНИЙ ===');

      setState(() {
        // Показываем все найденные напоминания для растения
        _plantReminders = plantReminders.toList();
        _isLoadingReminders = false;
      });

      AppLogger.ui('Загружено напоминаний для растения: ${_plantReminders.length}');
    } catch (e) {
      AppLogger.error('Ошибка загрузки напоминаний растения', e);
      setState(() {
        _isLoadingReminders = false;
      });
    }
  }

  Future<void> _addNewReminder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Необходима авторизация')),
        );
        return;
      }

      // Получаем различные возможные ID растения
      String? plantCollectionId = widget.plant['id']?.toString() ?? widget.plant['_id']?.toString();
      String? scanId = widget.plant['scan_id']?.toString();
      
      if (plantCollectionId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось определить ID растения')),
        );
        return;
      }

      print('🆔 === СОЗДАНИЕ НАПОМИНАНИЯ ДЛЯ РАСТЕНИЯ ===');
      print('📋 Collection ID: $plantCollectionId');
      print('🔬 Scan ID: $scanId');
      print('🎯 Будем использовать: ${scanId ?? plantCollectionId}');

      // Создаем PlantInfo объект из данных растения
      // Используем scan_id если есть, иначе collection_id
      final effectiveId = scanId ?? plantCollectionId;
      
      final plantInfo = PlantInfo(
        name: widget.plant['name']?.toString() ?? 'Растение',
        latinName: widget.plant['latin_name']?.toString() ?? '',
        description: widget.plant['description']?.toString() ?? '',
        isHealthy: widget.plant['is_healthy'] ?? true,
        difficultyLevel: widget.plant['difficulty_level']?.toString() ?? 'medium',
        tags: (widget.plant['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        careInfo: Map<String, dynamic>.from((widget.plant['care_info'] as Map?) ?? {}),
        growingConditions: Map<String, dynamic>.from((widget.plant['growing_conditions'] as Map?) ?? {}),
        pestsAndDiseases: Map<String, dynamic>.from((widget.plant['pests_and_diseases'] as Map?) ?? {}),
        seasonalCare: Map<String, dynamic>.from((widget.plant['seasonal_care'] as Map?) ?? {}),
        additionalInfo: Map<String, dynamic>.from((widget.plant['additional_info'] as Map?) ?? {}),
        images: Map<String, String>.from((widget.plant['images'] as Map?)?.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')) ?? {}),
        toxicity: Map<String, dynamic>.from((widget.plant['toxicity'] as Map?) ?? {}),
        scanId: effectiveId,
      );

      // Переходим на экран добавления напоминания - ВСЕГДА В РЕЖИМЕ ДОБАВЛЕНИЯ
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SetReminderScreen(
            plantData: plantInfo,
            isPlantAlreadyInCollection: true,
            forceAddMode: true, // Принудительно включаем режим добавления
            openFromWatering: false, // Переходим НЕ из кнопки полива
            fromScanHistory: true,   // Не после сканирования - возвращаемся назад
            hideLikeButton: true,    // Скрываем кнопку лайка при открытии из детальной страницы растения
          ),
        ),
      );

      // Если напоминание добавлено, принудительно обновляем список
      if (result == true) {
        print('🔄 Напоминание создано - принудительно обновляем список');
        
        // Показываем уведомление об успешном создании
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Напоминание успешно создано!'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
          ),
        );
        
        // Добавляем небольшую задержку для синхронизации с бэкендом
        await Future.delayed(Duration(milliseconds: 1000));
        
        // Принудительно перезагружаем напоминания
        _loadPlantReminders();
      }
    } catch (e) {
      AppLogger.error('Ошибка при добавлении напоминания', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: ${e.toString()}')),
      );
    }
  }  Future<void> _toggleReminderActive(Reminder reminder) async {
    print('🔄 === ПЕРЕКЛЮЧЕНИЕ АКТИВНОСТИ НАПОМИНАНИЯ ===');
    print('🆔 ID напоминания: ${reminder.id}');
    print('📊 Текущее состояние: ${reminder.isActive ? "Активно" : "Неактивно"}');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        print('❌ Токен отсутствует');
        return;
      }
      if (reminder.id == null) {
        print('❌ ID напоминания отсутствует');
        return;
      }

      print('📤 Отправляем запрос на переключение...');
      final success = await _reminderService.toggleReminderActive(token, reminder.id!);
      print('📥 Результат: ${success ? "Успех" : "Ошибка"}');
      
      if (success) {
        print('✅ Переключение успешно, перезагружаем список...');
        // Обновляем список и ждем завершения
        await _loadPlantReminders();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(reminder.isActive 
                  ? 'Напоминание отключено' 
                  : 'Напоминание включено'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('❌ Не удалось переключить напоминание');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка переключения напоминания')),
          );
        }
      }
    } catch (e) {
      print('❌ Исключение при переключении: $e');
      AppLogger.error('Ошибка переключения напоминания', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.toString()}')),
        );
      }
    }
    print('🔄 === КОНЕЦ ПЕРЕКЛЮЧЕНИЯ ===\n');
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    print('🗑️ === УДАЛЕНИЕ НАПОМИНАНИЯ ===');
    print('🆔 ID напоминания: ${reminder.id}');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        print('❌ Токен отсутствует');
        return;
      }

      // Подтверждение удаления
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Удалить напоминание?', style: TextStyle(fontFamily: 'Gilroy')),
          content: Text('Это действие нельзя отменить.', style: TextStyle(fontFamily: 'Gilroy')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Отмена', style: TextStyle(fontFamily: 'Gilroy')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Удалить', style: TextStyle(color: Colors.red, fontFamily: 'Gilroy')),
            ),
          ],
        ),
      );

      if (confirmed == true && reminder.id != null) {
        print('✅ Пользователь подтвердил удаление');
        print('📤 Отправляем запрос на удаление...');
        
        final success = await _reminderService.deleteReminder(token, reminder.id!);
        print('📥 Результат удаления: ${success ? "Успех" : "Ошибка"}');
        
        if (success) {
          print('✅ Удаление успешно, перезагружаем список...');
          // Обновляем список и ждем завершения
          await _loadPlantReminders();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Напоминание удалено'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          print('❌ Не удалось удалить напоминание');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка удаления напоминания')),
            );
          }
        }
      } else {
        print('❌ Удаление отменено или ID отсутствует');
      }
    } catch (e) {
      print('❌ Исключение при удалении: $e');
      AppLogger.error('Ошибка удаления напоминания', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.toString()}')),
        );
      }
    }
    print('🗑️ === КОНЕЦ УДАЛЕНИЯ ===\n');
  }

  void _showTreatmentDialog() {
    final plantName = widget.plant['name']?.toString() ?? 'Растение';
    final pestsAndDiseases = widget.plant['pests_and_diseases'] as Map? ?? {};
    final careInfo = widget.plant['care_info'] as Map? ?? {};
    
    // Извлекаем информацию о болезнях и лечении
    final commonDiseases = pestsAndDiseases['common_diseases'] as List? ?? [];
    final pestControl = careInfo['pest_control'] as Map? ?? {};
    final diseaseControl = careInfo['disease_treatment'] as Map? ?? {};
    
    final screenWidth = MediaQuery.of(context).size.width;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: screenWidth * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Заголовок
              Container(
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: Color(0xFFFF5722), // Красный цвет для больных растений
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Лечение: $plantName',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: screenWidth * 0.045,
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: screenWidth * 0.06,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Содержимое
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Обнаруженные болезни
                      if (commonDiseases.isNotEmpty) ...[
                        Text(
                          '🦠 Обнаруженные болезни:',
                          style: TextStyle(
                            color: Color(0xFFFF5722),
                            fontSize: screenWidth * 0.04,
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: screenWidth * 0.02),
                        ...commonDiseases.map((disease) => _buildDiseaseCard(disease, screenWidth)),
                        SizedBox(height: screenWidth * 0.04),
                      ],
                      
                      // Рекомендации по лечению от вредителей
                      if (pestControl.isNotEmpty) ...[
                        _buildTreatmentCard(
                          'Обработка от вредителей', 
                          pestControl, 
                          screenWidth,
                          Icons.bug_report,
                          Colors.orange,
                        ),
                        SizedBox(height: screenWidth * 0.03),
                      ],
                      
                      // Рекомендации по лечению болезней
                      if (diseaseControl.isNotEmpty) ...[
                        _buildTreatmentCard(
                          'Лечение болезней', 
                          diseaseControl, 
                          screenWidth,
                          Icons.local_hospital,
                          Colors.red,
                        ),
                        SizedBox(height: screenWidth * 0.03),
                      ],
                      
                      // Рекомендации препаратов ИИ
                      _buildAITreatmentRecommendations(screenWidth),
                      
                      // Если нет детальной информации
                      if (commonDiseases.isEmpty && pestControl.isEmpty && diseaseControl.isEmpty) ...[
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.warning_amber,
                                size: 48,
                                color: Colors.orange,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Растение требует внимания',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade800,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Детальная информация о болезнях и лечении отсутствует. Рекомендуется обратиться к специалисту.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
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
      ),
    );
  }
  
  Widget _buildDiseaseCard(Map disease, double screenWidth) {
    final name = disease['name']?.toString() ?? 'Неизвестная болезнь';
    final description = disease['description']?.toString() ?? '';
    final treatment = disease['treatment']?.toString() ?? '';
    final prevention = disease['prevention']?.toString() ?? '';
    
    return Container(
      margin: EdgeInsets.only(bottom: screenWidth * 0.03),
      padding: EdgeInsets.all(screenWidth * 0.03),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🦠 $name',
            style: TextStyle(
              color: Colors.red.shade800,
              fontSize: screenWidth * 0.035,
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w600,
            ),
          ),
          if (description.isNotEmpty && description != 'data_not_available') ...[
            SizedBox(height: screenWidth * 0.02),
            Text(
              description,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: screenWidth * 0.03,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w400,
                height: 1.3,
              ),
            ),
          ],
          if (treatment.isNotEmpty && treatment != 'data_not_available') ...[
            SizedBox(height: screenWidth * 0.02),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '💊 Лечение: $treatment',
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontSize: screenWidth * 0.03,
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          if (prevention.isNotEmpty && prevention != 'data_not_available') ...[
            SizedBox(height: screenWidth * 0.02),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '🛡️ Профилактика: $prevention',
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontSize: screenWidth * 0.03,
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildTreatmentCard(String title, Map treatment, double screenWidth, IconData icon, Color color) {
    final description = treatment['description']?.toString() ?? '';
    final automation = treatment['automation'] as Map? ?? {};
    final prevention = treatment['prevention'] as Map? ?? {};
    
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.03),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: screenWidth * 0.04,
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          if (description.isNotEmpty) ...[
            SizedBox(height: screenWidth * 0.02),
            Text(
              description,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: screenWidth * 0.03,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w400,
                height: 1.3,
              ),
            ),
          ],
          
          if (automation.isNotEmpty) ...[
            SizedBox(height: screenWidth * 0.02),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📋 Рекомендации:',
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: screenWidth * 0.03,
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  ...automation.entries.map((entry) {
                    if (entry.value == null || entry.value.toString().isEmpty) return SizedBox.shrink();
                    return Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        '• ${_formatAutomationKeyForDialog(entry.key)}: ${_formatValue('', entry.value)}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: screenWidth * 0.025,
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Построение виджета с рекомендациями препаратов ИИ
  Widget _buildAITreatmentRecommendations(double screenWidth) {
    final treatmentService = TreatmentService();
    final diseases = treatmentService.extractDiseaseNames(widget.plant);
    
    // Показываем блок с препаратами (вызывается только для больных растений)
    return Column(
      children: [
        SizedBox(height: screenWidth * 0.03),
        TreatmentRecommendationsWidget(
          diseases: diseases,
          maxRecommendations: 4, // Увеличиваем до 4 рекомендаций
          customTitle: '💊 Препараты для лечения',
          padding: EdgeInsets.zero, // Убираем лишний отступ
        ),
      ],
    );
  }
  
  String _formatAutomationKeyForDialog(String key) {
    switch (key) {
      case 'interval_days': return 'Интервал (дни)';
      case 'interval_months': return 'Интервал (месяцы)';
      case 'time_of_day': return 'Время дня';
      case 'method': return 'Метод';
      case 'preparation_type': return 'Препарат';
      case 'concentration': return 'Концентрация';
      case 'safety_level': return 'Уровень безопасности';
      case 'treatment_duration': return 'Длительность лечения (дни)';
      default: return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 375;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
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
          child: Column(
            children: [
              // Заголовок с кнопкой назад
              _buildHeader(),
              
              // Контент с прокруткой
              Expanded(
                child: SingleChildScrollView(
                  physics: ClampingScrollPhysics(),
                  child: Column(
                    children: [
                      // Галерея изображений
                      _buildImageGallery(screenHeight),
                      
                      // Основная информация
                      _buildMainInfo(isSmallScreen),
                      
                      // Секции с деталями
                      _buildDetailSections(isSmallScreen),
                      
                      // Блок напоминаний в конце контента
                      _buildRemindersSection(isSmallScreen),
                      
                      // Финальный отступ
                      SizedBox(height: 20),
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

  Widget _buildHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(15),
          bottomRight: Radius.circular(15),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1931873F),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: isSmallScreen ? 50 : 60,
              height: isSmallScreen ? 50 : 60,
              padding: EdgeInsets.all(isSmallScreen ? 7 : 10),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF0F0F0),
                ),
                child: Center(
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: isSmallScreen ? 16 : 18,
                    color: Color(0xFF1F2024),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 10 : 15),
          Expanded(
            child: Text(
              widget.plant['name']?.toString() ?? 'Растение',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w700,
                fontSize: isSmallScreen ? 17 : 20,
                color: Color(0xFF1F2024),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: isSmallScreen ? 8 : 10),
          // Кнопка избранного
          _buildFavoriteButton(isSmallScreen),
          SizedBox(width: isSmallScreen ? 8 : 10),
          // Индикатор здоровья / действие
          GestureDetector(
            onTap: () {
              _showDeletePlantDialog();
            },
            child: Container(
              width: isSmallScreen ? 28 : 32,
              height: isSmallScreen ? 28 : 32,
              decoration: BoxDecoration(
                color: _getHealthStatusColor(),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  _getHealthStatusIcon(),
                  size: isSmallScreen ? 16 : 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(double screenHeight) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;
    final imageHeight = isSmallScreen ? screenHeight * 0.28 : screenHeight * 0.35;
    
    if (_availableImages.isEmpty) {
      return Container(
        height: imageHeight,
        margin: EdgeInsets.all(isSmallScreen ? 12 : 15),
        decoration: BoxDecoration(
          color: Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.eco_outlined,
                size: isSmallScreen ? 40 : 48,
                color: Color(0xFF63A36C),
              ),
              SizedBox(height: isSmallScreen ? 8 : 12),
              Text(
                'Нет изображений',
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w500,
                  fontSize: isSmallScreen ? 14 : 16,
                  color: Color(0xFF7A7A7A),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: imageHeight,
      margin: EdgeInsets.all(isSmallScreen ? 12 : 15),
      child: Stack(
        children: [
          // Галерея изображений
          PageView.builder(
            controller: _imagePageController,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemCount: _availableImages.length,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1931873F),
                      blurRadius: isSmallScreen ? 12 : 15,
                      offset: Offset(0, isSmallScreen ? 3 : 5),
                    ),
                  ],
                ),
                                  child: ClipRRect(
                  borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
                  child: _availableImages[index].startsWith('http')
                      ? Image.network(
                          _availableImages[index],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            AppLogger.ui('Ошибка загрузки сетевого изображения: $error');
                            return Container(
                              color: Color(0xFFF0F0F0),
                              child: Center(
                                child: Icon(
                                  Icons.eco_outlined,
                                  size: 48,
                                  color: Color(0xFF63A36C),
                                ),
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Color(0xFFF0F0F0),
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: Color(0xFF63A36C),
                                ),
                              ),
                            );
                          },
                        )
                      : Image.asset(
                          _availableImages[index],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            AppLogger.ui('Ошибка загрузки локального изображения: $error');
                            return Container(
                              color: Color(0xFFF0F0F0),
                              child: Center(
                                child: Icon(
                                  Icons.eco_outlined,
                                  size: 48,
                                  color: Color(0xFF63A36C),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              );
            },
          ),
          
          // Индикаторы страниц
          if (_availableImages.length > 1)
            Positioned(
              bottom: 15,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _availableImages.asMap().entries.map((entry) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentImageIndex == entry.key
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainInfo(bool isSmallScreen) {
    final latinName = widget.plant['latin_name']?.toString() ?? '';
    final description = widget.plant['description']?.toString() ?? '';
    final tags = widget.plant['tags'] as List? ?? [];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 15),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
        boxShadow: [
          BoxShadow(
            color: Color(0x1931873F),
            blurRadius: isSmallScreen ? 12 : 15,
            offset: Offset(0, isSmallScreen ? 3 : 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Название и латинское название
          Text(
            widget.plant['name']?.toString() ?? 'Растение',
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w700,
              fontSize: isSmallScreen ? 22 : 24,
              color: Color(0xFF1F2024),
            ),
          ),
          
          if (latinName.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              latinName,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w500,
                fontSize: isSmallScreen ? 16 : 18,
                color: Color(0xFF63A36C),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          
          // Теги
          if (tags.isNotEmpty) ...[
            SizedBox(height: 15),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFFF0F8EC),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Color(0xFF63A36C).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    tag.toString(),
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w500,
                      fontSize: isSmallScreen ? 12 : 13,
                      color: Color(0xFF63A36C),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          
          // Описание
          if (description.isNotEmpty) ...[
            SizedBox(height: 20),
            Text(
              'Описание',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w700,
                fontSize: isSmallScreen ? 16 : 18,
                color: Color(0xFF1F2024),
              ),
            ),
            SizedBox(height: 10),
            Text(
              description,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w400,
                fontSize: isSmallScreen ? 14 : 15,
                color: Color(0xFF555555),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailSections(bool isSmallScreen) {
    return Column(
      children: [
        SizedBox(height: isSmallScreen ? 12 : 15),
        
        // Уход за растением
        _buildCareSection(isSmallScreen),
        
        SizedBox(height: isSmallScreen ? 12 : 15),
        
        // Условия содержания
        _buildGrowingConditionsSection(isSmallScreen),
        
        SizedBox(height: isSmallScreen ? 12 : 15),
        
        // Болезни и вредители
        _buildPestsAndDiseasesSection(isSmallScreen),
        
        SizedBox(height: isSmallScreen ? 12 : 15),
        
        // Лечебные рекомендации (только для больных растений)
        _buildTreatmentSection(isSmallScreen),
        
        SizedBox(height: isSmallScreen ? 12 : 15),
        
        // Дополнительная информация
        _buildAdditionalInfoSection(isSmallScreen),
      ],
    );
  }

  // Помощник для создания консистентных контейнеров секций
  Widget _buildSectionContainer({
    required bool isSmallScreen,
    required Widget child,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 15),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
        boxShadow: [
          BoxShadow(
            color: Color(0x1931873F),
            blurRadius: isSmallScreen ? 12 : 15,
            offset: Offset(0, isSmallScreen ? 3 : 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCareSection(bool isSmallScreen) {
    final careInfo = widget.plant['care_info'] as Map? ?? {};
    if (careInfo.isEmpty) return SizedBox.shrink();

    return _buildSectionContainer(
      isSmallScreen: isSmallScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFFF0F8EC),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.spa_outlined,
                  size: 20,
                  color: Color(0xFF63A36C),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Уход за растением',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w700,
                    fontSize: isSmallScreen ? 16 : 20,
                    color: Color(0xFF1F2024),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          
          // Полив
          if (careInfo['watering'] != null)
            _buildCareItem(
              'Полив', 
              Icons.water_drop_outlined, 
              careInfo['watering'], 
              isSmallScreen
            ),
          
          // Удобрение
          if (careInfo['fertilizing'] != null)
            _buildCareItem(
              'Удобрение', 
              Icons.eco_outlined, 
              careInfo['fertilizing'], 
              isSmallScreen
            ),
          
          // Пересадка
          if (careInfo['transplanting'] != null)
            _buildCareItem(
              'Пересадка', 
              Icons.agriculture_outlined, 
              careInfo['transplanting'], 
              isSmallScreen
            ),
          
          // Обрезка
          if (careInfo['pruning'] != null)
            _buildCareItem(
              'Обрезка', 
              Icons.content_cut_outlined, 
              careInfo['pruning'], 
              isSmallScreen
            ),
          
          // Опрыскивание
          if (careInfo['spraying'] != null)
            _buildCareItem(
              'Опрыскивание', 
              Icons.shower_outlined, 
              careInfo['spraying'], 
              isSmallScreen
            ),
        ],
      ),
    );
  }

  Widget _buildCareItem(String title, IconData icon, Map careData, bool isSmallScreen) {
    final description = careData['description']?.toString() ?? '';
    final automation = careData['automation'] as Map? ?? {};
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFFAFCF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFF63A36C).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: Color(0xFF63A36C),
              ),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w600,
                  fontSize: isSmallScreen ? 14 : 16,
                  color: Color(0xFF1F2024),
                ),
              ),
            ],
          ),
          
          if (description.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w400,
                fontSize: isSmallScreen ? 12 : 13,
                color: Color(0xFF555555),
                height: 1.4,
              ),
            ),
          ],
          
          // Показываем данные автоматизации если есть
          if (automation.isNotEmpty) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFF0F8EC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Рекомендации:',
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w600,
                      fontSize: isSmallScreen ? 11 : 12,
                      color: Color(0xFF63A36C),
                    ),
                  ),
                  SizedBox(height: 4),
                  ...automation.entries.map((entry) {
                    return Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        '• ${_formatAutomationKey(entry.key)}: ${_formatValue('', entry.value)}',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w400,
                          fontSize: isSmallScreen ? 10 : 11,
                          color: Color(0xFF555555),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGrowingConditionsSection(bool isSmallScreen) {
    final conditions = widget.plant['growing_conditions'] as Map? ?? {};
    if (conditions.isEmpty) return SizedBox.shrink();

    return _buildSectionContainer(
      isSmallScreen: isSmallScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFFF0F8EC),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.thermostat_outlined,
                  size: 20,
                  color: Color(0xFF63A36C),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Условия содержания',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w700,
                    fontSize: isSmallScreen ? 16 : 20,
                    color: Color(0xFF1F2024),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          
          // Температура
          if (conditions['temperature'] != null)
            _buildConditionItem(
              'Температура', 
              Icons.thermostat_outlined, 
              conditions['temperature'], 
              isSmallScreen,
              '°C'
            ),
          
          // Освещение
          if (conditions['lighting'] != null)
            _buildConditionItem(
              'Освещение', 
              Icons.wb_sunny_outlined, 
              conditions['lighting'], 
              isSmallScreen
            ),
          
          // Влажность
          if (conditions['humidity'] != null)
            _buildConditionItem(
              'Влажность', 
              Icons.water_outlined, 
              conditions['humidity'], 
              isSmallScreen,
              '%'
            ),
        ],
      ),
    );
  }

  Widget _buildConditionItem(String title, IconData icon, Map conditionData, bool isSmallScreen, [String? unit]) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFFAFCF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFF63A36C).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: Color(0xFF63A36C),
              ),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w600,
                  fontSize: isSmallScreen ? 14 : 16,
                  color: Color(0xFF1F2024),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          // Отображаем параметры
          ...conditionData.entries.map((entry) {
            if (entry.value == null) return SizedBox.shrink();
            
            return Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatConditionKey(entry.key),
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w400,
                      fontSize: isSmallScreen ? 12 : 13,
                      color: Color(0xFF555555),
                    ),
                  ),
                  Text(
                    '${_formatValue('', entry.value)}${unit ?? ''}',
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w600,
                      fontSize: isSmallScreen ? 12 : 13,
                      color: Color(0xFF63A36C),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildPestsAndDiseasesSection(bool isSmallScreen) {
    final pestsData = widget.plant['pests_and_diseases'] as Map? ?? {};
    if (pestsData.isEmpty) return SizedBox.shrink();

    final commonPests = pestsData['common_pests'] as List? ?? [];
    final commonDiseases = pestsData['common_diseases'] as List? ?? [];
    
    if (commonPests.isEmpty && commonDiseases.isEmpty) return SizedBox.shrink();

    return _buildSectionContainer(
      isSmallScreen: isSmallScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF3E0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bug_report_outlined,
                  size: 20,
                  color: Color(0xFFFF9800),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Болезни и вредители',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w700,
                    fontSize: isSmallScreen ? 16 : 20,
                    color: Color(0xFF1F2024),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          
          // Вредители
          if (commonPests.isNotEmpty) ...[
            Text(
              'Частые вредители:',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 14 : 16,
                color: Color(0xFF1F2024),
              ),
            ),
            SizedBox(height: 12),
            ...commonPests.map((pest) {
              if (pest is! Map) return SizedBox.shrink();
              return _buildPestDiseaseItem(pest, isSmallScreen, true);
            }).toList(),
          ],
          
          // Болезни
          if (commonDiseases.isNotEmpty) ...[
            if (commonPests.isNotEmpty) SizedBox(height: 20),
            Text(
              'Частые болезни:',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 14 : 16,
                color: Color(0xFF1F2024),
              ),
            ),
            SizedBox(height: 12),
            ...commonDiseases.map((disease) {
              if (disease is! Map) return SizedBox.shrink();
              return _buildPestDiseaseItem(disease, isSmallScreen, false);
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildPestDiseaseItem(Map item, bool isSmallScreen, bool isPest) {
    final name = item['name']?.toString() ?? '';
    final description = item['description']?.toString() ?? '';
    final treatment = item['treatment']?.toString() ?? '';
    final prevention = item['prevention']?.toString() ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPest ? Color(0xFFFFF9F5) : Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPest ? Color(0xFFFF9800).withOpacity(0.2) : Color(0xFF2196F3).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w600,
              fontSize: isSmallScreen ? 13 : 14,
              color: Color(0xFF1F2024),
            ),
          ),
          
          if (description.isNotEmpty) ...[
            SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w400,
                fontSize: isSmallScreen ? 11 : 12,
                color: Color(0xFF555555),
                height: 1.4,
              ),
            ),
          ],
          
          if (treatment.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              'Лечение: $treatment',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w400,
                fontSize: isSmallScreen ? 11 : 12,
                color: isPest ? Color(0xFFFF6F00) : Color(0xFF1976D2),
              ),
            ),
          ],
          
          if (prevention.isNotEmpty) ...[
            SizedBox(height: 4),
            Text(
              'Профилактика: $prevention',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w400,
                fontSize: isSmallScreen ? 11 : 12,
                color: Color(0xFF4CAF50),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTreatmentSection(bool isSmallScreen) {
    // Проверяем здоровье растения - показываем секцию только для больных растений
    final isHealthy = widget.plant['is_healthy'] ?? true;
    if (isHealthy) {
      return SizedBox.shrink(); // Не показываем всю секцию для здоровых растений
    }
    
    final pestsData = widget.plant['pests_and_diseases'] as Map? ?? {};
    final commonPests = pestsData['common_pests'] as List? ?? [];
    final commonDiseases = pestsData['common_diseases'] as List? ?? {};

    return _buildSectionContainer(
      isSmallScreen: isSmallScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF3E0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.healing_outlined,
                  size: 20,
                  color: Color(0xFFFF9800),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Лечебные рекомендации',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w700,
                    fontSize: isSmallScreen ? 16 : 20,
                    color: Color(0xFF1F2024),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          
          // Лечебные рекомендации
          if (commonPests.isNotEmpty || commonDiseases.isNotEmpty) ...[
            ...commonPests.map((pest) {
              if (pest is! Map) return SizedBox.shrink();
              return _buildTreatmentItem(pest, isSmallScreen, true);
            }).toList(),
            ...commonDiseases.map((disease) {
              if (disease is! Map) return SizedBox.shrink();
              return _buildTreatmentItem(disease, isSmallScreen, false);
            }).toList(),
          ],
          
          // Рекомендации препаратов ИИ (всегда показываем)
          _buildAITreatmentRecommendations(MediaQuery.of(context).size.width),
        ],
      ),
    );
  }

  Widget _buildTreatmentItem(Map item, bool isSmallScreen, bool isPest) {
    final name = item['name']?.toString() ?? '';
    final description = item['description']?.toString() ?? '';
    final treatment = item['treatment']?.toString() ?? '';
    final prevention = item['prevention']?.toString() ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPest ? Color(0xFFFFF9F5) : Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPest ? Color(0xFFFF9800).withOpacity(0.2) : Color(0xFF2196F3).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w600,
              fontSize: isSmallScreen ? 13 : 14,
              color: Color(0xFF1F2024),
            ),
          ),
          
          if (description.isNotEmpty) ...[
            SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w400,
                fontSize: isSmallScreen ? 11 : 12,
                color: Color(0xFF555555),
                height: 1.4,
              ),
            ),
          ],
          
          if (treatment.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              'Лечение: $treatment',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w400,
                fontSize: isSmallScreen ? 11 : 12,
                color: isPest ? Color(0xFFFF6F00) : Color(0xFF1976D2),
              ),
            ),
          ],
          
          if (prevention.isNotEmpty) ...[
            SizedBox(height: 4),
            Text(
              'Профилактика: $prevention',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w400,
                fontSize: isSmallScreen ? 11 : 12,
                color: Color(0xFF4CAF50),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoSection(bool isSmallScreen) {
    final additionalInfo = widget.plant['additional_info'] as Map? ?? {};
    final toxicity = widget.plant['toxicity'] as Map? ?? {};
    
    if (additionalInfo.isEmpty && toxicity.isEmpty) return SizedBox.shrink();

    return _buildSectionContainer(
      isSmallScreen: isSmallScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFFF0F8EC),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Color(0xFF63A36C),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Дополнительная информация',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w700,
                    fontSize: isSmallScreen ? 16 : 20,
                    color: Color(0xFF1F2024),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          
          // Дополнительные характеристики
          if (additionalInfo.isNotEmpty) ...[
            ...additionalInfo.entries.map((entry) {
              return _buildInfoRow(
                _formatAdditionalInfoKey(entry.key),
                entry.value,
                isSmallScreen
              );
            }).toList(),
          ],
          
          // Токсичность
          if (toxicity.isNotEmpty) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (toxicity['toxic_to_pets'] == true || toxicity['toxic_to_children'] == true)
                    ? Color(0xFFFFF3E0)
                    : Color(0xFFF0F8EC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_outlined,
                        size: 16,
                        color: (toxicity['toxic_to_pets'] == true || toxicity['toxic_to_children'] == true)
                            ? Color(0xFFFF9800)
                            : Color(0xFF4CAF50),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Безопасность',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w600,
                          fontSize: isSmallScreen ? 12 : 13,
                          color: Color(0xFF1F2024),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  if (toxicity['toxic_to_pets'] != null)
                    Text(
                      '• ${toxicity['toxic_to_pets'] == true ? 'Токсично' : 'Безопасно'} для животных',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w400,
                        fontSize: isSmallScreen ? 11 : 12,
                        color: Color(0xFF555555),
                      ),
                    ),
                  if (toxicity['toxic_to_children'] != null)
                    Text(
                      '• ${toxicity['toxic_to_children'] == true ? 'Токсично' : 'Безопасно'} для детей',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w400,
                        fontSize: isSmallScreen ? 11 : 12,
                        color: Color(0xFF555555),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value, bool isSmallScreen) {
    // Форматируем значения для лучшего отображения
    String formattedValue = _formatValue(label, value);
    
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w400,
              fontSize: isSmallScreen ? 11 : 12,
              color: Color(0xFF555555),
            ),
          ),
          SizedBox(height: 4),
          Container(
            width: double.infinity,
            child: Text(
              formattedValue,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w500,
                fontSize: isSmallScreen ? 11 : 12,
                color: Color(0xFF1F2024),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ПОЛНАЯ ЛОКАЛИЗАЦИЯ ВСЕХ ЗНАЧЕНИЙ API
  String _formatValue(String label, dynamic value) {
    // Обрабатываем null значения
    if (value == null) {
      return 'Не указано';
    }
    // Словарь переводов всех enum значений из API
    const Map<String, String> enumTranslations = {
      // Состояние растения
      'healthy': 'Здоровое',
      'sick': 'Больное',
      
      // Сложность ухода
      'easy': 'Легкий',
      'medium': 'Средний',
      'hard': 'Сложный',
      
      // Токсичность
      'non_toxic': 'Безопасно',
      'mildly_toxic': 'Слабо токсично',
      'moderately_toxic': 'Умеренно токсично',
      'toxic': 'Токсично',
      'highly_toxic': 'Очень токсично',
      
      // Время суток
      'morning': 'Утром',
      'evening': 'Вечером',
      'any': 'В любое время',
      
      // Сезоны
      'spring': 'Весна',
      'summer': 'Лето',
      'autumn': 'Осень',
      'winter': 'Зима',
      
      // Освещение
      'direct_sun': 'Прямое солнце',
      'bright_indirect': 'Яркий рассеянный свет',
      'medium_light': 'Умеренное освещение',
      'low_light': 'Слабое освещение',
      
      // Дренаж
      'excellent': 'Отличный',
      'good': 'Хороший',
      'moderate': 'Умеренный',
      'poor': 'Плохой',
      
      // Скорость роста
      'slow': 'Медленная',
      'fast': 'Быстрая',
      
      // Общие
      'data_not_available': 'Неизвестно',
      
      // Дополнительные (старые значения для совместимости)
      'partial_shade': 'Полутень',
      'shade': 'Тень',
      
      // Методы обработки
      'spray': 'Опрыскивание',
      'watering': 'Полив',
      'soaking': 'Замачивание',
      'dusting': 'Опудривание',
      
      // Уровень безопасности
      'low': 'Низкий',
      'high': 'Высокий',
    };

    // Конвертируем в строку для дальнейшей обработки
    String stringValue = value.toString();
    
    // Обрабатываем строку "null"
    if (stringValue.toLowerCase() == 'null') {
      return 'Не указано';
    }

    // Форматируем размер растения
    if (label == 'Размер взрослого растения' && stringValue.contains('{')) {
      try {
        // Пытаемся распарсить JSON
        Map<String, dynamic> sizeData = {};
        
        // Простой парсинг если это строка-JSON
        if (stringValue.startsWith('{') && stringValue.endsWith('}')) {
          String cleaned = stringValue.replaceAll(RegExp(r'[{}"]'), '');
          List<String> pairs = cleaned.split(',');
          for (String pair in pairs) {
            List<String> keyValue = pair.split(':');
            if (keyValue.length == 2) {
              sizeData[keyValue[0].trim()] = keyValue[1].trim();
            }
          }
        }
        
        // Форматируем в читаемый вид
        if (sizeData.isNotEmpty) {
          List<String> parts = [];
          
          if (sizeData['height'] != null) {
            parts.add('высота: ${sizeData['height']}');
          }
          if (sizeData['width'] != null) {
            parts.add('ширина: ${sizeData['width']}');
          }
          if (sizeData['spread'] != null) {
            parts.add('разрастание: ${sizeData['spread']}');
          }
          
          return parts.isNotEmpty ? parts.join(', ') : stringValue;
        }
      } catch (e) {
        // Если не удалось распарсить, возвращаем как есть
      }
    }
    
    // Обрабатываем проценты с булевыми значениями
    if (stringValue.endsWith('%') && stringValue.length > 1) {
      String numericPart = stringValue.substring(0, stringValue.length - 1);
      if (numericPart.toLowerCase() == 'true') return 'Да';
      if (numericPart.toLowerCase() == 'false') return 'Нет';
    }
    
    // Форматируем булевые значения
    if (stringValue.toLowerCase() == 'true') {
      return 'Да';
    } else if (stringValue.toLowerCase() == 'false') {
      return 'Нет';
    }
    
    // Применяем переводы enum значений
    String lowercaseValue = stringValue.toLowerCase();
    if (enumTranslations.containsKey(lowercaseValue)) {
      return enumTranslations[lowercaseValue]!;
    }
    
    return stringValue;
  }

  String _formatAdditionalInfoKey(String key) {
    switch (key) {
      case 'mature_size': return 'Размер взрослого растения';
      case 'growth_rate': return 'Скорость роста';
      case 'lifespan': return 'Продолжительность жизни';
      case 'air_purifying': return 'Очищает воздух';
      default: return key;
    }
  }

  Widget _buildFavoriteButton(bool isSmallScreen) {
    // Извлекаем ID растения из различных возможных полей
    String? plantId;
    
    // ИСПРАВЛЕНО: Сначала пробуем plant_id из коллекции, потом _id, только в крайнем случае scan_id
    if (widget.plant['_id'] != null) {
      plantId = widget.plant['_id'].toString();
    } else if (widget.plant['id'] != null) {
      plantId = widget.plant['id'].toString();
    } else if (widget.plant['scan_id'] != null) {
      plantId = widget.plant['scan_id'].toString();
    }
    
    // Логируем для отладки
    AppLogger.ui('PlantDetailPage: попытка создать кнопку избранного с ID: $plantId');
    AppLogger.ui('PlantDetailPage: полные данные растения: ${widget.plant}');
    
    if (plantId == null || plantId.isEmpty) {
      // Если ID не найден, показываем неактивную кнопку
      AppLogger.ui('PlantDetailPage: ID растения не найден, показываем неактивную кнопку');
      return Container(
        width: isSmallScreen ? 28 : 32,
        height: isSmallScreen ? 28 : 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFF0F0F0),
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/images/favorites/Layer_2_00000154399694884061480560000015505170056280207754_.svg',
            width: isSmallScreen ? 16 : 18,
            height: isSmallScreen ? 16 : 18,
            colorFilter: ColorFilter.mode(
              Color(0xFFBDBDBD),
              BlendMode.srcIn,
            ),
          ),
        ),
      );
    }
    
    // Создаем PlantInfo объект из данных растения для передачи в FavoriteButton
    PlantInfo? plantInfo;
    try {
      plantInfo = PlantInfo(
        name: widget.plant['name']?.toString() ?? 'Растение',
        latinName: widget.plant['latin_name']?.toString() ?? '',
        description: widget.plant['description']?.toString() ?? '',
        isHealthy: widget.plant['is_healthy'] ?? true,
        difficultyLevel: widget.plant['difficulty_level']?.toString() ?? 'medium',
        tags: (widget.plant['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        careInfo: Map<String, dynamic>.from((widget.plant['care_info'] as Map?) ?? {}),
        growingConditions: Map<String, dynamic>.from((widget.plant['growing_conditions'] as Map?) ?? {}),
        pestsAndDiseases: Map<String, dynamic>.from((widget.plant['pests_and_diseases'] as Map?) ?? {}),
        seasonalCare: Map<String, dynamic>.from((widget.plant['seasonal_care'] as Map?) ?? {}),
        additionalInfo: Map<String, dynamic>.from((widget.plant['additional_info'] as Map?) ?? {}),
        images: Map<String, String>.from((widget.plant['images'] as Map?)?.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')) ?? {}),
        toxicity: Map<String, dynamic>.from((widget.plant['toxicity'] as Map?) ?? {}),
        scanId: widget.plant['scan_id']?.toString() ?? plantId, // ИСПРАВЛЕНО: передаем scan_id отдельно
      );
    } catch (e) {
      AppLogger.error('Ошибка создания PlantInfo для FavoriteButton в PlantDetailPage: $e');
    }
    
    return FavoriteButton(
      plantId: plantId,
      size: isSmallScreen ? 20 : 24,
      plantData: plantInfo, // Передаем данные растения
    );
  }

  Widget _buildRemindersSection(bool isSmallScreen) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(15, 20, 15, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0x1931873F),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок секции
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notifications_outlined,
                      size: isSmallScreen ? 18 : 20,
                      color: Color(0xFF63A36C),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Напоминания',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w700,
                        fontSize: isSmallScreen ? 16 : 18,
                        color: Color(0xFF1F2024),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _addNewReminder,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFF63A36C),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: 16,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Добавить',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w600,
                            fontSize: isSmallScreen ? 11 : 12,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Список напоминаний или пустое состояние
            if (_isLoadingReminders)
              Container(
                height: 40,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF63A36C)),
                    ),
                  ),
                ),
              )
            else if (_plantReminders.isEmpty)
              Container(
                height: 40,
                child: Center(
                  child: Text(
                    'Нет напоминаний для этого растения',
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w400,
                      fontSize: isSmallScreen ? 12 : 13,
                      color: Color(0xFF7A7A7A),
                    ),
                  ),
                ),
              )
            else
              // Горизонтальный скролл с напоминаниями - показываем ВСЕ
              Container(
                height: 90, // Увеличил высоту, чтобы избежать переполнения
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _plantReminders.length,
                  separatorBuilder: (context, index) => SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final reminder = _plantReminders[index];
                    return _buildReminderCard(reminder, isSmallScreen);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(Reminder reminder, bool isSmallScreen) {
    // Эмодзи и названия для типов напоминаний
    String getTypeEmoji(String type, String? note) {
      // Проверяем заметку на специальные типы
      if (note != null) {
        final noteLC = note.toLowerCase();
        if (noteLC.contains('повернуть') || noteLC.contains('поворот') || noteLC.contains('вращение')) {
          return '🔄';
        }
        // Если это пользовательская задача (не автоматическая)
        if (!noteLC.contains('автоматическое напоминание')) {
          // Проверяем специфические ключевые слова пользовательских задач
          if (noteLC.contains('подвязать') || noteLC.contains('подвязка')) return '🪢';
          if (noteLC.contains('проветрить') || noteLC.contains('проветривание')) return '🌬️';
          if (noteLC.contains('очистить') || noteLC.contains('протереть') || noteLC.contains('уборка')) return '🧽';
          if (noteLC.contains('переставить') || noteLC.contains('перенести')) return '📦';
          if (noteLC.contains('проверить') || noteLC.contains('осмотреть')) return '🔍';
          // Для прочих пользовательских задач
          return '📝';
        }
      }
      
      switch (type.toLowerCase()) {
        case 'полив': case 'watering': return '💧';
        case 'удобрение': case 'fertilizing': return '🌱';
        case 'орошение': case 'spraying': return '🌿';
        case 'пересадка': case 'transplanting': return '🪴';
        case 'обрезка': case 'pruning': return '✂️';
        case 'pest_control': return '🐛';
        case 'disease_treatment': return '🍄';
        default: return '📅';
      }
    }

    String getTypeName(String type, String? note) {
      // Проверяем заметку на специальные типы
      if (note != null) {
        final noteLC = note.toLowerCase();
        if (noteLC.contains('повернуть') || noteLC.contains('поворот') || noteLC.contains('вращение')) {
          return 'Вращение';
        }
        // Если это пользовательская задача (не автоматическая)
        if (!noteLC.contains('автоматическое напоминание')) {
          // Проверяем специфические ключевые слова пользовательских задач
          if (noteLC.contains('подвязать') || noteLC.contains('подвязка')) return 'Подвязка';
          if (noteLC.contains('проветрить') || noteLC.contains('проветривание')) return 'Проветривание';
          if (noteLC.contains('очистить') || noteLC.contains('протереть') || noteLC.contains('уборка')) return 'Уборка';
          if (noteLC.contains('переставить') || noteLC.contains('перенести')) return 'Перестановка';
          if (noteLC.contains('проверить') || noteLC.contains('осмотреть')) return 'Осмотр';
          // Для прочих пользовательских задач
          return 'Моя задача';
        }
      }
      
      switch (type.toLowerCase()) {
        case 'watering': return 'Полив';
        case 'fertilizing': return 'Удобрение';
        case 'spraying': return 'Орошение';
        case 'transplanting': return 'Пересадка';
        case 'pruning': return 'Обрезка';
        case 'pest_control': return 'От вредителей';
        case 'disease_treatment': return 'От болезней';
        default: return type;
      }
    }

    return Container(
      width: isSmallScreen ? 140 : 160,
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: reminder.isActive ? Color(0xFFF0F8EC) : Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: reminder.isActive ? Color(0xFF63A36C) : Color(0xFFE0E0E0),
          width: 1.5,
        ),
        boxShadow: reminder.isActive ? [
          BoxShadow(
            color: Color(0xFF63A36C).withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Заголовок с переключателем
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      getTypeEmoji(reminder.type, reminder.note),
                      style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        getTypeName(reminder.type, reminder.note),
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w600,
                          fontSize: isSmallScreen ? 10 : 11,
                          color: Color(0xFF1F2024),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _toggleReminderActive(reminder),
                child: Container(
                  width: 28,
                  height: 16,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: reminder.isActive ? Color(0xFF63A36C) : Color(0xFFCCCCCC),
                  ),
                  child: AnimatedAlign(
                    duration: Duration(milliseconds: 200),
                    alignment: reminder.isActive ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 12,
                      height: 12,
                      margin: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 6),
          
          // Интервал и статус
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getIntervalText(reminder),
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w400,
                        fontSize: isSmallScreen ? 9 : 10,
                        color: Color(0xFF7A7A7A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Добавляем информацию о статусе для диагностики
                    if (!reminder.isActive || reminder.isCompleted)
                      Text(
                        reminder.isCompleted ? 'Выполнено' : 'Неактивно',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w500,
                          fontSize: isSmallScreen ? 8 : 9,
                          color: reminder.isCompleted ? Color(0xFF4CAF50) : Color(0xFFFF9800),
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _deleteReminder(reminder),
                child: Container(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: Color(0xFFFF5252),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getIntervalText(Reminder reminder) {
    if (reminder.repeatWeekly && reminder.daysOfWeek.isNotEmpty) {
      final daysCount = reminder.daysOfWeek.length;
      if (daysCount == 7) {
        return 'Ежедневно';
      } else if (daysCount == 1) {
        return 'Раз в неделю';
      } else {
        return '$daysCount дн/нед';
      }
    } else {
      // Для других типов напоминаний
      return 'По расписанию';
    }
  }

  Color _getHealthStatusColor() {
    if (widget.plant['is_healthy'] == true) {
      return Color(0xFF4CAF50);
    } else if (widget.plant['is_healthy'] == false) {
      return Color(0xFFFF9800);
    } else {
      // Если значение не определено, возвращаем прозрачный цвет
      return Colors.transparent;
    }
  }

  IconData _getHealthStatusIcon() {
    if (widget.plant['is_healthy'] == true) {
      return Icons.check;
    } else if (widget.plant['is_healthy'] == false) {
      return Icons.warning;
    } else {
      // Если значение не определено, возвращаем пустой иконкой
      return Icons.help_outline;
    }
  }

  String _formatAutomationKey(String key) {
    switch (key) {
      case 'interval_days': return 'Частота (дни)';
      case 'interval_months': return 'Частота (месяцы)';
      case 'time_of_day': return 'Время дня';
      case 'amount': return 'Количество';
      case 'water_type': return 'Тип воды';
      case 'fertilizer_type': return 'Тип удобрения';
      case 'concentration': return 'Концентрация';
      case 'best_season': return 'Лучший сезон';
      case 'soil_type': return 'Тип почвы';
      case 'pruning_type': return 'Тип обрезки';
      case 'spray_type': return 'Тип опрыскивания';
      default: return key;
    }
  }

  String _formatConditionKey(String key) {
    switch (key) {
      case 'min': return 'Минимум';
      case 'max': return 'Максимум';
      case 'optimal_min': return 'Оптимум мин';
      case 'optimal_max': return 'Оптимум макс';
      case 'type': return 'Тип';
      case 'hours_per_day': return 'Часов в день';
      case 'artificial_light_ok': return 'Искусственный свет';
      case 'min_percentage': return 'Минимум';
      case 'max_percentage': return 'Максимум';
      case 'optimal_percentage': return 'Оптимум';
      case 'misting_required': return 'Опрыскивание';
      default: return key;
    }
  }

  Future<void> _showDeletePlantDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          'Удалить растение из Вашей дачи?',
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Растение будет удалено из коллекции вместе со всеми напоминаниями.',
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Нет',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Color(0xFF7A7A7A),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Да',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Color(0xFFFF5722),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deletePlantFromCollection();
    }
  }

  // Пытаемся определить корректный ID записи коллекции для удаления
  Future<String?> _resolveCollectionId(String token) async {
    try {
      final directId = widget.plant['id']?.toString() ?? widget.plant['_id']?.toString();
      final scanIdFromPlant = widget.plant['scan_id']?.toString();
      if (directId != null && directId.isNotEmpty) {
        if (scanIdFromPlant != null && scanIdFromPlant.isNotEmpty && directId == scanIdFromPlant) {
          AppLogger.ui('PlantDetail: прямой ID совпадает со scan_id, ищем ID записи в коллекции');
        } else {
          AppLogger.ui('PlantDetail: используем прямой ID записи: $directId');
          return directId;
        }
      }

      // Загружаем коллекцию и ищем соответствие
      final collection = await _scanService.getUserPlantCollection(token);

      // 1) По scan_id (надежнее)
      if (scanIdFromPlant != null && scanIdFromPlant.isNotEmpty) {
        for (final item in collection) {
          final itemScanId = item['scan_id']?.toString();
          if (itemScanId != null && itemScanId == scanIdFromPlant) {
            final cid = item['id']?.toString() ?? item['_id']?.toString();
            if (cid != null && cid.isNotEmpty) {
              AppLogger.ui('PlantDetail: найден ID по scan_id: $cid');
              return cid;
            }
          }
        }
      }

      // 2) Фолбэк по имени
      final name = widget.plant['name']?.toString();
      if (name != null && name.isNotEmpty) {
        for (final item in collection) {
          final itemName = item['name']?.toString();
          if (itemName != null && itemName.toLowerCase().trim() == name.toLowerCase().trim()) {
            final cid = item['id']?.toString() ?? item['_id']?.toString();
            if (cid != null && cid.isNotEmpty) {
              AppLogger.ui('PlantDetail: найден ID по имени: $cid');
              return cid;
            }
          }
        }
      }

      AppLogger.ui('PlantDetail: не удалось определить ID записи коллекции');
      return null;
    } catch (e) {
      AppLogger.error('PlantDetail: ошибка при определении ID коллекции', e);
      return null;
    }
  }

  Future<void> _deletePlantFromCollection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Необходима авторизация')),
        );
        return;
      }

      // Определяем корректный ID записи коллекции
      final plantId = await _resolveCollectionId(token);
      if (plantId == null || plantId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось определить ID растения')),
        );
        return;
      }

      print('🗑️ Удаление растения ID: $plantId');
      
      final reminderService = ReminderService();
      
      final scanId = widget.plant['scan_id']?.toString();
      if (scanId != null && scanId.isNotEmpty) {
        print('🗑️ Удаление напоминаний для scan_id: $scanId');
        final reminders = await reminderService.getReminders(token, plantId: scanId);
        for (var reminder in reminders) {
          if (reminder.id != null) {
            await reminderService.deleteReminder(token, reminder.id!);
          }
        }
      }

      // Также пытаемся удалить напоминания, связанные с ID записи в коллекции
      if (plantId.isNotEmpty) {
        print('🗑️ Дополнительно удаляем напоминания для collection_id: $plantId');
        final remindersByCollection = await reminderService.getReminders(token, plantId: plantId);
        for (var reminder in remindersByCollection) {
          if (reminder.id != null) {
            await reminderService.deleteReminder(token, reminder.id!);
          }
        }
      }
      
      final success = await _scanService.removePlantFromCollection(
        plantId,
        token,
        scanId: scanId,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Растение удалено из коллекции'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при удалении растения'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Ошибка при удалении растения', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 