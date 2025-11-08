import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import '../homepage/UsefulInfoComponent.dart';
import 'favorites_page.dart';
import 'favorites_list_page.dart';
import 'scan_history_page.dart';
import 'achievements_page.dart';
import 'settings_page.dart';
import 'authenticity_check_page.dart';
import 'notifications_page.dart';
import '../services/api/auth_service.dart';
import '../services/api/user_service.dart';
import '../services/api/scan_service.dart';
import '../services/api/reminder_service.dart';
import '../models/user_profile.dart';
import '../services/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'plant_collection_page.dart';
import 'plant_detail_page.dart';
import '../services/plant_events.dart';
import '../scanner/scanner_screen.dart';

class MyDachaPage extends StatefulWidget {
  const MyDachaPage({Key? key}) : super(key: key);

  @override
  State<MyDachaPage> createState() => _MyDachaPageState();
}

class _MyDachaPageState extends State<MyDachaPage> {
  final UserService _userService = UserService();
  final ScanService _scanService = ScanService();
  UserProfile? _userProfile;
  bool _isLoadingProfile = true;
  List<dynamic> _userPlants = [];
  bool _isLoadingPlants = true;
  
  // PageView для растений
  PageController _plantsPageController = PageController();
  int _currentPlantsPage = 0;
  
