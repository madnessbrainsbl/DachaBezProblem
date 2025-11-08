import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/api/scan_service.dart';
import '../services/logger.dart';
import '../homepage/BottomNavigationComponent.dart';
import '../scanner/scanner_screen.dart';
import '../homepage/home_screen.dart';
import 'plant_detail_page.dart';
import '../services/plant_events.dart';

class PlantCollectionPage extends StatefulWidget {
  const PlantCollectionPage({Key? key}) : super(key: key);

  @override
  State<PlantCollectionPage> createState() => _PlantCollectionPageState();
}

class _PlantCollectionPageState extends State<PlantCollectionPage> {
  final ScanService _scanService = ScanService();
  List<dynamic> _allPlants = [];
  List<dynamic> _filteredPlants = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'Все';

  // Динамические фильтры на основе загруженных данных
  List<String> _availableFilters = ['Все'];
  
  // Подписка на события
  StreamSubscription? _plantEventsSubscription;

  @override
  void initState() {
    super.initState();
    _loadPlants();
    _subscribeToPlantEvents();
  }

  @override
  void dispose() {
    _plantEventsSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToPlantEvents() {
    _plantEventsSubscription = PlantEvents().stream.listen((_) {
      print('🔄 PlantCollectionPage: Получено событие обновления коллекции');
      _loadPlants();
    });
  }

  Future<void> _loadPlants() async {
    try {
      AppLogger.ui('Загрузка коллекции растений');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        AppLogger.ui('Токен не найден');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final plants = await _scanService.getUserPlantCollection(token);
      
      // Логируем структуру данных для отладки
      if (plants.isNotEmpty) {
        AppLogger.ui('Первое растение из коллекции: ${plants.first}');
        final firstPlant = plants.first;
        if (firstPlant['images'] != null) {
          AppLogger.ui('Изображения первого растения: ${firstPlant['images']}');
        }
      }
      
      // Генерируем фильтры на основе реальных данных
      _generateAvailableFilters(plants);
      
      setState(() {
        _allPlants = plants;
        _filteredPlants = plants;
        _isLoading = false;
      });
      
      AppLogger.ui('Загружено растений: ${plants.length}');
    } catch (e) {
      AppLogger.error('Ошибка загрузки коллекции растений', e);
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _generateAvailableFilters(List<dynamic> plants) {
    final Set<String> uniqueFilters = {'Все'};
    
    // Добавляем стандартные фильтры только если есть соответствующие растения
    bool hasHealthy = false;
    bool hasUnhealthy = false;
    final Set<String> existingTags = {};
    
    for (var plant in plants) {
      // Проверяем здоровье растений
      if (plant['is_healthy'] == true) hasHealthy = true;
      if (plant['is_healthy'] == false) hasUnhealthy = true;
      
      // Собираем все уникальные теги
      final tags = plant['tags'] as List? ?? [];
      for (var tag in tags) {
        if (tag != null && tag.toString().isNotEmpty) {
          existingTags.add(tag.toString());
        }
      }
    }
    
    // Добавляем фильтры состояния только если есть соответствующие растения
    if (hasHealthy) uniqueFilters.add('Здоровые');
    if (hasUnhealthy) uniqueFilters.add('Требуют внимания');
    
    // Добавляем фильтры на основе существующих тегов
    uniqueFilters.addAll(existingTags);
    
    _availableFilters = uniqueFilters.toList();
    
    // Сбрасываем выбранный фильтр если его больше нет
    if (!_availableFilters.contains(_selectedFilter)) {
      _selectedFilter = 'Все';
    }
    
    AppLogger.ui('Доступные фильтры: $_availableFilters');
  }

  void _filterPlants() {
    setState(() {
      _filteredPlants = _allPlants.where((plant) {
        // Фильтр по поиску
        bool matchesSearch = true;
        if (_searchQuery.isNotEmpty) {
          final plantName = plant['name']?.toString().toLowerCase() ?? '';
          final latinName = plant['latin_name']?.toString().toLowerCase() ?? '';
          final searchLower = _searchQuery.toLowerCase();
          matchesSearch = plantName.contains(searchLower) || latinName.contains(searchLower);
        }

        // Фильтр по категории
        bool matchesFilter = true;
        if (_selectedFilter != 'Все') {
          if (_selectedFilter == 'Здоровые') {
            matchesFilter = plant['is_healthy'] == true;
          } else if (_selectedFilter == 'Требуют внимания') {
            matchesFilter = plant['is_healthy'] == false;
          } else {
            // Для всех остальных фильтров ищем точное совпадение в тегах
            final tags = plant['tags'] as List? ?? [];
            matchesFilter = tags.any((tag) => tag.toString() == _selectedFilter);
          }
        }

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;

    return Scaffold(
      extendBody: true, // Расширяем body под нижнюю навигацию
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
              
              // Поисковая строка и фильтры
              _buildSearchAndFilters(isSmallScreen),
              
              // Содержимое
              Expanded(
                child: _isLoading
                    ? _buildLoadingContent()
                    : _filteredPlants.isEmpty
                        ? _buildEmptyContent()
                        : _buildPlantsGrid(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationComponent(
        selectedIndex: 3,
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

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(15),
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
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF0F0F0),
              ),
              child: Center(
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: Color(0xFF1F2024),
                ),
              ),
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Text(
              'Моя коллекция',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: Color(0xFF1F2024),
              ),
            ),
          ),
          Text(
            '${_filteredPlants.length} растений',
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Color(0xFF63A36C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(15),
      child: Column(
        children: [
          // Поисковая строка
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1931873F),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _filterPlants();
              },
              decoration: InputDecoration(
                hintText: 'Поиск растений...',
                hintStyle: TextStyle(
                  fontFamily: 'Gilroy',
                  color: Color(0xFFB8B8B8),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Color(0xFF63A36C),
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          
          SizedBox(height: 12),
          
          // Фильтры
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _availableFilters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = filter;
                      });
                      _filterPlants();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Color(0xFF63A36C) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1931873F),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w500,
                          fontSize: isSmallScreen ? 12 : 13,
                          color: isSelected ? Colors.white : Color(0xFF1F2024),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingContent() {
    return Padding(
      padding: EdgeInsets.all(15),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1931873F),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF63A36C)),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyContent() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Color(0xFFF0F8EC),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.eco_outlined,
                  size: 40,
                  color: Color(0xFF63A36C),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'Растения не найдены'
                  : 'Ваша коллекция пуста',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Color(0xFF1F2024),
              ),
            ),
            SizedBox(height: 10),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Попробуйте изменить поисковый запрос\nили выберите другой фильтр'
                  : 'Просканируйте ваши первые растения\nчтобы начать создавать коллекцию!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: Color(0xFF7A7A7A),
                height: 1.4,
              ),
            ),
            SizedBox(height: 30),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ScannerScreen()),
                );
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Color(0xFF63A36C),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1931873F),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  'Сканировать растение',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantsGrid() {
    return Padding(
      padding: EdgeInsets.all(15),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _filteredPlants.length,
        itemBuilder: (context, index) {
          final plant = _filteredPlants[index];
          return GestureDetector(
            onTap: () {
              // Переход на детальную страницу растения
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlantDetailPage(plant: plant),
                ),
              );
            },
            child: _buildPlantCard(plant),
          );
        },
      ),
    );
  }

  Widget _buildPlantCard(Map<String, dynamic> plant) {
    final plantName = plant['name']?.toString() ?? 'Растение';
    final isHealthy = plant['is_healthy'] ?? true;
    final tags = plant['tags'] as List? ?? [];
    
    // Получаем изображение по новой логике API
    String? imageUrl;
    if (plant['images'] != null && plant['images'] is Map) {
      final images = plant['images'] as Map;
      // ИСПРАВЛЕНО: thumbnail (кроп) должен быть приоритетным для списков
      // Приоритет: thumbnail (кроп) > crop > main_image > original > user_image
      imageUrl = images['thumbnail'] ?? 
                images['crop'] ?? 
                images['main_image'] ?? 
                images['original'] ?? 
                images['user_image'];
      
      // Если ничего не нашли, но в images есть значения, берем первое непустое
      if (imageUrl == null && images.values.isNotEmpty) {
        for (var value in images.values) {
          if (value != null && value.toString().isNotEmpty) {
            imageUrl = value.toString();
            break;
          }
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0x1931873F),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Изображение растения
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    color: Color(0xFFF0F0F0),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: imageUrl != null && imageUrl.startsWith('http')
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Color(0xFFF0F0F0),
                                child: Center(
                                  child: Icon(
                                    Icons.eco_outlined,
                                    size: 32,
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
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF63A36C)),
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Color(0xFFF0F0F0),
                            child: Center(
                              child: Icon(
                                Icons.eco_outlined,
                                size: 32,
                                color: Color(0xFF63A36C),
                              ),
                            ),
                          ),
                  ),
                ),
                
                // Индикатор здоровья
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isHealthy ? Color(0xFF4CAF50) : Color(0xFFFF9800),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isHealthy ? Icons.check : Icons.warning,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Информация о растении
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plantName,
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1F2024),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                if (tags.isNotEmpty) ...[
                  SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: tags.take(2).map((tag) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(0xFFF0F8EC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag.toString(),
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w400,
                            fontSize: 10,
                            color: Color(0xFF63A36C),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
} 