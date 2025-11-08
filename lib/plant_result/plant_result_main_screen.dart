import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'set_reminder_screen.dart';
import '../models/plant_info.dart';
import '../services/api/scan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/achievement_manager.dart';
import '../scanner/scanner_screen.dart';
import '../homepage/home_screen.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

// Импорт модульных файлов
import 'plant_result_constants.dart';
import 'plant_result_widgets.dart';
import 'plant_result_dialogs.dart';
import 'plant_result_utils.dart';
import '../widgets/treatment_recommendations_widget.dart';
import '../services/api/treatment_service.dart';

class PlantResultHealthyScreen extends StatelessWidget {
  final bool isHealthy;
  final dynamic plantData; // Данные о растении, полученные от API
  final bool fromScanHistory; // Новый параметр: пришли ли из истории сканирования
  final int debugForceRebuild = DateTime.now().millisecondsSinceEpoch; // ВРЕМЕННО для форсирования rebuild
  
  // Хак для доступа к context вне build метода
  late BuildContext _context;

  // Загружаемые изображения
  String? mainImageUrl;
  String? avatarImageUrl;
  
  // Данные растения и вредителей
  // final PlantCalculationData? _calculationData = null; // Не используется

  // Флаг для контроля показа достижений на этом экране
  static bool _achievementsShown = false;

