import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../homepage/UsefulInfoComponent.dart';
import '../homepage/BottomNavigationComponent.dart';
import '../homepage/home_screen.dart';
import '../scanner/scanner_screen.dart';
import '../services/api/scan_service.dart';
import '../services/api/favorites_service.dart';
import '../services/logger.dart';
import '../models/plant_info.dart';
import '../plant_result/plant_result_healthy_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../widgets/favorite_button.dart';
import 'package:http/http.dart' as http;

class ScanHistoryPage extends StatefulWidget {
  const ScanHistoryPage({Key? key}) : super(key: key);

  @override
  State<ScanHistoryPage> createState() => _ScanHistoryPageState();
}

class _ScanHistoryPageState extends State<ScanHistoryPage> with WidgetsBindingObserver {
  bool _isLoading = true;
  List<dynamic> _scanHistory = [];
  List<dynamic> _filteredScanHistory = [];

  // НОВОЕ: флаг, чтобы знать, был ли переход в "paused"
  bool _shouldReloadOnResume = false;

  String? _errorMessage;
  final ScanService _scanService = ScanService();
  
  // Получаем текущий месяц
  DateTime _selectedDate = DateTime.now();
  String get _currentMonth {
    try {
      return DateFormat('MMMM', 'ru_RU').format(_selectedDate);
    } catch (e) {
      // Если русская локаль не инициализирована, используем английскую
      final monthNames = [
        'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
        'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
      ];
      return monthNames[_selectedDate.month - 1];
    }
  }
  
