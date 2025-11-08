import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../homepage/UsefulInfoComponent.dart';
import '../homepage/BottomNavigationComponent.dart';
import '../homepage/home_screen.dart';
import '../scanner/scanner_screen.dart';
import '../models/achievement.dart';
import '../services/api/achievement_service.dart';
import '../config/api_config.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({Key? key}) : super(key: key);

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  List<Achievement> _achievements = [];
  List<AchievementTemplate> _templates = [];
  AchievementStats? _stats;
  UserProgress? _userProgress;
  bool _isLoading = true;
  String _selectedCategory = 'Все';
  bool _isProgressExpanded = false;

  final List<String> _categories = [
    'Все',
    'Сканирование',
    'Напоминания', 
    'Активность',
    'Чат с ИИ',
    'Избранное',
    'Специальное'
  ];

  final Map<String, String> _categoryMap = {
    'Все': '',
    'Сканирование': 'scan',
    'Напоминания': 'reminder',
    'Активность': 'daily',
    'Чат с ИИ': 'chat',
    'Избранное': 'favorite',
    'Специальное': 'special'
  };

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      if (token.isEmpty) {
        print('❌ Токен авторизации не найден');
        setState(() => _isLoading = false);
        return;
      }

      print('🏆 ===== НАЧАЛО ЗАГРУЗКИ ДОСТИЖЕНИЙ =====');
      print('🔑 Токен длина: ${token.length}');

      // Загружаем данные параллельно, включая прогресс
      final results = await Future.wait([
        AchievementService.getUserAchievements(token),
        AchievementService.getAchievementTemplates(token),
        AchievementService.getAchievementStats(token),
        AchievementService.getUserProgress(token),
      ]);

      print('📦 ===== РЕЗУЛЬТАТЫ ЗАГРУЗКИ =====');
      final achievements = results[0] as List<Achievement>;
      final templates = results[1] as List<AchievementTemplate>;
      final stats = results[2] as AchievementStats?;
      final progressData = results[3] as Map<String, dynamic>?;
      
      print('🏆 Полученные достижения: ${achievements.length}');
      for (int i = 0; i < achievements.length; i++) {
        final achievement = achievements[i];
        print('   ${i + 1}. ID: ${achievement.id}');
        print('      Название: ${achievement.name}');
        print('      Тип: ${achievement.template?.achievementType ?? "unknown"}');
        print('      Дата: ${achievement.date}');
        print('      Template ID: ${achievement.template?.id ?? "null"}');
        print('      Template название: ${achievement.template?.name ?? "null"}');
      }
      
      print('📋 Шаблоны достижений: ${templates.length}');
      for (int i = 0; i < templates.length && i < 10; i++) {
        final template = templates[i];
        print('   ${i + 1}. ID: ${template.id}');
        print('      Название: ${template.name}');
        print('      Тип: ${template.achievementType}');
        print('      Иконка: ${template.iconUrl}');
        print('      Категория: ${template.category}');
      }

      setState(() {
        _achievements = achievements;
        _templates = templates;
        _stats = stats;
        
        if (progressData != null) {
          _userProgress = UserProgress.fromJson(progressData);
        }
        
        _isLoading = false;
      });

      print('✅ Загружено: ${_achievements.length} достижений, ${_templates.length} шаблонов');
      
      // Проверяем соответствие между достижениями и шаблонами
      print('🔍 ===== ПРОВЕРКА СООТВЕТСТВИЙ =====');
      int matchCount = 0;
      for (final achievement in _achievements) {
        final matchingTemplate = _templates.firstWhere(
          (template) => template.id == achievement.template?.id,
          orElse: () => AchievementTemplate(
            id: 'not_found',
            name: 'Не найден',
            description: '',
            iconUrl: '',
            points: 0,
            achievementType: '',
            category: '',
          ),
        );
        
        if (matchingTemplate.id != 'not_found') {
          matchCount++;
          print('✅ Найдено соответствие: ${achievement.name} -> ${matchingTemplate.name}');
        } else {
          print('❌ НЕ найден шаблон для достижения: ${achievement.name} (Template ID: ${achievement.template?.id})');
        }
      }
      print('📊 Всего соответствий найдено: $matchCount из ${_achievements.length}');
      
      // Создаем тестовые шаблоны только если реальные не загружены
      if (_templates.isEmpty) {
        print('⚠️ Шаблоны не загружены! Создаю тестовые шаблоны для демонстрации');
        _createTestTemplates();
      } else {
        print('✅ Реальные шаблоны загружены из API');
      }
      
      // Создаем тестовый прогресс если API не отвечает
      if (_userProgress == null) {
        print('⚠️ Прогресс не загружен! Создаю тестовый прогресс');
        _userProgress = UserProgress(
          scan: AchievementProgress(current: 5, next: 10, thresholds: [1, 5, 25, 50, 100]),
          reminder: AchievementProgress(current: 0, next: 1, thresholds: [1, 5, 10, 25]),
          daily: AchievementProgress(current: 1, next: 7, thresholds: [3, 7, 30]),
          chat: AchievementProgress(current: 0, next: 1, thresholds: [1, 10, 50]),
          favorite: AchievementProgress(current: 0, next: 1, thresholds: [1, 5, 25]),
        );
      }
      
      print('📊 Прогресс: ${_userProgress != null ? "загружен" : "не загружен"}');
      print('🏆 ===== ЗАВЕРШЕНИЕ ЗАГРУЗКИ ДОСТИЖЕНИЙ =====');
    } catch (e) {
      print('❌ Ошибка загрузки достижений: $e');
      print('🔧 Создаю тестовые шаблоны для демонстрации');
      _createTestTemplates();
      setState(() => _isLoading = false);
    }
  }

  // Создание тестовых шаблонов для демонстрации, если API не отвечает
  void _createTestTemplates() {
    if (_templates.isNotEmpty) {
      print('🔧 Реальные шаблоны уже загружены (${_templates.length}), тестовые не создаваем');
      return; // Если уже есть шаблоны, не создаваем тестовые
    }
    
    print('🔧 Создаю тестовые шаблоны для демонстрации');
    
    _templates = [
      // Сканирование
      AchievementTemplate(
        id: 'test_first_scan',
        name: 'Первые шаги',
        description: 'Просканируйте свое первое растение',
        iconUrl: '',
        points: 10,
        achievementType: 'scan_1',
        category: 'scan',
      ),
      AchievementTemplate(
        id: 'test_novice_scanner',
        name: 'Начинающий садовод',
        description: 'Просканируйте 5 различных растений',
        iconUrl: '',
        points: 25,
        achievementType: 'scan_5',
        category: 'scan',
      ),
      AchievementTemplate(
        id: 'test_experienced_scanner',
        name: 'Опытный ботаник',
        description: 'Просканируйте 25 растений',
        iconUrl: '',
        points: 100,
        achievementType: 'scan_25',
        category: 'scan',
      ),
      
      // Напоминания
      AchievementTemplate(
        id: 'test_first_reminder',
        name: 'Заботливый садовод',
        description: 'Создайте первое напоминание',
        iconUrl: '',
        points: 15,
        achievementType: 'reminder_1',
        category: 'reminder',
      ),
      AchievementTemplate(
        id: 'test_many_reminders',
        name: 'Организованный уход',
        description: 'Создайте 10 напоминаний',
        iconUrl: '',
        points: 50,
        achievementType: 'reminder_10',
        category: 'reminder',
      ),
      
      // Активность
      AchievementTemplate(
        id: 'test_daily_user',
        name: 'Ежедневный садовод',
        description: 'Заходите в приложение 7 дней подряд',
        iconUrl: '',
        points: 75,
        achievementType: 'daily_7',
        category: 'daily',
      ),
    ];
    
    print('🔧 Создано ${_templates.length} тестовых шаблонов');
  }

  List<AchievementTemplate> get _filteredTemplates {
    if (_selectedCategory == 'Все') {
      return _templates;
    }
    
    final categoryType = _categoryMap[_selectedCategory];
    final filtered = _templates.where((template) {
      bool matches = false;
      
      // Проверяем по новым названиям категорий
      if (_selectedCategory == 'Сканирование') {
        matches = template.category == 'Сканирование' || 
                 template.achievementType.contains('scan') ||
                 template.achievementType.contains('plant');
      } else if (_selectedCategory == 'Напоминания') {
        matches = template.category == 'Напоминания' || 
                 template.achievementType.contains('reminder') ||
                 template.achievementType.contains('care');
      } else if (_selectedCategory == 'Активность') {
        matches = template.category == 'Активность' || 
                 template.achievementType.contains('daily') ||
                 template.achievementType.contains('login');
      } else if (_selectedCategory == 'Чат с ИИ') {
        matches = template.category == 'Чат с ИИ' || 
                 template.achievementType.contains('chat') ||
                 template.achievementType.contains('ai');
      } else if (_selectedCategory == 'Избранное') {
        matches = template.category == 'Избранное' || 
                 template.achievementType.contains('favorite') ||
                 template.achievementType.contains('like');
      } else if (_selectedCategory == 'Специальное') {
        matches = template.category == 'Общие' || 
                 template.achievementType.contains('special') ||
                 template.achievementType.contains('guru');
      }
      
      return matches;
    }).toList();
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
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
              Column(
                children: [
                  // Заголовок
                  Container(
                    padding: EdgeInsets.all(16),
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
                        SizedBox(width: 16),
                        Text(
                          'Достижения',
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

                  // Основной контент с прокруткой
                  Expanded(
                    child: _isLoading 
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Color(0xFF63A36C)),
                              SizedBox(height: 16),
                              Text(
                                'Загрузка достижений...',
                                style: TextStyle(
                                  color: Color(0xFF63A36C),
                                  fontSize: 16,
                                  fontFamily: 'Gilroy',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadAchievements,
                          child: SingleChildScrollView(
                            physics: AlwaysScrollableScrollPhysics(),
                            child: Column(
                              children: [
                                // Статистика (если загружена)
                                if (_stats != null)
                                  Container(
                                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0x1931873F),
                                          blurRadius: 10,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildStatCard('Достижения', '${_stats!.totalAchievements}', '🏆'),
                                        _buildStatCard('Баллы', '${_stats!.totalPoints}', '⭐'),
                                        _buildStatCard('Прогресс', '${(_achievements.length / _templates.length * 100).toInt()}%', '📈'),
                                      ],
                                    ),
                                  ),

                                // Блок прогресса (если загружен) - СВОРАЧИВАЕМЫЙ
                                if (_userProgress != null)
                                  Container(
                                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0x1931873F),
                                          blurRadius: 10,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        // Заголовок с кнопкой сворачивания
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              _isProgressExpanded = !_isProgressExpanded;
                                            });
                                          },
                                          child: Container(
                                            padding: EdgeInsets.all(16),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.trending_up,
                                                  color: Color(0xFF63A36C),
                                                  size: 20,
                                                ),
                                                SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                          'Прогресс до следующих достижений',
                                          style: TextStyle(
                                            fontFamily: 'Gilroy',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF63A36C),
                                          ),
                                        ),
                                                ),
                                                Icon(
                                                  _isProgressExpanded 
                                                    ? Icons.keyboard_arrow_up 
                                                    : Icons.keyboard_arrow_down,
                                                  color: Color(0xFF63A36C),
                                                  size: 24,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        
                                        // Содержимое прогресса с анимацией
                                        AnimatedContainer(
                                          duration: Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                          height: _isProgressExpanded ? null : 0,
                                          child: AnimatedOpacity(
                                            duration: Duration(milliseconds: 300),
                                            opacity: _isProgressExpanded ? 1.0 : 0.0,
                                            child: _isProgressExpanded 
                                              ? Container(
                                                  padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
                                                  child: Column(
                                                    children: [
                                        _buildProgressItem('Сканирование', _userProgress!.scan, '🔍'),
                                        _buildProgressItem('Напоминания', _userProgress!.reminder, '⏰'),
                                        _buildProgressItem('Активность', _userProgress!.daily, '📅'),
                                        _buildProgressItem('Чат с ИИ', _userProgress!.chat, '💬'),
                                        _buildProgressItem('Избранное', _userProgress!.favorite, '❤️'),
                                                    ],
                                                  ),
                                                )
                                              : SizedBox.shrink(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Фильтры по категориям
                                Container(
                                  height: 60,
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: EdgeInsets.symmetric(horizontal: 16),
                                    itemCount: _categories.length,
                                    itemBuilder: (context, index) {
                                      final category = _categories[index];
                                      final isSelected = category == _selectedCategory;
                                      
                                      return Padding(
                                        padding: EdgeInsets.only(right: 8),
                                        child: FilterChip(
                                          label: Text(category),
                                          selected: isSelected,
                                          onSelected: (selected) {
                                            setState(() => _selectedCategory = category);
                                          },
                                          backgroundColor: Colors.white.withOpacity(0.7),
                                          selectedColor: Color(0xFF63A36C).withOpacity(0.3),
                                          labelStyle: TextStyle(
                                            color: isSelected ? Color(0xFF63A36C) : Color(0xFF666666),
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                                // Карточки достижений - РАЗДЕЛЕННЫЕ СЕКЦИИ
                                if (_filteredTemplates.isEmpty)
                                  Container(
                                    padding: EdgeInsets.all(40),
                                    child: Text(
                                      'Нет достижений в данной категории',
                                      style: TextStyle(
                                        color: Color(0xFF666666),
                                        fontSize: 16,
                                        fontFamily: 'Gilroy',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                else
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // СЕКЦИЯ ПОЛУЧЕННЫХ ДОСТИЖЕНИЙ
                                        ..._buildEarnedAchievementsSection(),
                                        
                                        // СЕКЦИЯ ДОСТУПНЫХ ДОСТИЖЕНИЙ
                                        ..._buildAvailableAchievementsSection(),
                                      ],
                                    ),
                                  ),

                                // Нижний отступ для закрепленного блока
                                SizedBox(height: 180),
                              ],
                            ),
                          ),
                        ),
                  ),
                ],
              ),

              // Градиентный фон для плавного перехода в UsefulInfoComponent
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 240,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(0.00, -1.00),
                      end: Alignment(0, 1),
                      colors: [
                        Color(0x00C7E6B5),
                        Color(0xFFC2E3B0),
                        Color(0xFFB7DFA5)
                      ],
                    ),
                  ),
                ),
              ),

              // Позиционируем компонент с полезной информацией
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: UsefulInfoComponent(),
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

  // НОВОЕ: Виджет для отображения прогресса отдельной категории
  Widget _buildProgressItem(String title, AchievementProgress progress, String emoji) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            emoji,
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                    ),
                    Text(
                      '${progress.current}/${progress.next}',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF63A36C),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                LinearProgressIndicator(
                  value: progress.progress,
                  backgroundColor: Color(0xFFE0E0E0),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF63A36C)),
                  minHeight: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String emoji) {
    return Column(
      children: [
        Text(
          emoji,
          style: TextStyle(fontSize: 24),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF63A36C),
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontSize: 12,
            color: Color(0xFF666666),
          ),
        ),
      ],
    );
  }

  // Секция полученных достижений
  List<Widget> _buildEarnedAchievementsSection() {
    print('🔍 ===== ПОСТРОЕНИЕ СЕКЦИИ ПОЛУЧЕННЫХ ДОСТИЖЕНИЙ =====');
    print('📊 Всего шаблонов в _filteredTemplates: ${_filteredTemplates.length}');
    print('🏆 Всего полученных достижений в _achievements: ${_achievements.length}');
    
    // Фильтруем полученные достижения
    final earnedTemplates = _filteredTemplates.where((template) {
      final hasAchievement = _achievements.any((achievement) => achievement.template?.id == template.id);
      print('   Шаблон ${template.name} (ID: ${template.id}): ${hasAchievement ? "ПОЛУЧЕН" : "не получен"}');
      return hasAchievement;
    }).toList();
    
    print('🎯 Итого найдено полученных шаблонов: ${earnedTemplates.length}');
    
    if (earnedTemplates.isEmpty) {
      print('⚠️ Нет полученных достижений для отображения');
      return [];
    }
    
    return [
      // Заголовок секции
      Container(
        margin: EdgeInsets.only(top: 16, bottom: 12),
        child: Row(
          children: [
            Icon(
              Icons.emoji_events,
              color: Color(0xFF63A36C),
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Полученные достижения (${earnedTemplates.length})',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF63A36C),
              ),
            ),
          ],
        ),
      ),
      
      // Грид с полученными достижениями
      GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.7,
        ),
        itemCount: earnedTemplates.length,
        itemBuilder: (context, index) {
          final template = earnedTemplates[index];
          final earnedAchievement = _achievements.firstWhere(
            (achievement) => achievement.template?.id == template.id
          );
          
          return _buildAchievementCard(
            context,
            template,
            true, // isEarned
            earnedAchievement,
          );
        },
      ),
      
      SizedBox(height: 24),
    ];
  }

  // Секция доступных достижений
  List<Widget> _buildAvailableAchievementsSection() {
    // Фильтруем недоступные достижения
    final availableTemplates = _filteredTemplates.where((template) {
      return !_achievements.any((achievement) => achievement.template?.id == template.id);
    }).toList();
    
    if (availableTemplates.isEmpty) {
      return [
        Container(
          padding: EdgeInsets.all(40),
          child: Text(
            'Все достижения в этой категории получены! 🎉',
            style: TextStyle(
              color: Color(0xFF63A36C),
              fontSize: 16,
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }
    
    return [
      // Заголовок секции
      Container(
        margin: EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(
              Icons.lock_outline,
              color: Color(0xFF999999),
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Доступные достижения (${availableTemplates.length})',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF999999),
              ),
            ),
          ],
        ),
      ),
      
      // Грид с доступными достижениями
      GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.7,
        ),
        itemCount: availableTemplates.length,
        itemBuilder: (context, index) {
          final template = availableTemplates[index];
          
          return _buildAchievementCard(
            context,
            template,
            false, // isEarned
            null,
          );
        },
      ),
    ];
  }

  // Получить иконку для типа достижения
  IconData _getIconForTemplate(AchievementTemplate template) {
    if (template.achievementType.contains('scan')) {
      return Icons.qr_code_scanner;
    } else if (template.achievementType.contains('reminder')) {
      return Icons.notifications_active;
    } else if (template.achievementType.contains('daily')) {
      return Icons.calendar_today;
    } else if (template.achievementType.contains('chat')) {
      return Icons.chat_bubble;
    } else if (template.achievementType.contains('favorite')) {
      return Icons.favorite;
    }
    return Icons.emoji_events;
  }

  // Получить текст требования для недоступного достижения
  String _getRequirementText(AchievementTemplate template) {
    if (template.achievementType.contains('scan_1')) {
      return 'Просканируйте первое растение';
    } else if (template.achievementType.contains('scan_5')) {
      return 'Просканируйте 5 растений';
    } else if (template.achievementType.contains('scan_25')) {
      return 'Просканируйте 25 растений';
    } else if (template.achievementType.contains('reminder_1')) {
      return 'Создайте первое напоминание';
    } else if (template.achievementType.contains('reminder_10')) {
      return 'Создайте 10 напоминаний';
    } else if (template.achievementType.contains('daily_7')) {
      return 'Заходите 7 дней подряд';
    }
    return template.description;
  }

  // Получить прогресс для шаблона достижения
  AchievementProgress? _getProgressForTemplate(AchievementTemplate template) {
    if (_userProgress == null) return null;
    
    if (template.achievementType.contains('scan')) {
      return _userProgress!.scan;
    } else if (template.achievementType.contains('reminder')) {
      return _userProgress!.reminder;
    } else if (template.achievementType.contains('daily')) {
      return _userProgress!.daily;
    } else if (template.achievementType.contains('chat')) {
      return _userProgress!.chat;
    } else if (template.achievementType.contains('favorite')) {
      return _userProgress!.favorite;
    }
    return null;
  }

  // Получить текущий прогресс для шаблона
  int? _getCurrentProgressForTemplate(AchievementTemplate template) {
    final progress = _getProgressForTemplate(template);
    return progress?.current;
  }

  // Получить требуемый прогресс для достижения
  int? _getRequiredProgressForTemplate(AchievementTemplate template) {
    if (template.achievementType.contains('scan_1')) return 1;
    if (template.achievementType.contains('scan_5')) return 5;
    if (template.achievementType.contains('scan_25')) return 25;
    if (template.achievementType.contains('reminder_1')) return 1;
    if (template.achievementType.contains('reminder_10')) return 10;
    if (template.achievementType.contains('daily_7')) return 7;
    return null;
  }

  String _formatDate(DateTime date) {
    final months = [
      'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildAchievementCard(BuildContext context, AchievementTemplate template, bool isEarned, Achievement? earnedAchievement) {
    // Получаем прогресс для этого типа достижения
    AchievementProgress? progress = _getProgressForTemplate(template);
    int? currentProgress = _getCurrentProgressForTemplate(template);
    int? requiredProgress = _getRequiredProgressForTemplate(template);
    
    return Container(
      decoration: BoxDecoration(
        gradient: isEarned 
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFF8FDF6),
              ],
            )
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF8F8F8),
                Color(0xFFE8E8E8),
              ],
            ),
        borderRadius: BorderRadius.circular(20),
        border: isEarned 
          ? Border.all(color: Color(0xFF63A36C), width: 2)
          : Border.all(color: Color(0xFFE0E0E0), width: 1),
        boxShadow: [
          BoxShadow(
            color: isEarned 
              ? Color(0xFF63A36C).withOpacity(0.2)
              : Colors.black.withOpacity(0.05),
            blurRadius: isEarned ? 15 : 8,
            offset: Offset(0, isEarned ? 6 : 3),
            spreadRadius: isEarned ? 1 : 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Основной контент
            Opacity(
              opacity: isEarned ? 1.0 : 0.6, // Делаем неполученные более тусклыми
              child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Иконка достижения
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Фоновый круг с градиентом
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          gradient: isEarned 
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF63A36C),
                                  Color(0xFF4F8A56),
                                ],
                              )
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFBDBDBD),
                                  Color(0xFF9E9E9E),
                                ],
                              ),
                          borderRadius: BorderRadius.circular(35),
                          boxShadow: [
                            BoxShadow(
                              color: isEarned 
                                ? Color(0xFF63A36C).withOpacity(0.3)
                                : Colors.grey.withOpacity(0.2),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      // Изображение из API или иконка
                      if (template.iconUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(35),
                          child: Image.network(
                              template.iconUrl.startsWith('http') 
                                ? template.iconUrl 
                                : '${ApiConfig.socketUrl}${template.iconUrl}',
                            width: 40,
                            height: 40,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              print('❌ Ошибка загрузки иконки: ${template.iconUrl}');
                                print('   Полный URL: ${template.iconUrl.startsWith('http') ? template.iconUrl : '${ApiConfig.socketUrl}${template.iconUrl}'}');
                              return Icon(
                                _getIconForTemplate(template),
                                size: 35,
                                color: Colors.white,
                              );
                            },
                          ),
                        )
                      else
                        Icon(
                          _getIconForTemplate(template),
                          size: 35,
                          color: Colors.white,
                        ),
                      
                      // Статус чекмарк для полученных достижений
                      if (isEarned)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF4CAF50).withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                    SizedBox(height: 8),
                  
                  // Название достижения
                  Text(
                    template.name,
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                        fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isEarned ? Color(0xFF1F2024) : Color(0xFF666666),
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                    SizedBox(height: 8),
                  
                  // Описание или требование
                  Text(
                    isEarned ? template.description : _getRequirementText(template),
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                        fontSize: 10,
                      color: isEarned ? Color(0xFF666666) : Color(0xFF999999),
                        height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                    // Удаляем Spacer отсюда, если он был
                    // Добавляем SizedBox для контроля вертикального пространства перед блоком "Баллы"
                    // или перед блоком "Прогресс бар", если он отображается.
                    // Цель - чтобы между описанием и следующим элементом был небольшой фиксированный отступ.
                    SizedBox(height: 8), 
                  
                  // Прогресс бар (если не получено)
                  if (!isEarned && currentProgress != null && requiredProgress != null) ...[
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Прогресс',
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontSize: 9,
                                  color: Color(0xFF888888),
                                ),
                              ),
                              Text(
                                '$currentProgress/$requiredProgress',
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF63A36C),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: Color(0xFFE0E0E0),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: requiredProgress > 0 
                                ? (currentProgress / requiredProgress).clamp(0.0, 1.0) 
                                : 0.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF63A36C),
                                      Color(0xFF7FB07C),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                  ],
                  
                  // Баллы
                  Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isEarned 
                          ? [Color(0xFF63A36C), Color(0xFF7FB07C)]
                          : [Color(0xFFE0E0E0), Color(0xFFBDBDBD)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: isEarned 
                            ? Color(0xFF63A36C).withOpacity(0.2)
                            : Colors.grey.withOpacity(0.1),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: 12,
                          color: isEarned ? Colors.white : Color(0xFF666666),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${template.points}',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isEarned ? Colors.white : Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Дата получения (если получено)
                  if (isEarned && earnedAchievement != null) ...[
                      SizedBox(height: 4),
                    Text(
                      'Получено ${_formatDate(earnedAchievement.date)}',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                          fontSize: 8,
                        color: Color(0xFF999999),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
                ),
              ),
            ),
            
            // Дополнительный эффект блокировки для неполученных достижений
            if (!isEarned)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