  PlantResultHealthyScreen({
    Key? key, 
    this.isHealthy = true, 
    this.plantData,
    this.fromScanHistory = false, // По умолчанию false (значит пришли после сканирования)
  }) : super(key: key) {
    print('🎯 === КОНСТРУКТОР PlantResultHealthyScreen ВЫЗВАН ===');
    print('🎯 isHealthy: $isHealthy');
    print('🎯 plantData type: ${plantData?.runtimeType}');
    
    // Извлекаем URL изображений, если они доступны
    if (plantData != null && plantData is PlantInfo) {
      final images = plantData.images;
      
      print('🎭 ==== PlantResultHealthyScreen КОНСТРУКТОР ====');
      print('📱 PlantResultHealthyScreen: plantData НЕ null');
      print('📱 PlantResultHealthyScreen: Тип plantData: ${plantData.runtimeType}');
      print('🌱 PlantResultHealthyScreen: Название растения: ${plantData.name}');
      print('💚 PlantResultHealthyScreen: Здоровое: ${plantData.isHealthy}');
      print('🆔 PlantResultHealthyScreen: ScanId: "${plantData.scanId}"');
      print('🖼️ PlantResultHealthyScreen: Доступные ключи изображений: ${images.keys.toList()}');
      
      // Логируем все изображения детально
      print('🖼️ ===== ВСЕ ИЗОБРАЖЕНИЯ В PLANTDATA =====');
      images.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          print('  ✅ $key: $value');
        } else {
          print('  ❌ $key: ПУСТОЕ/NULL');
        }
      });
      print('🖼️ ===== КОНЕЦ СПИСКА ВСЕХ ИЗОБРАЖЕНИЙ =====');
      
      // Для главного изображения используем приоритет: кроп/thumbnail -> основные
      final mainImageKeys = ['thumbnail', 'crop', 'main_image', 'user_image', 'original_image', 'scan_image', 'original', 'main'];
      print('🔍 Поиск главного изображения по приоритету: ${mainImageKeys.join(" -> ")}');
      
      for (String key in mainImageKeys) {
        if (images.containsKey(key) && images[key]!.isNotEmpty) {
          mainImageUrl = images[key];
          print('✅ PlantResultHealthyScreen: Установлен mainImageUrl ($key): $mainImageUrl');
          break;
        }
      }
      
      // Для аватара используем тот же приоритет, включая crop
      final avatarImageKeys = ['thumbnail', 'crop', 'user_image', 'original_image', 'scan_image', 'main_image'];
      print('🔍 Поиск аватара по приоритету: ${avatarImageKeys.join(" -> ")}');
      
      for (String key in avatarImageKeys) {
        if (images.containsKey(key) && images[key]!.isNotEmpty) {
          avatarImageUrl = images[key];
          print('✅ PlantResultHealthyScreen: Установлен avatarImageUrl ($key): $avatarImageUrl');
          break;
        }
      }
      
      // Проактивная проверка доступности изображений
      print('🔍 PlantResultHealthyScreen: Запускаем проверку доступности изображений...');
      PlantResultUtils.checkImageAvailability(mainImageUrl, avatarImageUrl);
      print('🎭 ==== КОНЕЦ PlantResultHealthyScreen КОНСТРУКТОР ====');
    } else {
      print('🎭 ==== PlantResultHealthyScreen КОНСТРУКТОР ====');
      print('❌ PlantResultHealthyScreen: ❗️ plantData IS NULL или не PlantInfo');
      print('📱 PlantResultHealthyScreen: Тип данных: ${plantData?.runtimeType ?? "NULL"}');
      print('🎭 ==== КОНЕЦ PlantResultHealthyScreen КОНСТРУКТОР ====');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🚨🚨🚨 BUILD МЕТОД ВЫЗВАН!!! 🚨🚨🚨');
    print('🚨 isHealthy: $isHealthy');
    print('🚨 plantData type: ${plantData?.runtimeType}');
    
    _context = context;
    
    // ОТЛАДКА: Логируем параметры при каждом build
    print('🏗️ === BUILD PlantResultHealthyScreen ===');
    print('🏗️ isHealthy параметр: $isHealthy');
    if (plantData is PlantInfo) {
      final plantInfo = plantData as PlantInfo;
      print('🏗️ PlantInfo.isHealthy: ${plantInfo.isHealthy}');
      print('🏗️ PlantInfo.name: ${plantInfo.name}');
    }
    print('🏗️ === КОНЕЦ BUILD DEBUG ===');
    
    // НОВОЕ: Проверяем достижения на экране результата (показываем полноценный попап)
    if (!_achievementsShown && plantData != null && plantData is PlantInfo) {
      _achievementsShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkResultAchievements(context);
      });
    }
    
    return Scaffold(
      appBar: null,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(0.00, -1.00),
            end: const Alignment(0, 1),
            colors: isHealthy 
                ? [plantResultWhite, plantResultLightGreenBg] 
                : [plantResultWhite, plantResultBgRed],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 90.0),
                  child: Column(
                    children: [
                      _buildHeaderSection(),
                      const SizedBox(height: 15),
                      _buildPlantNameSection(),
                      const SizedBox(height: 15),
                      _buildTagsSection(),
                      SizedBox(height: MediaQuery.of(context).size.width * 0.06),
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width * 0.05),
                        child: Column(
                          children: [
                            _buildHealthyCard(),
                            SizedBox(height: MediaQuery.of(context).size.width * 0.04),
                            _buildDescriptionCard(),
                            SizedBox(height: MediaQuery.of(context).size.width * 0.04),
                            _buildWateringCard(),
                            SizedBox(height: MediaQuery.of(context).size.width * 0.04),
                            _buildTemperatureCard(),
                            SizedBox(height: MediaQuery.of(context).size.width * 0.04),
                            _buildPestsCard(),
                            // Добавляем рекомендации препаратов для больных растений
                            // ВРЕМЕННО: показываем всегда для отладки
                            SizedBox(height: MediaQuery.of(context).size.width * 0.04),
                            if (_shouldShowTreatmentRecommendations()) ...[
                              SizedBox(height: MediaQuery.of(context).size.width * 0.04),
                              _buildTreatmentRecommendationsCard(),
                            ],
                            // ],
                          ],
                        ),
                      ),
                      SizedBox(height: MediaQuery.of(context).size.width * 0.05),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: MediaQuery.of(context).padding.bottom + 145,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00EDF6DF),
                      Color(0xFFEDF6DF),
                      Color(0xFFEDF6DF)
                    ],
                    stops: [0.0, 0.7, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomNavBar(),
            ),
          ],
        ),
      ),
    );
  }

  // --- Виджеты Секций ---

  Widget _buildHeaderSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final imageWidth = screenWidth - 44;
        final imageHeight = imageWidth * 0.7;
        final avatarSize = screenWidth * 0.25;
        final imageTop = 0.0;
        final avatarTop = imageTop + imageHeight - avatarSize / 2;
        
        // Определяем источники изображений (локальные или из API)
        Widget mainImageWidget = Image.asset(
          plantResultMainImageAsset,
          fit: BoxFit.cover,
        );
        
        Widget avatarImageWidget = Image.asset(
          plantResultAvatarAsset,
          fit: BoxFit.contain,
        );
        
        // Если у нас есть URL изображений из API, используем их
        if (mainImageUrl != null && mainImageUrl!.isNotEmpty) {
          mainImageWidget = _buildSmartNetworkImage(
            mainImageUrl!,
            BoxFit.cover,
            isMainImage: true,
          );
        }
        
        if (avatarImageUrl != null && avatarImageUrl!.isNotEmpty) {
          avatarImageWidget = _buildSmartNetworkImage(
            avatarImageUrl!,
            BoxFit.cover,
            isMainImage: false,
          );
        }

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + screenWidth * 0.04,
                left: screenWidth * 0.05,
                right: screenWidth * 0.05,
                bottom: screenWidth * 0.03,
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      // Используем умную навигацию
                      _navigateBack();
                    },
                    child: SizedBox(
                      width: screenWidth * 0.06,
                      height: screenWidth * 0.06,
                      child: SvgPicture.asset(
                        plantResultCloseIconAsset,
                        colorFilter: ColorFilter.mode(
                          isHealthy ? plantResultGreenAccent : plantResultRedAccent,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Результат сканирования',
                    style: TextStyle(
                      color: plantResultDarkText,
                      fontSize: screenWidth * 0.045,
                      fontFamily: plantResultFontFamily,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.09,
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
            SizedBox(
              height: avatarTop + avatarSize / 2,
              child: Stack(
                alignment: Alignment.topCenter,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: imageTop,
                    left: screenWidth * 0.05,
                    child: Container(
                      width: imageWidth,
                      height: imageHeight,
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: mainImageWidget,
                    ),
                  ),
                  Positioned(
                    top: avatarTop,
                    child: Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: const ShapeDecoration(
                        color: plantResultPlaceholderGrey,
                        shape: OvalBorder(),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: avatarImageWidget,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlantNameSection() {
    final screenWidth = MediaQuery.of(_context).size.width;
    
    // Определяем имя и латинское имя растения
    String plantName = 'Данные отсутствуют';
    String latinName = 'Нет данных';
    
    // Используем данные из API, если они доступны
    if (plantData != null && plantData is PlantInfo) {
      plantName = plantData.name;
      latinName = plantData.latinName;
    }

    return Padding(
      padding: EdgeInsets.only(top: screenWidth * 0.08),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$plantName\n',
              style: TextStyle(
                color: plantResultDarkText,
                fontSize: screenWidth * 0.045,
                fontFamily: plantResultFontFamily,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: latinName,
              style: TextStyle(
                color: isHealthy ? plantResultGreenAccent : plantResultRedAccent,
                fontSize: screenWidth * 0.04,
                fontStyle: FontStyle.italic,
                fontFamily: plantResultFontFamily,
                fontWeight: FontWeight.w300,
                height: 1.40,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTagsSection() {
    // Получаем теги из данных API, если они доступны
    List<String> tags = [];
    
    if (plantData != null && plantData is PlantInfo && plantData.tags.isNotEmpty) {
      tags = plantData.tags.take(3).toList(); // Берем максимум 3 тега
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22.0),
      child: tags.isEmpty 
        ? Text(
            'Теги отсутствуют',
            style: TextStyle(
              color: isHealthy ? plantResultGreenAccent : plantResultRedAccent,
              fontSize: 14,
              fontFamily: plantResultFontFamily,
              fontWeight: FontWeight.w400,
            ),
          )
        : Row(
          children: [
            for (int i = 0; i < tags.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Flexible(
                child: PlantResultTag(
                  text: tags[i],
                  textColor: tags[i].toLowerCase().contains('токсичн') 
                      ? plantResultTagToxicRed 
                      : (isHealthy ? plantResultGreenAccent : plantResultTagRed),
                  isHealthy: isHealthy,
                ),
              ),
            ]
          ],
        ),
    );
  }

  // Методы для построения карточек - упрощенные версии
  Widget _buildHealthyCard() {
    return _buildInfoCard(
      title: isHealthy ? 'Растение здорово' : 'Растение нездорово',
      description: _getHealthDescription(),
      iconAsset: plantResultPlusIconAsset,
      buttonText: 'Узнать подробнее',
      onButtonPressed: () {/* TODO */},
    );
  }

  Widget _buildDescriptionCard() {
    String plantName = '';
    String description = 'Данные отсутствуют';
    
    if (plantData != null && plantData is PlantInfo) {
      plantName = plantData.name;
      description = plantData.description.isNotEmpty ? plantData.description : 'Данные отсутствуют';
    }

    return _buildInfoCard(
      title: '',
      description: description,
      iconAsset: plantResultBookIconAsset,
      linkText: 'Открыть полное описание',
      onLinkPressed: () => PlantResultDialogs.showFullDescriptionDialog(_context, plantName, description, isHealthy),
    );
  }

  Widget _buildWateringCard() {
    return _buildInfoCard(
      title: 'Полив',
      description: _getWateringDescription(),
      iconAsset: plantResultWaterDropIconAsset,
      buttonText: 'Посчитать',
      onButtonPressed: () => PlantResultDialogs.showWateringCalculatorDialog(_context, plantData, isHealthy),
    );
  }

  Widget _buildTemperatureCard() {
    return _buildInfoCard(
      title: 'Температура',
      description: _getTemperatureDescription(),
      iconAsset: plantResultTempIconAsset,
    );
  }

  Widget _buildPestsCard() {
    return _buildInfoCard(
      title: 'Вредители и болезни',
      description: _getPestsDescription(),
      iconAsset: plantResultPestIconAsset,
      onCardTap: () => PlantResultDialogs.showPestsAndDiseasesDialog(_context, plantData, isHealthy),
    );
  }

  bool _shouldShowTreatmentRecommendations() {
    print('🤖 === ПРОВЕРКА ПОКАЗА РЕКОМЕНДАЦИЙ ИИ ===');
    print('📊 isHealthy параметр: $isHealthy');
    
    if (plantData is PlantInfo) {
      final plantInfo = plantData as PlantInfo;
      print('🌱 PlantInfo.isHealthy: ${plantInfo.isHealthy}');
      print('🌱 PlantInfo.name: ${plantInfo.name}');
      
      // Используем значение из plantData, а не из параметра конструктора
      final shouldShow = !plantInfo.isHealthy;
      print('🤖 Показывать рекомендации: $shouldShow');
      print('🤖 === КОНЕЦ ПРОВЕРКИ ===');
      return shouldShow;
    }
    
    // Fallback на параметр конструктора
    final shouldShow = !isHealthy;
    print('🤖 Fallback - показывать рекомендации: $shouldShow');
    print('🤖 === КОНЕЦ ПРОВЕРКИ ===');
    return shouldShow;
  }

  Widget _buildTreatmentRecommendationsCard() {
    print('💊 === НАЧАЛО СОЗДАНИЯ КАРТОЧКИ РЕКОМЕНДАЦИЙ ===');
    print('💊 plantData: ${plantData != null}');
    print('💊 plantData тип: ${plantData?.runtimeType}');
    
    // Проверяем здоровье растения - показываем рекомендации только для больных растений
    bool isHealthy = true;
    if (plantData is PlantInfo) {
      final plantInfo = plantData as PlantInfo;
      isHealthy = plantInfo.isHealthy;
      print('💊 PlantInfo.name: ${plantInfo.name}');
      print('💊 PlantInfo.isHealthy: ${plantInfo.isHealthy}');
      print('💊 PlantInfo.pestsAndDiseases: ${plantInfo.pestsAndDiseases.keys.toList()}');
      
      if (plantInfo.pestsAndDiseases.containsKey('common_diseases')) {
        print('💊 common_diseases: ${plantInfo.pestsAndDiseases['common_diseases']}');
      }
      if (plantInfo.pestsAndDiseases.containsKey('detected')) {
        print('💊 detected: ${plantInfo.pestsAndDiseases['detected']}');
      }
    } else if (plantData is Map) {
      isHealthy = plantData['is_healthy'] ?? true;
      print('💊 Map is_healthy: $isHealthy');
    }
    
    // Если растение здоровое, не показываем блок рекомендаций
    if (isHealthy) {
      print('💊 Растение здоровое - не показываем рекомендации');
      return SizedBox.shrink();
    }
    
    print('💊 Растение больное - показываем рекомендации');
    print('💊 Создаем TreatmentService...');
    final treatmentService = TreatmentService();
    print('💊 Вызываем extractDiseaseNames...');
    final diseases = treatmentService.extractDiseaseNames(plantData);
    
    print('💊 Найдены болезни для лечения: $diseases');
    print('💊 Количество болезней: ${diseases.length}');
    print('💊 Создаем Container...');
    
    final container = Container(
      width: MediaQuery.of(_context).size.width - 44,
      decoration: ShapeDecoration(
        color: plantResultWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        shadows: const [
          BoxShadow(
            color: plantResultShadowColor,
            blurRadius: 20,
            offset: Offset(0, 4),
            spreadRadius: 0
          )
        ],
      ),
      child: TreatmentRecommendationsWidget(
        diseases: diseases,
        maxRecommendations: 4, // Увеличиваем до 4 рекомендаций
        customTitle: 'Препараты для лечения',
        padding: EdgeInsets.all(16),
      ),
    );
    
    print('💊 Container создан');
    print('💊 === КОНЕЦ СОЗДАНИЯ КАРТОЧКИ РЕКОМЕНДАЦИЙ ===');
    return container;
  }

  Widget _buildInfoCard({
    required String title,
    required String description,
    required String iconAsset,
    String? buttonText,
    VoidCallback? onButtonPressed,
    String? linkText,
    VoidCallback? onLinkPressed,
    VoidCallback? onCardTap,
  }) {
    final screenWidth = MediaQuery.of(_context).size.width;
    final cardWidth = screenWidth - 44;
    final iconSize = screenWidth * 0.035;
    final iconBgSize = screenWidth * 0.075;

    return GestureDetector(
      onTap: onCardTap,
      child: Container(
        width: cardWidth,
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: ShapeDecoration(
          color: plantResultWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: title == (isHealthy ? 'Растение здорово' : 'Растение нездорово')
                ? BorderSide(width: 1.0, color: _iconBorderColor)
                : BorderSide.none,
          ),
          shadows: const [
            BoxShadow(
              color: plantResultShadowColor,
              blurRadius: 20,
              offset: Offset(0, 4),
              spreadRadius: 0)
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlantResultCardIconCircle(
              asset: iconAsset,
              color: _iconColor,
              bgSize: iconBgSize,
              iconSize: iconSize,
            ),
            SizedBox(width: screenWidth * 0.025),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title.isNotEmpty) ...[
                    Text(
                      title,
                      style: TextStyle(
                        color: plantResultDarkText,
                        fontSize: screenWidth * 0.04,
                        fontFamily: plantResultFontFamily,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.012),
                  ],
                  Text(
                    description,
                    style: TextStyle(
                      color: plantResultDarkText,
                      fontSize: screenWidth * 0.03,
                      fontFamily: plantResultFontFamily,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.025),
                  if (buttonText != null && onButtonPressed != null)
                    PlantResultCardButton(
                      text: buttonText,
                      onPressed: onButtonPressed,
                      borderColor: _iconBorderColor,
                    )
                  else if (linkText != null && onLinkPressed != null)
                    InkWell(
                      onTap: onLinkPressed,
                      child: Text(
                        linkText,
                        style: TextStyle(
                          color: isHealthy ? plantResultGreenAccent : plantResultTagRed,
                          fontSize: screenWidth * 0.025,
                          fontFamily: plantResultFontFamily,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (linkText == null && onCardTap != null)
              SvgPicture.asset(
                plantResultArrowRightAsset,
                width: screenWidth * 0.018,
                height: screenWidth * 0.033,
                colorFilter: ColorFilter.mode(_iconColor, BlendMode.srcIn),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final screenWidth = MediaQuery.of(_context).size.width;
    final bottomPadding = MediaQuery.of(_context).padding.bottom;
    final buttonHeight = screenWidth * 0.1 < 40 ? 40.0 : screenWidth * 0.1;

    return Container(
      padding: EdgeInsets.only(
        left: screenWidth * 0.04,
        right: screenWidth * 0.04,
        top: 10,
        bottom: bottomPadding + 10,
      ),
      decoration: const BoxDecoration(
        color: plantResultWhite,
        boxShadow: [
          BoxShadow(
              color: plantResultShadowColor,
              blurRadius: 20,
              offset: Offset(0, -4),
              spreadRadius: 0)
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: screenWidth * 0.3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                PlantResultBottomNavIcon(
                  asset: plantResultBottomShareAsset, 
                  size: screenWidth * 0.06,
                  onTap: () => _onSharePressed(),
                ),
                PlantResultFavoriteButton(
                  size: screenWidth * 0.06,
                  plantData: plantData,
                ),
                PlantResultBottomNavIcon(
                  asset: plantResultBottomCameraAsset, 
                  size: screenWidth * 0.06,
                  onTap: () => _onCameraPressed(),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            width: screenWidth * 0.45,
            height: buttonHeight,
            decoration: const ShapeDecoration(
              gradient: plantResultButtonGradient,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(30)),
              ),
              shadows: [
                BoxShadow(
                    color: plantResultShadowColor,
                    blurRadius: 20,
                    offset: Offset(0, 4),
                    spreadRadius: 0)
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onAddPlantPressed(),
                customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: FutureBuilder<bool>(
                    future: _checkIfPlantInCollection(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(plantResultWhite),
                            strokeWidth: 2,
                          ),
                        );
                      }
                      
                      bool isInCollection = snapshot.data ?? false;
                      String buttonText = isInCollection ? 'Установить напоминание' : 'Запланировать уход';
                      
                      return Text(
                        buttonText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: plantResultWhite,
                          fontSize: screenWidth * 0.038,
                          fontFamily: plantResultFontFamily,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Умная загрузка изображений
  Widget _buildSmartNetworkImage(String imageUrl, BoxFit fit, {required bool isMainImage}) {
    return FutureBuilder<bool>(
      future: PlantResultUtils.checkImageAvailabilityOnce(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return PlantResultLoadingIndicator(
            isMainImage: isMainImage,
            isHealthy: isHealthy,
          );
        }
        
        if (snapshot.hasData && snapshot.data == true) {
          return Image.network(
            imageUrl,
            fit: fit,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return PlantResultLoadingIndicator(
                isMainImage: isMainImage,
                isHealthy: isHealthy,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return PlantResultLoadingIndicator(
                isMainImage: isMainImage,
                isHealthy: isHealthy,
              );
            },
          );
        } else {
          return PlantResultLoadingIndicator(
            isMainImage: isMainImage,
            isHealthy: isHealthy,
          );
        }
      },
    );
  }

  // --- Универсальные цвета для иконок ---
  Color get _iconColor => isHealthy ? plantResultGreenAccent : plantResultRedAccent;
  Color get _iconBorderColor => isHealthy ? plantResultGreenAccent : plantResultBorderRed;

  // Вспомогательные методы получения данных
  String _getHealthDescription() {
    if (plantData != null && plantData is PlantInfo) {
      if (plantData.careInfo.containsKey('recommendations') && 
          plantData.careInfo['recommendations'] is List && 
          (plantData.careInfo['recommendations'] as List).isNotEmpty) {
        return plantData.careInfo['recommendations'][0].toString();
      }
    }
    return 'Данные о рекомендациях отсутствуют';
  }

  String _getWateringDescription() {
    if (plantData != null && plantData is PlantInfo) {
      if (plantData.careInfo.containsKey('watering') && 
          plantData.careInfo['watering'] is Map) {
        final wateringData = plantData.careInfo['watering'] as Map;
        // 1) Описание — как основной источник
        if (wateringData.containsKey('description') && 
            wateringData['description'] != null &&
            wateringData['description'].toString().isNotEmpty) {
          return wateringData['description'].toString();
        }
        // 2) Fallback: собрать кратко из automation
        if (wateringData.containsKey('automation') && wateringData['automation'] is Map) {
          final automation = wateringData['automation'] as Map;
          final interval = automation['interval_days']?.toString();
          final amount = automation['amount']?.toString();
          if (interval != null && interval.isNotEmpty) {
            var text = 'Поливать каждые $interval дней';
            if (amount != null && amount.isNotEmpty) {
              text += ', $amount';
            }
            return text;
          }
        }
      }
    }
    return 'Регулярный полив по мере высыхания почвы';
  }

  String _getTemperatureDescription() {
    if (plantData != null && plantData is PlantInfo) {
      if (plantData.growingConditions.containsKey('temperature') && 
          plantData.growingConditions['temperature'] is Map) {
        final tempData = plantData.growingConditions['temperature'] as Map<String, dynamic>;
        
        double? minTemp = PlantResultUtils.parseTemperatureNumber(tempData['optimal_min']);
        double? maxTemp = PlantResultUtils.parseTemperatureNumber(tempData['optimal_max']);
        
        if (minTemp != null && maxTemp != null) {
          return 'Оптимальная температура: ${minTemp.toInt()}°C – ${maxTemp.toInt()}°C';
        }
      }
    }
    return 'Умеренная температура 18–25°C';
  }

  String _getPestsDescription() {
    if (plantData != null && plantData is PlantInfo) {
      final plantInfo = plantData as PlantInfo;
      
      // 1) Обнаруженные проблемы (приоритетные)
      int detectedProblems = 0;
      try {
        detectedProblems = plantInfo.getDetectedProblems().length;
      } catch (_) {
        // ignore
      }
      if (plantInfo.pestsAndDiseases.containsKey('detected')) {
        final detected = plantInfo.pestsAndDiseases['detected'];
        if (detected is List) {
          detectedProblems = detectedProblems < detected.length ? detected.length : detectedProblems;
        }
      }
      if (detectedProblems > 0) {
        return 'Обнаружено проблем: $detectedProblems';
      }
      
      // 2) Возможные вредители/болезни по новой структуре
      int totalPests = 0;
      int totalDiseases = 0;
      if (plantInfo.pestsAndDiseases.containsKey('common_pests')) {
        final pests = plantInfo.pestsAndDiseases['common_pests'];
        if (pests is List) totalPests = pests.length; else if (pests is Map) totalPests = pests.keys.length;
      }
      if (plantInfo.pestsAndDiseases.containsKey('common_diseases')) {
        final diseases = plantInfo.pestsAndDiseases['common_diseases'];
        if (diseases is List) totalDiseases = diseases.length; else if (diseases is Map) totalDiseases = diseases.keys.length;
      }
      if (totalPests > 0 || totalDiseases > 0) {
        final parts = <String>[];
        if (totalPests > 0) parts.add('$totalPests возм. вредителей');
        if (totalDiseases > 0) parts.add('$totalDiseases возм. болезней');
        return parts.join(', ');
      }
      
      // 3) Обратная совместимость (старая структура)
      int oldPests = 0;
      int oldDiseases = 0;
      if (plantInfo.pestsAndDiseases.containsKey('pests') && plantInfo.pestsAndDiseases['pests'] is List) {
        oldPests = (plantInfo.pestsAndDiseases['pests'] as List).length;
      }
      if (plantInfo.pestsAndDiseases.containsKey('diseases') && plantInfo.pestsAndDiseases['diseases'] is List) {
        oldDiseases = (plantInfo.pestsAndDiseases['diseases'] as List).length;
      }
      if (oldPests + oldDiseases > 0) {
        return 'Обнаружено: $oldPests вредителей, $oldDiseases болезней';
      }
      
      return 'Вредители и болезни не обнаружены';
    }
    return 'Данные о вредителях и болезнях отсутствуют';
  }

  // Методы для работы с коллекцией
  Future<bool> _checkIfPlantInCollection() async {
    if (plantData != null && plantData is PlantInfo) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token') ?? '';
        
        if (token.isNotEmpty) {
          final scanService = ScanService();
          final plantName = plantData.name;
          final scanId = plantData.scanId; // Получаем scan_id
          
          print('🔍 PlantResultMainScreen: Проверяем растение в коллекции');
          print('🌱 Название: $plantName');
          print('🆔 ScanId: $scanId');
          
          // ИСПРАВЛЕНО: Передаем scanId для точной проверки
          final result = await scanService.isPlantInCollection(plantName, token, scanId: scanId);
          
          print('📋 Результат проверки: $result');
          return result;
        }
      } catch (e) {
        print('Ошибка при проверке коллекции: $e');
      }
    }
    return false;
  }

  void _onAddPlantPressed() async {
    bool isInCollection = await _checkIfPlantInCollection();
    
    if (isInCollection) {
      Navigator.push(
        _context,
        MaterialPageRoute(
          builder: (_) => SetReminderScreen(
            plantData: plantData,
            isPlantAlreadyInCollection: true,
            openFromWatering: false,
            fromScanHistory: fromScanHistory, // Передаем параметр из виджета
          ),
        ),
      );
    } else {
      Navigator.push(
        _context,
        MaterialPageRoute(
          builder: (_) => SetReminderScreen(
            plantData: plantData,
            isPlantAlreadyInCollection: false,
            openFromWatering: false,
            fromScanHistory: fromScanHistory, // Передаем параметр из виджета
          ),
        ),
      );
    }
  }

  // Проверка достижений на экране результата
  Future<void> _checkResultAchievements(BuildContext context) async {
    try {
      if (plantData == null || !(plantData is PlantInfo)) return;

      final plant = plantData as PlantInfo;
      String? plantName = plant.name;
      
      final achievementManager = AchievementManager();
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (context.mounted) {
        await achievementManager.checkScanAchievementsWithPopup(
          context,
          plantName: plantName,
          scanType: 'camera',
        );
      }
    } catch (e) {
      print('Ошибка при проверке достижений: $e');
    }
  }

  // Умная навигация в зависимости от контекста
  void _navigateBack() {
    if (fromScanHistory) {
      // Если пришли из истории сканирования - возвращаемся назад
      Navigator.of(_context).pop();
    } else {
      // Если пришли после сканирования - переходим на главный экран
      Navigator.of(_context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => HomeScreen(initialIndex: 0),
        ),
        (route) => false,
      );
    }
  }

  void _onCameraPressed() {
    Navigator.of(_context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ScannerScreen(),
      ),
    );
  }

  void _onSharePressed() {
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
        ScaffoldMessenger.of(_context).showSnackBar(
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
        ScaffoldMessenger.of(_context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось открыть магазин приложений'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(_context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при открытии магазина: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
} 