  // Список всех месяцев для выбора
  final List<Map<String, dynamic>> _availableMonths = [
    {'date': DateTime(DateTime.now().year, 1), 'name': 'Январь'},
    {'date': DateTime(DateTime.now().year, 2), 'name': 'Февраль'},
    {'date': DateTime(DateTime.now().year, 3), 'name': 'Март'},
    {'date': DateTime(DateTime.now().year, 4), 'name': 'Апрель'},
    {'date': DateTime(DateTime.now().year, 5), 'name': 'Май'},
    {'date': DateTime(DateTime.now().year, 6), 'name': 'Июнь'},
    {'date': DateTime(DateTime.now().year, 7), 'name': 'Июль'},
    {'date': DateTime(DateTime.now().year, 8), 'name': 'Август'},
    {'date': DateTime(DateTime.now().year, 9), 'name': 'Сентябрь'},
    {'date': DateTime(DateTime.now().year, 10), 'name': 'Октябрь'},
    {'date': DateTime(DateTime.now().year, 11), 'name': 'Ноябрь'},
    {'date': DateTime(DateTime.now().year, 12), 'name': 'Декабрь'},
  ];
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);  // Добавляем наблюдатель
    _initializeDateFormatting();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);  // Удаляем наблюдатель
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Переход в настоящий фон: помечаем, что нужно обновить при возврате
      _shouldReloadOnResume = true;
    } else if (state == AppLifecycleState.resumed) {
      // Возврат на передний план
      if (_shouldReloadOnResume) {
        // Обновляем только если приложение действительно было в фоне
        _shouldReloadOnResume = false;
        AppLogger.ui('🔄 Приложение возобновлено из background, обновляем историю сканирования');
        FavoritesService.clearCache();
        _loadScanHistory();
      } else {
        // Приложение было лишь кратковременно неактивно (например, шторка)
        AppLogger.ui('✅ Приложение возобновлено из inactive, обновление истории не требуется');
      }
    }
  }
  
  // Этот метод вызывается когда возвращаемся на экран с другого экрана
  @override
  void didUpdateWidget(ScanHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    AppLogger.ui('🔄 Экран истории обновлен, перезагружаем данные');
    // Очищаем кэш чтобы получить актуальные данные при возврате
    FavoritesService.clearCache();
    _loadScanHistory();
  }
  
  // Инициализация локализации дат
  Future<void> _initializeDateFormatting() async {
    await initializeDateFormatting('ru_RU', null);
    _loadScanHistory();
  }
  
  // НОВОЕ: Предзагрузка статуса избранного для всех растений в истории
  Future<void> _preloadFavoriteStatuses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) return;
      
      AppLogger.api('🔄 Предзагрузка статусов избранного для ${_scanHistory.length} растений');
      
      final favoritesService = FavoritesService();
      
      // Проходим по всем растениям в истории и проверяем их статус
      for (final scan in _scanHistory) {
        if (scan is Map<String, dynamic>) {
          // ИСПРАВЛЕНО: Используем только scanId, НЕ ищем в коллекции
          String plantId = scan['_id'] ?? scan['scan_id'] ?? '';
          
          if (plantId.isNotEmpty) {
            AppLogger.api('🔍 Предзагрузка статуса для растения: ID=$plantId');
            // Проверяем статус избранного (это обновит кэш)
            await favoritesService.checkIsFavorite(token, plantId);
          }
        }
      }
      
      AppLogger.api('✅ Предзагрузка статусов избранного завершена');
      
      // Обновляем UI после загрузки статусов
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      AppLogger.error('Ошибка при предзагрузке статусов избранного: $e');
    }
  }
  
  Future<void> _loadScanHistory() async {
    try {
      // Получаем токен из SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Необходимо войти в аккаунт';
        });
        return;
      }
      
      // НОВОЕ: Загружаем коллекцию растений пользователя для правильного определения ID
      // Получаем историю сканирований
      final history = await _scanService.getScanHistory(token);
      
      setState(() {
        _scanHistory = history;
        _filteredScanHistory = _filterScansByMonth(history, _selectedDate);
        _isLoading = false;
      });
      
      // НОВОЕ: Предзагружаем статусы избранного после загрузки истории
      _preloadFavoriteStatuses();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Не удалось загрузить историю сканирований';
      });
      print('Ошибка при загрузке истории сканирований: $e');
    }
  }


  
  // Безопасное форматирование месяца и года
  String _formatMonthYear(DateTime date) {
    try {
      return DateFormat('MMMM yyyy', 'ru_RU').format(date);
    } catch (e) {
      final monthNames = [
        'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
        'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
      ];
      return '${monthNames[date.month - 1]} ${date.year}';
    }
  }
  
  // Безопасное форматирование даты
  String _formatDate(DateTime date) {
    try {
      return DateFormat('d MMMM', 'ru_RU').format(date);
    } catch (e) {
      final monthNames = [
        'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
        'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
      ];
      return '${date.day} ${monthNames[date.month - 1]}';
    }
  }
  
  // Фильтрация сканирований по выбранному месяцу
  List<dynamic> _filterScansByMonth(List<dynamic> scans, DateTime selectedMonth) {
    if (scans.isEmpty) return [];
    
    print('==== ФИЛЬТРАЦИЯ ПО МЕСЯЦУ ====');
    print('Выбранный месяц: ${_formatMonthYear(selectedMonth)}');
    print('Всего сканирований для фильтрации: ${scans.length}');
    
    final filteredScans = scans.where((scan) {
      try {
        // Определяем дату сканирования
        DateTime scanDate;
        
        if (scan['timestamp'] != null) {
          scanDate = DateTime.parse(scan['timestamp']);
        } else if (scan['scan_date'] != null) {
          scanDate = DateTime.parse(scan['scan_date']);
        } else if (scan['created_at'] != null) {
          scanDate = DateTime.parse(scan['created_at']);
        } else {
          print('⚠️ Нет даты в сканировании: ${scan['_id']}');
          return false;
        }
        
        // Проверяем соответствие месяца и года
        final matches = scanDate.year == selectedMonth.year && 
                       scanDate.month == selectedMonth.month;
        
                 if (matches) {
           print('✅ Сканирование ${scan['_id']} подходит: ${scanDate.day}.${scanDate.month}.${scanDate.year}');
         }
        
        return matches;
      } catch (e) {
        print('❌ Ошибка при обработке даты сканирования: $e');
        return false;
      }
    }).toList();
    
    print('Результат фильтрации: ${filteredScans.length} сканирований');
    print('==== КОНЕЦ ФИЛЬТРАЦИИ ====');
    
    return filteredScans;
  }
  
  // Показать диалог выбора месяца
  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: 400,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Заголовок
              Container(
                padding: EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Выберите месяц',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Gilroy',
                        color: Color(0xFF1F2024),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.close,
                        color: Color(0xFF63A36C),
                      ),
                    ),
                  ],
                ),
              ),
              // Список месяцев
              Expanded(
                child: ListView.builder(
                  itemCount: _availableMonths.length,
                  itemBuilder: (context, index) {
                    final month = _availableMonths[index];
                    final isSelected = _selectedDate.month == month['date'].month;
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = month['date'];
                          _filteredScanHistory = _filterScansByMonth(_scanHistory, _selectedDate);
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        decoration: BoxDecoration(
                          color: isSelected ? Color(0xFFD0E6C3) : Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              'assets/images/my_dacha/kalendar.svg',
                              width: 16,
                              height: 16,
                              color: isSelected ? Color(0xFF63A36C) : Color(0xFF1F2024),
                            ),
                            SizedBox(width: 12),
                            Text(
                              month['name'],
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'Gilroy',
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? Color(0xFF63A36C) : Color(0xFF1F2024),
                              ),
                            ),
                            Spacer(),
                            if (isSelected)
                              Icon(
                                Icons.check,
                                color: Color(0xFF63A36C),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Метод для группировки сканирований по датам
  Map<String, List<dynamic>> _groupScansByDate() {
    final Map<String, List<dynamic>> groupedScans = {};
    
    print('==== Данные истории сканирований ====');
    print('Всего элементов после фильтрации: ${_filteredScanHistory.length}');
    
    // Получаем текущую дату для группировки
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    
    for (int i = 0; i < _filteredScanHistory.length; i++) {
      print('Элемент #$i: ${json.encode(_filteredScanHistory[i])}');
      
      final scan = _filteredScanHistory[i];
      
      // Определяем дату сканирования
      DateTime scanDate;
      
      // Проверяем наличие timestamp в разных местах структуры
      if (scan['timestamp'] != null) {
        scanDate = DateTime.parse(scan['timestamp']);
      } else if (scan['scan_date'] != null) {
        scanDate = DateTime.parse(scan['scan_date']);
      } else if (scan['created_at'] != null) {
        scanDate = DateTime.parse(scan['created_at']);
      } else {
        // Если timestamp нет совсем, используем вчерашнюю дату для примера
        print('⚠️ ОШИБКА: Нет поля timestamp/scan_date/created_at в элементе #$i');
        scanDate = yesterday;
      }
      
      // Определяем ключ для группировки
      String dateKey;
      
      if (scanDate.year == today.year && scanDate.month == today.month && scanDate.day == today.day) {
        dateKey = 'Сегодня';
      } else if (scanDate.year == yesterday.year && scanDate.month == yesterday.month && scanDate.day == yesterday.day) {
        dateKey = 'Вчера';
      } else {
        dateKey = _formatDate(scanDate);
      }
      
      // Добавляем сканирование в соответствующую группу
      if (!groupedScans.containsKey(dateKey)) {
        groupedScans[dateKey] = [];
      }
      
      groupedScans[dateKey]!.add(scan);
    }
    
    return groupedScans;
  }
  
  // Форматирует дату для группировки
  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Сегодня';
    } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Вчера';
    } else {
      return _formatDate(date);
    }
  }
  
  // Получение форматированной даты для отображения
  String _getFormattedDate(String dateKey) {
    if (dateKey == 'Сегодня' || dateKey == 'Вчера') {
      return dateKey;
    }
    return dateKey;
  }
  
  // Открывает экран с детальной информацией о растении
  Future<void> _openPlantDetails(dynamic scanData) async {
    if (scanData == null) {
      print('⚠️ scanData равен null, не могу открыть детали');
      return;
    }
    
    try {
      print('Попытка создания PlantInfo из scanData: ${json.encode(scanData)}');
      
      // Проверяем наличие result и plant_info в scanData
      if (!(scanData is Map) || 
          !scanData.containsKey('result') || 
          scanData['result'] == null ||
          !(scanData['result'] is Map) || 
          !scanData['result'].containsKey('plant_info') || 
          scanData['result']['plant_info'] == null) {
        print('⚠️ Отсутствует поле result.plant_info в scanData или оно равно null');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: данные растения отсутствуют или повреждены')),
        );
        return;
      }
      
      final plantInfoData = scanData['result']['plant_info'];
      
      // ИСПРАВЛЕНО: Используем только scanId для открытия деталей
      // НЕ ищем в коллекции - растение из истории независимо от коллекции
      final plantInfoWithScanId = Map<String, dynamic>.from(plantInfoData);
      
      final scanId = scanData['_id'] ?? scanData['scan_id'] ?? '';
      final plantName = plantInfoData['name'] ?? '';
      
      AppLogger.api('🔍 _openPlantDetails: Открываем растение "$plantName" с scanId: "$scanId"');
      
      // Используем scanId как есть - не ищем в коллекции
      plantInfoWithScanId['scan_id'] = scanId;
      
      print('🆔 Финальный ID для PlantInfo: "${plantInfoWithScanId['scan_id']}"');
      print('🔍 Доступные ключи в scanData: ${scanData.keys.toList()}');
      
      // Создаем PlantInfo с помощью фабричного метода
      final plantInfo = PlantInfo.fromJson(plantInfoWithScanId);
      
      print('PlantInfo успешно создан: name=${plantInfo.name}, tags.length=${plantInfo.tags.length}');
      
      // Переходим на экран результатов
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlantResultHealthyScreen(
            isHealthy: plantInfo.isHealthy,
            plantData: plantInfo,
            fromScanHistory: true, // Указываем, что открыто из истории сканирования
          ),
        ),
      );
      
      // Обновляем историю при возврате, чтобы синхронизировать лайки
      AppLogger.ui('🔄 Возврат с экрана результата, обновляем историю сканирования');
      _loadScanHistory();
    } catch (e) {
      print('⚠️ Ошибка при открытии деталей растения: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть детали растения: $e')),
      );
    }
  }
  
  // Безопасно преобразует JSON-данные в List<String>
  List<String> _getSafeListFromJson(dynamic jsonData) {
    if (jsonData == null) return [];
    if (jsonData is List) {
      return jsonData.map((item) => item?.toString() ?? '').toList();
    }
    return [];
  }
  
  // Безопасно преобразует JSON-данные в Map<String, dynamic>
  Map<String, dynamic> _getSafeMapFromJson(dynamic jsonData) {
    if (jsonData == null) return {};
    if (jsonData is Map) {
      return Map<String, dynamic>.from(jsonData);
    }
    return {};
  }
  
  // Безопасно преобразует JSON-данные в Map<String, String> для изображений
  Map<String, String> _getSafeImageMapFromJson(dynamic jsonData) {
    if (jsonData == null) return {};
    if (jsonData is Map) {
      final result = <String, String>{};
      jsonData.forEach((key, value) {
        if (key is String && value != null) {
          result[key] = value.toString();
        }
      });
      return result;
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    // Группируем сканирования по датам
    final groupedScans = _filteredScanHistory.isEmpty ? <String, List<dynamic>>{} : _groupScansByDate();
    
    return Scaffold(
      extendBody: true, // Расширяем body под нижнюю навигацию
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
          child: Stack(
            children: [
              // Основной контент с прокруткой
              Positioned.fill(
                child: Column(
                  children: [
                    // Верхняя часть с заголовком (фиксированная)
                    Container(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: SvgPicture.asset(
                              'assets/images/favorites/back_arrow.svg',
                              width: 24,
                              height: 24,
                              color: Color(0xFF63A36C),
                            ),
                          ),
                          SizedBox(width: 16),
                          Text(
                            'История сканирований',
                            style: TextStyle(
                              color: Color(0xFF1F2024),
                              fontSize: 18,
                              fontFamily: 'Gilroy',
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.005,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Расширяемый контейнер с историей
                    Expanded(
                      child: Stack(
                        children: [
                          // Белый контейнер с историей
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 22),
                            child: Container(
                              decoration: ShapeDecoration(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                shadows: [
                                  BoxShadow(
                                    color: Color(0x1931873F),
                                    blurRadius: 20,
                                    offset: Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 15),
                                  // Выбор месяца с зеленой подложкой
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 15),
                                    child: GestureDetector(
                                      onTap: _showMonthPicker,
                                      child: Container(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: ShapeDecoration(
                                          color: Color(0xFFD0E6C3),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(100),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SvgPicture.asset(
                                              'assets/images/my_dacha/kalendar.svg',
                                              width: 14,
                                              height: 14,
                                              color: Colors.black,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              _currentMonth, // Динамически обновляется
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 12,
                                                fontFamily: 'Gilroy',
                                                letterSpacing: 0.12,
                                              ),
                                            ),
                                            SizedBox(width: 4),
                                            Icon(
                                              Icons.keyboard_arrow_down,
                                              size: 14,
                                              color: Colors.black,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  
                                  // Отображение загрузки или данных
                                  Expanded(
                                    child: _isLoading
                                      ? Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFF63A36C),
                                          ),
                                        )
                                      : _errorMessage?.isNotEmpty == true
                                        ? Center(
                                            child: Text(
                                              _errorMessage!,
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 16,
                                                fontFamily: 'Gilroy',
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          )
                                        : _filteredScanHistory.isEmpty
                                          ? Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  SvgPicture.asset(
                                                    'assets/images/my_dacha/kalendar.svg',
                                                    width: 48,
                                                    height: 48,
                                                    color: Color(0xFF63A36C).withOpacity(0.5),
                                                  ),
                                                  SizedBox(height: 16),
                                                  Text(
                                                    'Нет сканирований за ${_currentMonth.toLowerCase()}',
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
                                                    'Выберите другой месяц или создайте\nновое сканирование',
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
                                            )
                                          : ListView(
                                              padding: EdgeInsets.fromLTRB(15, 0, 15, 250), // Увеличенный отступ снизу для UsefulInfoComponent + BottomNav
                                              children: [
                                                // Выводим сгруппированные сканирования
                                                for (String dateKey in groupedScans.keys)
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      // Заголовок группы
                                                      dateKey == 'Сегодня'
                                                        ? _buildDateHeaderRich('Сегодня', _formatDate(DateTime.now()))
                                                        : _buildDateHeader(_getFormattedDate(dateKey)),
                                                      
                                                      // Элементы группы
                                                      ...((groupedScans[dateKey] ?? []).map((scan) => 
                                                        _buildScanItem(
                                                          context,
                                                          _getSafeImageUrl(scan),
                                                          _getSafePlantName(scan),
                                                          _getSafePlantType(scan),
                                                          () => _openPlantDetails(scan),
                                                          scan, // Передаем данные сканирования для извлечения ID растения
                                                        )
                                                      ).toList()),
                                                      
                                                      SizedBox(height: 10),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Градиентный фон снизу (не блокирует касания) - красивый как раньше
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 320, // Увеличиваем высоту градиента
                            child: IgnorePointer(  // Делаем градиент прозрачным для касаний
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment(0.00, -1.00),
                                    end: Alignment(0, 1),
                                    colors: [
                                      Color(0x00C7E6B5), // Прозрачный вверху
                                      Color(0xFFC2E3B0), // Средний цвет
                                      Color(0xFFB7DFA5)  // Насыщенный внизу
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Фиксированный блок "Полезная информация" снизу (динамически над нижним меню)
              Positioned(
                left: 0,
                right: 0,
                bottom: kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom, // Динамически над нижним меню
                child: UsefulInfoComponent(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationComponent(
        selectedIndex: 3, // Соответствует индексу "Моя дача" в BottomNavigation
        onItemTapped: (index) {
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ScannerScreen()),
            );
            return;
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => HomeScreen(initialIndex: index)),
          );
        },
      ),
    );
  }

  // Заголовок даты с разным форматированием для "Сегодня" и даты
  Widget _buildDateHeaderRich(String prefix, String date) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$prefix ',
              style: TextStyle(
                color: Color(0xFF1F2024),
                fontSize: 14,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w700,
                letterSpacing: 0.07,
              ),
            ),
            TextSpan(
              text: date,
              style: TextStyle(
                color: Color(0xFF63A36C),
                fontSize: 14,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w700,
                letterSpacing: 0.07,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Обычный заголовок даты
  Widget _buildDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Text(
        date,
        style: TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontFamily: 'Gilroy',
          fontWeight: FontWeight.w700,
          letterSpacing: 0.07,
        ),
      ),
    );
  }

  // Элемент списка сканирований с изображением, поддерживающий как URL так и ассеты
  Widget _buildScanItem(
    BuildContext context,
    String imageUrl,
    String plantName,
    String plantType,
    VoidCallback onTap,
    dynamic scanData, // Данные сканирования для извлечения ID растения
  ) {
    print('==== Построение элемента сканирования ====');
    print('imageUrl: $imageUrl');
    print('plantName: $plantName');
    print('plantType: $plantType');
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 5),
        height: 52,
        child: Row(
          children: [
            // Круглое изображение растения
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFD9D9D9),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: imageUrl.startsWith('http')
                  ? Image.network(
                      imageUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print('⚠️ Ошибка загрузки изображения: $error');
                        return _buildPlaceholderImage();
                      },
                    )
                  : imageUrl.isNotEmpty 
                    ? Image.asset(
                        imageUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderImage();
                        },
                      )
                    : _buildPlaceholderImage(),
              ),
            ),
            SizedBox(width: 12),
            // Информация о растении
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    plantName,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.08,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    plantType,
                    style: TextStyle(
                      color: Color(0xFF63A36C),
                      fontSize: 14,
                      fontFamily: 'Gilroy',
                    ),
                  ),
                ],
              ),
            ),
            // Кнопка избранного
            _buildFavoriteButtonForScan(scanData),
          ],
        ),
      ),
    );
  }

  String _getSafeImageUrl(dynamic scan) {
    if (scan is Map<String, dynamic>) {
      print('==== Анализ структуры сканирования ====');
      print('Ключи верхнего уровня: ${scan.keys.toList()}');
      
      // Сначала проверяем изображения на верхнем уровне сканирования
      final topLevelImageKeys = [
        'image_url',
        'thumbnail_url', 
        'user_image_url',
        'original_image_url',
        'scan_image_url'
      ];
      
      for (String key in topLevelImageKeys) {
        if (scan[key] != null && scan[key].toString().isNotEmpty) {
          print('Найдено изображение на верхнем уровне - $key: ${scan[key]}');
          return scan[key].toString();
        }
      }
      
      // Затем проверяем в result.plant_info.images
      if (scan['result'] is Map<String, dynamic> && 
          scan['result']['plant_info'] is Map<String, dynamic> && 
          scan['result']['plant_info']['images'] is Map<String, dynamic>) {
        
        final images = scan['result']['plant_info']['images'];
        
        print('==== Доступные изображения в plant_info ====');
        images.forEach((key, value) {
          print('$key: $value');
        });
        print('==== Конец списка изображений ====');
        
        // ИСПРАВЛЕНО: thumbnail (кроп) должен быть приоритетным для списков
        final imageKeys = [
          'thumbnail',      // КРОП 300x300px - приоритет №1 для списков!
          'crop',           // Алиас кропа
          'user_image',     // Изображение пользователя
          'original_image', // Оригинальное изображение
          'scan_image',     // Изображение сканирования
          'uploaded_image', // Загруженное изображение
          'main_image',     // Основное изображение (обычно из базы)
          'icon_image'      // Иконка (последний приоритет)
        ];
        
        for (String key in imageKeys) {
          if (images[key] != null && images[key].toString().isNotEmpty) {
            final imageUrl = images[key].toString();
            
            // Проверяем, не является ли это изображением из Unsplash (неправильное изображение)
            if (key == 'main_image' && imageUrl.contains('unsplash.com')) {
              print('Пропускаем main_image из Unsplash: $imageUrl');
              continue; // Пропускаем изображения из Unsplash для main_image
            }
            
            print('Используем $key: $imageUrl');
            return imageUrl;
          }
        }
      }
      
      // Если ничего нет, возвращаем пустую строку (будет показана заглушка)
      print('Нет доступных пользовательских изображений');
      return '';
    }
    return '';
  }

  String _getSafePlantName(dynamic scan) {
    if (scan is Map<String, dynamic> && 
        scan['result'] is Map<String, dynamic> && 
        scan['result']['plant_info'] is Map<String, dynamic> && 
        scan['result']['plant_info']['name'] is String) {
      return scan['result']['plant_info']['name'];
    }
    return 'Неизвестное растение';
  }

  String _getSafePlantType(dynamic scan) {
    if (scan is Map<String, dynamic> && 
        scan['result'] is Map<String, dynamic> && 
        scan['result']['plant_info'] is Map<String, dynamic>) {
      
      final plantInfo = scan['result']['plant_info'];
      
      // Сначала проверим есть ли tags
      if (plantInfo['tags'] is List && (plantInfo['tags'] as List).isNotEmpty) {
        return plantInfo['tags'][0].toString();
      }
      
      // Затем проверим, есть ли latin_name
      if (plantInfo['latin_name'] is String && plantInfo['latin_name'].toString().isNotEmpty) {
        return plantInfo['latin_name'];
      }
      
      // Если ничего не нашли, возвращаем просто "Растение"
      return 'Растение';
    }
    return 'Растение';
  }

  Widget _buildFavoriteButtonForScan(dynamic scanData) {
    // Извлекаем ID растения из данных сканирования
    String plantId = '';
    PlantInfo? plantInfo;
    
    print('🔧 ОТЛАДКА _buildFavoriteButtonForScan вызван!');
    print('🔧 scanData type: ${scanData.runtimeType}');
    if (scanData is Map<String, dynamic>) {
      print('🔧 scanData keys: ${scanData.keys.toList()}');
      print('🔧 scanData[\'_id\']: ${scanData['_id']}');
      print('🔧 scanData[\'scan_id\']: ${scanData['scan_id']}');
      
      // ИСПРАВЛЕНО: Используем только scanId, НЕ ищем в коллекции по названию
      // История сканирований и коллекция избранных - это РАЗНЫЕ сущности!
      String scanId = scanData['_id'] ?? scanData['scan_id'] ?? '';
      plantId = scanId; // Всегда используем ID сканирования
      
      print('🔧 История: scanId извлечен: "$plantId"');
      
      // Сначала пытаемся найти правильный plant ID через название растения
      if (scanData['result'] is Map<String, dynamic> && 
          scanData['result']['plant_info'] is Map<String, dynamic>) {
        
        final plantInfoData = scanData['result']['plant_info'];
        final plantName = plantInfoData['name'] ?? '';
        
        print('🔧 История: Растение из сканирования: "$plantName", scanId: $plantId');
        
        // Создаем PlantInfo объект для передачи в FavoriteButton
        try {
          plantInfo = PlantInfo.fromJson(plantInfoData);
          // Устанавливаем scanId, если его нет в plantInfo
          if (plantInfo.scanId.isEmpty && scanId.isNotEmpty) {
            plantInfo = PlantInfo(
              name: plantInfo.name,
              latinName: plantInfo.latinName,
              description: plantInfo.description,
              isHealthy: plantInfo.isHealthy,
              difficultyLevel: plantInfo.difficultyLevel,
              tags: plantInfo.tags,
              careInfo: plantInfo.careInfo,
              growingConditions: plantInfo.growingConditions,
              pestsAndDiseases: plantInfo.pestsAndDiseases,
              seasonalCare: plantInfo.seasonalCare,
              additionalInfo: plantInfo.additionalInfo,
              images: plantInfo.images,
              toxicity: plantInfo.toxicity,
              scanId: scanId, // Используем scanId для совместимости с другой логикой
            );
          }
        } catch (e) {
          print('🔧 Ошибка создания PlantInfo для FavoriteButton: $e');
        }
      } else {
        plantId = scanId; // Fallback к ID сканирования
      }
    }
    
    if (plantId.isNotEmpty) {
      print('🔧 История: Создаем FavoriteButton для plantId: $plantId');
      
      // НОВОЕ: Проверяем статус избранного из кэша
      final cachedStatus = FavoritesService.getCachedStatus(plantId);
      bool initialIsFavorite = false;
      String? initialFavoriteId;
      
      if (cachedStatus != null) {
        initialIsFavorite = cachedStatus['isFavorite'] ?? false;
        initialFavoriteId = cachedStatus['favoriteId'];
        print('🔧 История: Используем кэшированный статус для $plantId: isFavorite=$initialIsFavorite, favoriteId=$initialFavoriteId');
      } else {
        print('🔧 История: Нет кэша для $plantId, FavoriteButton сделает API запрос');
      }
      
      return FavoriteButton(
        plantId: plantId,
        size: 20.0,
        activeColor: Color(0xFF63A36C),
        inactiveColor: Color(0xFFBDBDBD),
        plantData: plantInfo, // Передаем данные растения
        initialIsFavorite: initialIsFavorite, // НОВОЕ: Передаем начальный статус
        initialFavoriteId: initialFavoriteId, // НОВОЕ: Передаем начальный ID
        onToggle: () {
          // ДОБАВЛЕН CALLBACK: Обновляем список после изменения статуса лайка
          print('🔧 Лайк изменен, обновляем список истории');
          _loadScanHistory();
        },
      );
    } else {
      print('🔧 История: plantId пустой, показываем неактивную иконку');
      // Если нет ID, показываем неактивную иконку
      return SizedBox(
        width: 30,
        height: 30,
        child: Center(
          child: Icon(
            Icons.favorite_border,
            size: 20,
            color: Color(0xFFBDBDBD),
          ),
        ),
      );
    }
  }



  // Метод для создания заглушки изображения
  Widget _buildPlaceholderImage() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Color(0xFFD0E6C3), // Светло-зеленый цвет
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.local_florist, // Иконка цветка
        color: Color(0xFF63A36C),
        size: 24,
      ),
    );
  }
}