  // Подписка на события
  StreamSubscription? _plantEventsSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadUserPlants();
    _subscribeToPlantEvents();
  }

  Future<void> _showDeletePlantDialog(Map<String, dynamic> plant) async {
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
            child: Text('Нет'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Да', style: TextStyle(color: Color(0xFFFF5722))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deletePlantFromCollection(plant);
    }
  }

  // Пытаемся определить корректный ID записи коллекции для удаления
  Future<String?> _resolveCollectionId(Map<String, dynamic> plant, String token) async {
    try {
      // 1) Если уже есть id/_id в объекте - пробуем их первыми
      final directId = plant['id']?.toString() ?? plant['_id']?.toString();
      final scanIdFromPlant = plant['scan_id']?.toString();
      if (directId != null && directId.isNotEmpty) {
        // Если прямой ID случайно равен scan_id, это, вероятно, не ID записи коллекции
        if (scanIdFromPlant != null && scanIdFromPlant.isNotEmpty && directId == scanIdFromPlant) {
          print('🧭 resolveId: прямой ID совпадает со scan_id -> будем искать по коллекции');
        } else {
          print('🧭 resolveId: найден прямой ID в объекте: $directId');
          return directId;
        }
      }

      // 2) Загружаем актуальную коллекцию с сервера
      print('🧭 resolveId: загружаем коллекцию для сопоставления...');
      final collection = await _scanService.getUserPlantCollection(token);
      print('🧭 resolveId: получена коллекция из ${collection.length} элементов');

      // 2a) Ищем по scan_id (надежнее всего)
      final scanId = scanIdFromPlant;
      print('🧭 resolveId: ищем по scan_id="$scanId"');
      if (scanId != null && scanId.isNotEmpty) {
        for (int i = 0; i < collection.length; i++) {
          final item = collection[i];
          final itemScanId = item['scan_id']?.toString();
          print('🧭 resolveId: элемент $i: scan_id="$itemScanId", name="${item['name']}"');
          if (itemScanId != null && itemScanId == scanId) {
            print('🧭 resolveId: ✅ СОВПАДЕНИЕ по scan_id в элементе $i');
            // Логируем ключи корневого уровня
            try { 
              print('🧭 resolveId: ключи элемента коллекции: '+ (item.keys.join(', '))); 
              print('🧭 resolveId: полный элемент: $item');
            } catch (e) { 
              print('🧭 resolveId: ошибка вывода ключей: $e');
            }

            // Предпочитаем явные идентификаторы записи коллекции
            final candidates = <String?>[
              item['_id']?.toString(),
              item['collection_id']?.toString(),
              item['collectionId']?.toString(),
              item['entry_id']?.toString(),
              item['entryId']?.toString(),
              item['id']?.toString(),
            ];
            for (final c in candidates) {
              if (c != null && c.isNotEmpty && c != scanId) {
                print('🧭 resolveId: выбран ID записи коллекции: $c');
                return c;
              }
            }

            // Если других кандидатов нет, возвращаем то, что есть, но предупреждаем
            final fallback = item['id']?.toString() ?? item['_id']?.toString();
            if (fallback != null && fallback.isNotEmpty) {
              print('⚠️ resolveId: единственный доступный ID совпадает со scan_id ($fallback). Пробуем с ним.');
              return fallback;
            }
          } else {
            print('🧭 resolveId: элемент $i - НЕТ совпадения (itemScanId="$itemScanId" != scanId="$scanId")');
          }
        }
        print('🧭 resolveId: поиск по scan_id завершён, совпадений не найдено');
      } else {
        print('🧭 resolveId: scanId пустой или null, пропускаем поиск по scan_id');
      }

      // 2b) Фолбэк по имени (может быть неоднозначным, но лучше чем ничего)
      final name = plant['name']?.toString();
      if (name != null && name.isNotEmpty) {
        for (final item in collection) {
          final itemName = item['name']?.toString();
          if (itemName != null && itemName.toLowerCase().trim() == name.toLowerCase().trim()) {
            final cid = item['id']?.toString() ?? item['_id']?.toString();
            if (cid != null && cid.isNotEmpty) {
              print('🧭 resolveId: найден ID по имени: $cid');
              return cid;
            }
          }
        }
      }

      print('🧭 resolveId: не удалось определить ID для удаления');
      return null;
    } catch (e) {
      print('💥 resolveId: ошибка при попытке определить ID: $e');
      return null;
    }
  }

  Future<void> _deletePlantFromCollection(Map<String, dynamic> plant) async {
    try {
      print('🗑️🗑️🗑️ === НАЧАЛО _deletePlantFromCollection ===');
      print('🗑️ Данные растения для удаления: $plant');
      print('🗑️ plant[\"id\"]: ${plant['id']}');
      print('🗑️ plant[\"_id\"]: ${plant['_id']}');
      print('🗑️ plant[\"scan_id\"]: ${plant['scan_id']}');
      print('🗑️ plant[\"name\"]: ${plant['name']}');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Необходима авторизация')),
        );
        return;
      }

      // Определяем корректный ID записи коллекции
      print('🗑️ Вызываем _resolveCollectionId...');
      String? plantId = await _resolveCollectionId(plant, token);
      print('🗑️ _resolveCollectionId вернул: $plantId');
      if (plantId == null || plantId.isEmpty) {
        print('❌ MyDacha: ID записи коллекции не найден');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось определить ID растения')), 
        );
        return;
      }
      print('🆔 MyDacha: Удаляем запись коллекции с ID: $plantId');

      // Удаляем связанные напоминания по scan_id и по collection_id
      final reminderService = ReminderService();
      final scanId = plant['scan_id']?.toString();
      if (scanId != null && scanId.isNotEmpty) {
        final reminders = await reminderService.getReminders(token, plantId: scanId);
        for (final r in reminders) {
          if (r.id != null) await reminderService.deleteReminder(token, r.id!);
        }
      }
      final remindersByCollection = await reminderService.getReminders(token, plantId: plantId);
      for (final r in remindersByCollection) {
        if (r.id != null) await reminderService.deleteReminder(token, r.id!);
      }

      final ok = await _scanService.removePlantFromCollection(
        plantId,
        token,
        scanId: scanId,
      );
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Растение удалено из коллекции'), backgroundColor: Color(0xFF4CAF50)),
        );
        _loadUserPlants();
      } else {
        print('❌ MyDacha: removePlantFromCollection вернул false');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при удалении растения'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      AppLogger.error('Ошибка при удалении растения из MyDacha', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  void _subscribeToPlantEvents() {
    _plantEventsSubscription = PlantEvents().stream.listen((_) {
      print('🔄 MyDachaPage: Получено событие обновления коллекции');
      _loadUserPlants();
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      AppLogger.ui('Загрузка профиля пользователя для MyDachaPage');
      
      // Сначала пробуем загрузить из кэша
      final cachedProfile = await _userService.getCachedProfile();
      if (cachedProfile != null) {
        setState(() {
          _userProfile = cachedProfile;
          _isLoadingProfile = false;
        });
      }

      // Затем загружаем свежие данные с сервера
      final profile = await _userService.getUserProfile();
      if (profile != null) {
        setState(() {
          _userProfile = profile;
          _isLoadingProfile = false;
        });
        // Сохраняем в кэш
        await _userService.cacheProfile(profile);
        AppLogger.ui('Профиль пользователя загружен: ${profile.displayName}');
      } else {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      AppLogger.error('Ошибка загрузки профиля пользователя', e);
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadUserPlants() async {
    try {
      print('🌱 === ЗАГРУЗКА РАСТЕНИЙ ПОЛЬЗОВАТЕЛЯ ===');
      AppLogger.ui('Загрузка растений пользователя для MyDachaPage');
      
      // Получаем токен авторизации
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      print('🔑 Токен найден: ${token != null ? "ДА (длина ${token!.length})" : "НЕТ"}');
      
      if (token == null || token.isEmpty) {
        print('❌ Токен пустой, прерываем загрузку растений');
        AppLogger.ui('Токен не найден, пропускаем загрузку растений');
        setState(() {
          _isLoadingPlants = false;
        });
        return;
      }

      print('🌐 Запрашиваем коллекцию растений с сервера...');
      
      // Загружаем растения с сервера
      final plants = await _scanService.getUserPlantCollection(token);
      
      print('📦 Получен ответ от API:');
      print('   • Количество растений: ${plants.length}');
      print('   • Данные: $plants');
      
      setState(() {
        _userPlants = plants;
        _isLoadingPlants = false;
      });
      
      if (plants.isEmpty) {
        print('🌿 Коллекция пуста - будет показана заглушка');
      } else {
        print('✅ Растения загружены успешно:');
        for (int i = 0; i < plants.length; i++) {
          final plant = plants[i];
          print('   ${i + 1}. ${plant['name'] ?? 'Без названия'} (здоровое: ${plant['is_healthy'] ?? 'неизвестно'})');
        }
      }
      
      AppLogger.ui('Растения пользователя загружены: ${plants.length} шт.');
      print('🌱 === КОНЕЦ ЗАГРУЗКИ РАСТЕНИЙ ===');
    } catch (e) {
      print('💥 ОШИБКА загрузки растений: $e');
      AppLogger.error('Ошибка загрузки растений пользователя', e);
      setState(() {
        _isLoadingPlants = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Адаптивные размеры
    final cardWidth = (screenWidth - 75) / 4; // Учитываем отступы между карточками
    final actionCardWidth = (screenWidth - 45) / 3;
    final isSmallScreen = screenWidth < 375;
    final isMediumScreen = screenWidth >= 375 && screenWidth < 414;
    
    // Адаптивные размеры шрифтов
    final titleFontSize = isSmallScreen ? 16.0 : 18.0;
    final subtitleFontSize = isSmallScreen ? 9.0 : 10.0;
    final buttonFontSize = isSmallScreen ? 11.0 : 12.0;

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
          child: SingleChildScrollView(
            physics: ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Белая шапка с приветствием
                Container(
                  width: double.infinity,
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
                      Container(
                        width: isSmallScreen ? 35 : 40,
                        height: isSmallScreen ? 35 : 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFDDDDDD),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 7,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/images/my_dacha/avatar_silhouette.svg',
                            width: isSmallScreen ? 25 : 30,
                            height: isSmallScreen ? 25 : 30,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: _isLoadingProfile
                            ? Row(
                                children: [
                                  Text(
                                    'Привет, ',
                                    style: TextStyle(
                                      fontFamily: 'Gilroy',
                                      fontWeight: FontWeight.w600,
                                      fontSize: isSmallScreen ? 13 : 14,
                                      color: Colors.black,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 8,
                                    height: 8,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFF63A36C)),
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                'Привет, ${_userProfile?.displayName ?? 'Пользователь'}',
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontWeight: FontWeight.w600,
                                  fontSize: isSmallScreen ? 13 : 14,
                                  color: Colors.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isSmallScreen ? 12 : 15),

                // Моя Дача с растениями - в одном белом блоке
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 15),
                  child: Container(
                    width: double.infinity,
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
                    child: Column(
                      children: [
                        // Заголовок и ссылка
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              flex: 2,
                              child: Text(
                                'Моя Дача',
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontWeight: FontWeight.w600,
                                  fontSize: titleFontSize,
                                  letterSpacing: 0.005,
                                  color: Color(0xFF1F2024),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Flexible(
                              flex: 1,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PlantCollectionPage(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Открыть полный список',
                                  style: TextStyle(
                                    fontFamily: 'Gilroy',
                                    fontWeight: FontWeight.w600,
                                    fontSize: subtitleFontSize,
                                    color: Color(0xFF63A36C),
                                  ),
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 15),
                        // PageView с растениями или заглушка
                        _buildPlantsPageView(cardWidth, isSmallScreen),
                        SizedBox(height: 10),
                        // Динамические индикаторы страниц
                        _buildPageIndicators(isSmallScreen),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 12 : 15),

                // Три карточки с действиями
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // История сканирований (телефон)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ScanHistoryPage()),
                            );
                          },
                          child: _buildActionItem(
                            context,
                            'assets/images/my_dacha/favorites.png', // Телефон с веточкой
                            'История сканирований',
                            actionCardWidth,
                            isSmallScreen,
                            isImage: true,
                          ),
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 6 : 8),
                      // Избранное (сердечко)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => FavoritesListPage()),
                            );
                          },
                          child: _buildActionItem(
                            context,
                            'assets/images/my_dacha/achievements.png', // Сердечко
                            'Избранное',
                            actionCardWidth,
                            isSmallScreen,
                            isImage: true,
                          ),
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 6 : 8),
                      // Достижения (чайник)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => AchievementsPage()),
                            );
                          },
                          child: _buildActionItem(
                            context,
                            'assets/images/my_dacha/history_scan.png', // Чайник
                            'Достижения',
                            actionCardWidth,
                            isSmallScreen,
                            isImage: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isSmallScreen ? 12 : 15),

                // Кнопка "Проверка подлинности препарата" - после трех карточек
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 15),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AuthenticityCheckPage()),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      height: isSmallScreen ? 36 : 40,
                      decoration: BoxDecoration(
                        color: Color(0xFF63A36C),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1931873F),
                            blurRadius: 20,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Проверка подлинности препарата',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w500,
                            fontSize: buttonFontSize,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 12 : 15),

                // Настройки, Уведомления, Выход - с правильными разделителями
                Container(
                  padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => SettingsPage()),
                          );
                        },
                        child: _buildBottomMenuItem('Настройки', isSmallScreen),
                      ),
                      Container(
                        height: isSmallScreen ? 16 : 20,
                        width: 1,
                        margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 15),
                        color: Color(0xFFB2D39F),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => NotificationsPage()),
                          );
                        },
                        child: _buildBottomMenuItem('Уведомления', isSmallScreen),
                      ),
                      Container(
                        height: isSmallScreen ? 16 : 20,
                        width: 1,
                        margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 15),
                        color: Color(0xFFB2D39F),
                      ),
                      GestureDetector(
                        onTap: () {
                          _handleLogout(context);
                        },
                        child: Text(
                          'Выход',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w600,
                            fontSize: buttonFontSize,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isSmallScreen ? 12 : 15),

                // Полезная информация
                UsefulInfoComponent(),
                SizedBox(height: isSmallScreen ? 15 : 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlantsRow(double cardWidth, bool isSmallScreen) {
    if (_isLoadingPlants) {
      // Показываем скелетон во время загрузки
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(4, (index) => 
          Expanded(
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                  ),
                ),
                SizedBox(height: isSmallScreen ? 3 : 5),
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        ).expand((widget) => [
          widget,
          if (widget != null) SizedBox(width: isSmallScreen ? 6 : 8),
        ]).take(7).toList(),
      );
    }

    if (_userPlants.isEmpty) {
      // Показываем красивую заглушку
      return Container(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Color(0xFFF0F8EC),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.eco_outlined,
                  size: 30,
                  color: Color(0xFF63A36C),
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Ваша коллекция пуста',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 14 : 16,
                color: Color(0xFF1F2024),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Просканируйте ваши первые растения\nчтобы начать создавать коллекцию!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w400,
                fontSize: isSmallScreen ? 11 : 12,
                color: Color(0xFF7A7A7A),
                height: 1.3,
              ),
            ),
          ],
        ),
      );
    }

    // Показываем реальные растения (максимум 4)
    final plantsToShow = _userPlants.take(4).toList();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ...plantsToShow.asMap().entries.map((entry) {
          final index = entry.key;
          final plant = entry.value;
          final plantName = plant['name']?.toString() ?? 'Растение';
          
          // Определяем изображение растения по новой логике API
          String? plantImageUrl;
          
          // Для отладки - выводим структуру растения из коллекции
          if (index == 0) { // Только для первого растения, чтобы не засорять логи
            print('🌱 === АНАЛИЗ РАСТЕНИЯ ИЗ КОЛЛЕКЦИИ ===');
            print('📊 Ключи растения: ${plant.keys.join(", ")}');
            print('📸 photo: "${plant['photo']}"');
            
            if (plant['images'] != null && plant['images'] is Map) {
              final images = plant['images'] as Map;
              print('🖼️ Доступные изображения в коллекции:');
              images.forEach((key, value) {
                print('     - $key: "$value"');
              });
            } else {
              print('❌ Нет images в растении из коллекции');
            }
            print('🌱 === КОНЕЦ АНАЛИЗА РАСТЕНИЯ ИЗ КОЛЛЕКЦИИ ===');
          }
          
          // Сначала проверяем поле photo
          if (plant['photo'] != null && plant['photo'].toString().isNotEmpty) {
            plantImageUrl = plant['photo'].toString();
            if (index == 0) print('🖼️ Коллекция: Используем изображение из photo: $plantImageUrl');
          }
          // Затем проверяем структуру images
          else if (plant['images'] != null && plant['images'] is Map) {
            final images = plant['images'] as Map;
            // ИСПРАВЛЕНО: thumbnail (кроп) должен быть приоритетным для списков
            // Приоритет: thumbnail (кроп) > crop > main_image > original > user_image
            plantImageUrl = images['thumbnail'] ?? 
                          images['crop'] ?? 
                          images['main_image'] ?? 
                          images['original'] ?? 
                          images['user_image'];
            
            // Если ничего не нашли, но в images есть значения, берем первое непустое
            if (plantImageUrl == null && images.values.isNotEmpty) {
              for (var value in images.values) {
                if (value != null && value.toString().isNotEmpty) {
                  plantImageUrl = value.toString();
                  break;
                }
              }
            }
            
            if (index == 0 && plantImageUrl != null) {
              print('🖼️ Коллекция: Используем изображение из images: $plantImageUrl');
            }
          }
          
          return [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  // Переход на детальную страницу растения
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlantDetailPage(plant: plant),
                    ),
                  );
                },
                child: _buildPlantItem(
                  plantImageUrl, 
                  plantName.length > 10 ? '${plantName.substring(0, 10)}...' : plantName,
                  cardWidth, 
                  isSmallScreen,
                  isNetworkImage: plantImageUrl != null && plantImageUrl.startsWith('http'),
                ),
              ),
            ),
            if (index < plantsToShow.length - 1) SizedBox(width: isSmallScreen ? 6 : 8),
          ];
        }).expand((list) => list).toList(),
        
        // Заполняем пустые слоты если растений меньше 4
        ...List.generate(
          4 - plantsToShow.length,
          (index) => [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  print('🌱 MyDachaPage: Кнопка "Добавить" нажата!');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ScannerScreen()),
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: cardWidth + 20,
                  ),
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Color(0xFFE8E8E8),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.add_circle_outline,
                              size: 24,
                              color: Color(0xFFB8B8B8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 3 : 5),
                      Text(
                        'Добавить',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w400,
                          fontSize: isSmallScreen ? 9 : 10,
                          color: Color(0xFFB8B8B8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (index < 4 - plantsToShow.length - 1) SizedBox(width: isSmallScreen ? 6 : 8),
          ],
        ).expand((list) => list).toList(),
      ],
    );
  }

  Widget _buildPlantItem(String? imagePath, String name, double width, bool isSmallScreen, {bool isNetworkImage = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Color(0xFFF0F0F0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imagePath != null
                  ? (isNetworkImage
                      ? Image.network(
                          imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Color(0xFFF0F0F0),
                              child: Center(
                                child: Icon(
                                  Icons.eco_outlined,
                                  size: 24,
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
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF63A36C)),
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Image.asset(
                          imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Color(0xFFF0F0F0),
                              child: Center(
                                child: Icon(
                                  Icons.eco_outlined,
                                  size: 24,
                                  color: Color(0xFF63A36C),
                                ),
                              ),
                            );
                          },
                        ))
                  : Container(
                      color: Color(0xFFF0F0F0),
                      child: Center(
                        child: Icon(
                          Icons.eco_outlined,
                          size: 24,
                          color: Color(0xFF63A36C),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 3 : 5),
        Text(
          name,
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontWeight: FontWeight.w400,
            fontSize: isSmallScreen ? 9 : 10,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // Новый метод для PageView с растениями
  Widget _buildPlantsPageView(double cardWidth, bool isSmallScreen) {
    if (_isLoadingPlants) {
      return _buildLoadingSkeleton(cardWidth, isSmallScreen);
    }

    if (_userPlants.isEmpty) {
      return _buildEmptyPlantsState(isSmallScreen);
    }

    // Группируем растения по 4 на страницу
    final plantsPages = <List<dynamic>>[];
    for (int i = 0; i < _userPlants.length; i += 4) {
      plantsPages.add(_userPlants.skip(i).take(4).toList());
    }

    return Container(
      height: cardWidth + 30, // Высота карточки + отступы
      child: PageView.builder(
        controller: _plantsPageController,
        onPageChanged: (index) {
          setState(() {
            _currentPlantsPage = index;
          });
        },
        itemCount: plantsPages.length,
        itemBuilder: (context, pageIndex) {
          final plantsOnPage = plantsPages[pageIndex];
          return _buildPlantsPage(plantsOnPage, cardWidth, isSmallScreen);
        },
      ),
    );
  }

  // Одна страница с растениями (до 4 штук)
  Widget _buildPlantsPage(List<dynamic> plants, double cardWidth, bool isSmallScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ...plants.asMap().entries.map((entry) {
          final index = entry.key;
          final plant = entry.value;
          final plantName = plant['name']?.toString() ?? 'Растение';
          
          // Определяем изображение растения
          String? plantImageUrl;
                      if (plant['photo'] != null && plant['photo'].toString().isNotEmpty) {
              plantImageUrl = plant['photo'].toString();
            } else if (plant['images'] != null && plant['images'] is Map) {
            final images = plant['images'] as Map;
            // ИСПРАВЛЕНО: thumbnail (кроп) должен быть приоритетным для списков
            plantImageUrl = images['thumbnail'] ?? 
                          images['crop'] ?? 
                          images['main_image'] ?? 
                          images['original'] ?? 
                          images['user_image'];
          }
          
          return [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlantDetailPage(plant: plant),
                    ),
                  );
                },
                onLongPress: () {
                  _showDeletePlantDialog(plant);
                },
                child: _buildPlantItem(
                  plantImageUrl, 
                  plantName.length > 10 ? '${plantName.substring(0, 10)}...' : plantName,
                  cardWidth, 
                  isSmallScreen,
                  isNetworkImage: plantImageUrl != null && plantImageUrl.startsWith('http'),
                ),
              ),
            ),
            if (index < plants.length - 1) SizedBox(width: isSmallScreen ? 6 : 8),
          ];
        }).expand((list) => list).toList(),
        
        // Заполняем пустые слоты если растений меньше 4
        ...List.generate(
          4 - plants.length,
          (index) => [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  print('🌱 MyDachaPage: Кнопка "Добавить" (страница) нажата!');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ScannerScreen()),
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: cardWidth + 20,
                  ),
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Color(0xFFE8E8E8),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.add_circle_outline,
                              size: 24,
                              color: Color(0xFFB8B8B8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 3 : 5),
                      Text(
                        'Добавить',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w400,
                          fontSize: isSmallScreen ? 9 : 10,
                          color: Color(0xFFB8B8B8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (index < 4 - plants.length - 1) SizedBox(width: isSmallScreen ? 6 : 8),
          ],
        ).expand((list) => list).toList(),
      ],
    );
  }

  // Индикаторы страниц
  Widget _buildPageIndicators(bool isSmallScreen) {
    if (_isLoadingPlants || _userPlants.isEmpty) {
      return SizedBox.shrink();
    }

    // Количество страниц
    final totalPages = ((_userPlants.length - 1) / 4).floor() + 1;
    
    if (totalPages <= 1) {
      return SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalPages, (index) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 2.5),
          width: isSmallScreen ? 6 : 8,
          height: isSmallScreen ? 6 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == _currentPlantsPage 
                ? Color(0xFFB2D39F) 
                : Color(0xFFF4F4F4),
          ),
        );
      }),
    );
  }

  // Загрузочный скелетон
  Widget _buildLoadingSkeleton(double cardWidth, bool isSmallScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (index) => 
        Expanded(
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
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
                ),
              ),
              SizedBox(height: isSmallScreen ? 3 : 5),
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ),
        ),
      ).expand((widget) => [
        widget,
        if (widget != null) SizedBox(width: isSmallScreen ? 6 : 8),
      ]).take(7).toList(),
    );
  }

  // Пустое состояние
  Widget _buildEmptyPlantsState(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Color(0xFFF0F8EC),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.eco_outlined,
                size: 30,
                color: Color(0xFF63A36C),
              ),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Ваша коллекция пуста',
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w600,
              fontSize: isSmallScreen ? 14 : 16,
              color: Color(0xFF1F2024),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Просканируйте ваши первые растения\nчтобы начать создавать коллекцию!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w400,
              fontSize: isSmallScreen ? 11 : 12,
              color: Color(0xFF7A7A7A),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
      BuildContext context, String iconPath, String title, double width, bool isSmallScreen,
      {bool isImage = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        constraints: BoxConstraints(
          minHeight: isSmallScreen ? 90 : 100,
        ),
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
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                flex: 3,
                child: isImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          iconPath,
                          width: width * (isSmallScreen ? 0.5 : 0.6),
                          height: width * (isSmallScreen ? 0.5 : 0.6),
                          fit: BoxFit.cover,
                        ),
                      )
                    : iconPath.endsWith('.svg')
                        ? SvgPicture.asset(
                            iconPath,
                            width: isSmallScreen ? 20 : 24,
                            height: isSmallScreen ? 20 : 24,
                          )
                        : Image.asset(
                            iconPath,
                            width: isSmallScreen ? 20 : 24,
                            height: isSmallScreen ? 20 : 24,
                          ),
              ),
              SizedBox(height: isSmallScreen ? 4 : 8),
              Flexible(
                flex: 2,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w700,
                      fontSize: isSmallScreen ? 9 : 10,
                      color: Colors.black,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomMenuItem(String title, bool isSmallScreen) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Gilroy',
        fontWeight: FontWeight.w600,
        fontSize: isSmallScreen ? 11 : 12,
        color: Colors.black,
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    // Показываем диалог подтверждения
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text('Выход из приложения'),
              content: Text('Вы уверены, что хотите выйти из приложения?'),
              actions: <Widget>[
                TextButton(
                  child: Text('Отмена'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                TextButton(
                  child: Text('Выйти'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirmed) {
      // Выполняем выход из системы
      try {
        await AuthService().signOut();
        // Перенаправляем на экран авторизации
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/auth', (route) => false);
      } catch (e) {
        // Показываем сообщение об ошибке, если что-то пошло не так
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Произошла ошибка при выходе из приложения'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _plantEventsSubscription?.cancel();
    _plantsPageController.dispose();
    super.dispose();
  }
}
