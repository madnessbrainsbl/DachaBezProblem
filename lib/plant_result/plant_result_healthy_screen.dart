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

class PlantResultHealthyScreen extends StatefulWidget {
  final bool isHealthy;
  final dynamic plantData; // Данные о растении, полученные от API
  final bool fromScanHistory; // Новый параметр: пришли ли из истории сканирования

  const PlantResultHealthyScreen({
    Key? key, 
    this.isHealthy = true, 
    this.plantData,
    this.fromScanHistory = false, // По умолчанию false (значит пришли после сканирования)
  }) : super(key: key);

  @override
  State<PlantResultHealthyScreen> createState() => _PlantResultHealthyScreenState();
}

class _PlantResultHealthyScreenState extends State<PlantResultHealthyScreen> {
  // Загружаемые изображения
  String? mainImageUrl;
  String? avatarImageUrl;
  
  // Данные растения и вредителей

  // Флаг для контроля показа достижений на этом экране
  static bool _achievementsShown = false;

  // НОВОЕ: Переменная для отслеживания состояния растения в коллекции
  bool? _isPlantInCollection;
  bool _isCheckingCollection = false;

  @override
  void initState() {
    super.initState();
    _initializeImages();
    _checkPlantInCollectionStatus();
  }

  void _initializeImages() {
    // Извлекаем URL изображений, если они доступны
    if (widget.plantData != null && widget.plantData is PlantInfo) {
      final images = widget.plantData.images;
      
      print('🎭 ==== PlantResultHealthyScreen ИНИЦИАЛИЗАЦИЯ ====');
      print('📱 PlantResultHealthyScreen: plantData НЕ null');
      print('📱 PlantResultHealthyScreen: Тип plantData: ${widget.plantData.runtimeType}');
      print('🌱 PlantResultHealthyScreen: Название растения: ${widget.plantData.name}');
      print('💚 PlantResultHealthyScreen: Здоровое: ${widget.plantData.isHealthy}');
      print('🆔 PlantResultHealthyScreen: ScanId: "${widget.plantData.scanId}"');
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
      
      // Приоритет изображений: сначала кроп/thumbnail, затем основные
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
      print('🎭 ==== КОНЕЦ PlantResultHealthyScreen ИНИЦИАЛИЗАЦИЯ ====');
    } else {
      print('🎭 ==== PlantResultHealthyScreen ИНИЦИАЛИЗАЦИЯ ====');
      print('❌ PlantResultHealthyScreen: ❗️ plantData IS NULL или не PlantInfo');
      print('📱 PlantResultHealthyScreen: Тип данных: ${widget.plantData?.runtimeType ?? "NULL"}');
      print('🎭 ==== КОНЕЦ PlantResultHealthyScreen ИНИЦИАЛИЗАЦИЯ ====');
    }
  }

  // НОВОЕ: Проверка статуса растения в коллекции
  Future<void> _checkPlantInCollectionStatus() async {
    if (widget.plantData != null && widget.plantData is PlantInfo) {
      setState(() {
        _isCheckingCollection = true;
      });
      
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token') ?? '';
        
        if (token.isNotEmpty) {
          final scanService = ScanService();
          final plantName = widget.plantData.name;
          final scanId = widget.plantData.scanId; // Получаем scan_id
          
          print('🔍 PlantResultHealthyScreen: Проверяем растение в коллекции');
          print('🌱 Название: $plantName');
          print('🆔 ScanId: $scanId');
          
          // ИСПРАВЛЕНО: Передаем scanId для точной проверки
          final isInCollection = await scanService.isPlantInCollection(plantName, token, scanId: scanId);
          
          print('📋 Результат проверки: $isInCollection');
          
          if (mounted) {
            setState(() {
              _isPlantInCollection = isInCollection;
              _isCheckingCollection = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isPlantInCollection = false;
              _isCheckingCollection = false;
            });
          }
        }
      } catch (e) {
        print('Ошибка при проверке коллекции: $e');
        if (mounted) {
          setState(() {
            _isPlantInCollection = false;
            _isCheckingCollection = false;
          });
        }
      }
    }
  }

  // НОВОЕ: Callback для обновления состояния при изменении лайка
  void _onFavoriteToggled() {
    print('🔄 PlantResultHealthyScreen: Лайк изменен, обновляем статус коллекции');
    _checkPlantInCollectionStatus();
  }

  @override
  Widget build(BuildContext context) {
    // НОВОЕ: Проверяем достижения на экране результата (показываем полноценный попап)
    if (!_achievementsShown && widget.plantData != null && widget.plantData is PlantInfo) {
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
            colors: widget.isHealthy 
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
                            _buildWateringCard(),
                            SizedBox(height: MediaQuery.of(context).size.width * 0.04),
                            _buildTemperatureCard(),
                            SizedBox(height: MediaQuery.of(context).size.width * 0.04),
                            _buildPestsCard(),
                            // Добавляем рекомендации препаратов для больных растений
                            if (_shouldShowTreatmentRecommendations()) ...[
                              SizedBox(height: MediaQuery.of(context).size.width * 0.04),
                              _buildTreatmentRecommendationsCard(),
                            ],
                            SizedBox(height: MediaQuery.of(context).size.width * 0.04),
                            _buildLightingCard(),
                            SizedBox(height: MediaQuery.of(context).size.width * 0.04),
                            _buildHumidityCard(),
                            SizedBox(height: MediaQuery.of(context).size.width * 0.04),
                            _buildFertilizingCard(),
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
                          widget.isHealthy ? plantResultGreenAccent : plantResultRedAccent,
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
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Определяем имя и латинское имя растения
    String plantName = 'Данные отсутствуют';
    String latinName = 'Нет данных';
    
    // Используем данные из API, если они доступны
    if (widget.plantData != null && widget.plantData is PlantInfo) {
      plantName = widget.plantData.name;
      latinName = widget.plantData.latinName;
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
                color: widget.isHealthy ? plantResultGreenAccent : plantResultRedAccent,
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
    
    if (widget.plantData != null && widget.plantData is PlantInfo && widget.plantData.tags.isNotEmpty) {
      tags = widget.plantData.tags.take(3).toList(); // Берем максимум 3 тега
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22.0),
      child: tags.isEmpty 
        ? Text(
            'Теги отсутствуют',
            style: TextStyle(
              color: widget.isHealthy ? plantResultGreenAccent : plantResultRedAccent,
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
                      : (widget.isHealthy ? plantResultGreenAccent : plantResultTagRed),
                  isHealthy: widget.isHealthy,
                ),
              ),
            ]
          ],
        ),
    );
  }

  // Методы для построения карточек - ОБНОВЛЕННЫЕ
  Widget _buildHealthyCard() {
    return _buildInfoCard(
      title: widget.isHealthy ? 'Растение здорово' : 'Растение нездорово',
      description: _getHealthDescription(),
      iconAsset: plantResultPlusIconAsset,
      buttonText: 'Узнать подробнее',
      onButtonPressed: () => _showHealthDetailsDialog(),
    );
  }

  Widget _buildWateringCard() {
    return _buildInfoCard(
      title: 'Полив',
      description: _getWateringDescription(),
      iconAsset: plantResultWaterDropIconAsset,
      onCardTap: () => _showWateringDetailsDialog(),
    );
  }

  Widget _buildTemperatureCard() {
    return _buildInfoCard(
      title: 'Температура',
      description: _getTemperatureDescription(),
      iconAsset: plantResultTempIconAsset,
      onCardTap: () => _showTemperatureDetailsDialog(),
    );
  }

  Widget _buildPestsCard() {
    return _buildInfoCard(
      title: 'Вредители и болезни',
      description: _getPestsDescription(),
      iconAsset: plantResultPestIconAsset,
      onCardTap: () => _showPestsDetailsDialog(),
    );
  }

  // НОВЫЕ карточки с данными из бэкенда
  Widget _buildLightingCard() {
    return _buildInfoCard(
      title: 'Освещение',
      description: _getLightingDescription(),
      iconAsset: plantResultPlusIconAsset, // Заменить на иконку света
      onCardTap: () => _showLightingDetailsDialog(),
    );
  }

  Widget _buildHumidityCard() {
    return _buildInfoCard(
      title: 'Влажность',
      description: _getHumidityDescription(),
      iconAsset: plantResultWaterDropIconAsset, // Заменить на иконку влажности
      onCardTap: () => _showHumidityDetailsDialog(),
    );
  }

  Widget _buildFertilizingCard() {
    return _buildInfoCard(
      title: 'Удобрения',
      description: _getFertilizingDescription(),
      iconAsset: plantResultPlusIconAsset, // Заменить на иконку удобрений
      onCardTap: () => _showFertilizingDetailsDialog(),
    );
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
    final screenWidth = MediaQuery.of(context).size.width;
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
            side: title == (widget.isHealthy ? 'Растение здорово' : 'Растение нездорово')
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
                          color: widget.isHealthy ? plantResultGreenAccent : plantResultTagRed,
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
              PlantResultClickableArrow(
                screenWidth: screenWidth,
                iconColor: _iconColor,
                onTap: onCardTap,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
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
                  plantData: widget.plantData,
                  isInCollection: _isPlantInCollection,
                  onFavoriteToggled: _onFavoriteToggled,
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
                    child: _isCheckingCollection
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(plantResultWhite),
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            (_isPlantInCollection ?? false) ? 'Запланировать уход' : 'Запланировать уход',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: plantResultWhite,
                              fontSize: screenWidth * 0.038,
                              fontFamily: plantResultFontFamily,
                              fontWeight: FontWeight.w600,
                            ),
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
            isHealthy: widget.isHealthy,
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
                isHealthy: widget.isHealthy,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return PlantResultLoadingIndicator(
                isMainImage: isMainImage,
                isHealthy: widget.isHealthy,
              );
            },
          );
        } else {
          return PlantResultLoadingIndicator(
            isMainImage: isMainImage,
            isHealthy: widget.isHealthy,
          );
        }
      },
    );
  }

  // --- Универсальные цвета для иконок ---
  Color get _iconColor => widget.isHealthy ? plantResultGreenAccent : plantResultRedAccent;
  Color get _iconBorderColor => widget.isHealthy ? plantResultGreenAccent : plantResultBorderRed;

  // Вспомогательные методы получения данных
  String _getHealthDescription() {
    if (widget.plantData == null) return 'Нет данных о здоровье растения';
    
    try {
      final plantInfo = widget.plantData as PlantInfo;
      
      if (widget.isHealthy) {
        // Для здоровых растений - краткое позитивное сообщение
        return 'Растение выглядит здоровым и не требует срочного вмешательства.';
      } else {
        // Для больных растений ищем рекомендации
        String description = 'Обнаружены проблемы, требующие внимания.';
        
        // Ищем рекомендации в разных местах
        if (plantInfo.careInfo.containsKey('recommendations') && 
            plantInfo.careInfo['recommendations'] != null) {
          final recommendations = plantInfo.careInfo['recommendations'];
          if (recommendations is List && recommendations.isNotEmpty) {
            description = _truncateText(recommendations[0].toString(), 100);
          } else if (recommendations is String && recommendations.isNotEmpty) {
            description = _truncateText(recommendations, 100);
          }
        }
        
        // Альтернативно ищем в pest_control или disease_treatment
        if (description == 'Обнаружены проблемы, требующие внимания.') {
          if (plantInfo.careInfo.containsKey('disease_treatment') && 
              plantInfo.careInfo['disease_treatment'] != null) {
            final treatment = plantInfo.careInfo['disease_treatment'];
            if (treatment is Map && treatment.containsKey('description')) {
              description = _truncateText(treatment['description'].toString(), 100);
            }
          }
        }
        
        return description;
      }
    } catch (e) {
      print('❌ Ошибка получения описания здоровья: $e');
      return 'Не удалось получить информацию о здоровье растения';
    }
  }

  // Обрезка текста до нужной длины
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    
    // Ищем последний пробел в пределах лимита
    int cutIndex = maxLength;
    int lastSpace = text.lastIndexOf(' ', maxLength);
    if (lastSpace > maxLength * 0.7) {
      cutIndex = lastSpace;
    }
    
    return '${text.substring(0, cutIndex)}...';
  }

  // Получение описания полива  
  String _getWateringDescription() {
    if (widget.plantData == null) return 'Поливайте по мере необходимости';
    
    try {
      final plantInfo = widget.plantData as PlantInfo;
      
      if (plantInfo.careInfo.containsKey('watering') && 
          plantInfo.careInfo['watering'] is Map) {
        final wateringData = plantInfo.careInfo['watering'] as Map;
        
        if (wateringData.containsKey('description') && 
            wateringData['description'] != null &&
            wateringData['description'].toString().isNotEmpty) {
          return _truncateText(wateringData['description'].toString(), 80);
        }
        
        // Если описания нет, составляем из automation данных
        if (wateringData.containsKey('automation') && 
            wateringData['automation'] is Map) {
          final automation = wateringData['automation'] as Map;
          String interval = automation['interval_days']?.toString() ?? 'регулярно';
          String amount = automation['amount']?.toString() ?? '';
          
          String description = 'Поливать каждые $interval дней';
          if (amount.isNotEmpty) {
            description += ', $amount';
          }
          return description;
        }
      }
      
      return 'Регулярный полив по мере высыхания почвы';
    } catch (e) {
      print('❌ Ошибка получения описания полива: $e');
      return 'Поливайте по мере необходимости';
    }
  }

  // Получение описания температуры
  String _getTemperatureDescription() {
    if (widget.plantData == null) return 'Комнатная температура';
    
    try {
      final plantInfo = widget.plantData as PlantInfo;
      
      if (plantInfo.growingConditions.containsKey('temperature') && 
          plantInfo.growingConditions['temperature'] is Map) {
        final tempData = plantInfo.growingConditions['temperature'] as Map;
        
        // 1) Каноничный источник: оптимальный диапазон
        final double? optimalMin = PlantResultUtils.parseTemperatureNumber(tempData['optimal_min']);
        final double? optimalMax = PlantResultUtils.parseTemperatureNumber(tempData['optimal_max']);
        if (optimalMin != null && optimalMax != null) {
          return 'Оптимальная температура: ${optimalMin.toInt()}°C – ${optimalMax.toInt()}°C';
        }
        
        // 2) Текстовое описание (если когда-либо будет)
        if (tempData.containsKey('description') && tempData['description'] != null) {
          final desc = tempData['description'].toString();
          if (desc.isNotEmpty) {
            return _truncateText(desc, 80);
          }
        }
        
        // 3) Fallback: используем крайние допустимые пределы как приблизительный ориентир
        if (tempData.containsKey('min') && tempData.containsKey('max')) {
          return 'Оптимальная температура: ${tempData['min']}°C - ${tempData['max']}°C';
        }
      }
      
      // 4) Общий фолбэк
      return 'Умеренная температура 18-25°C';
    } catch (e) {
      print('❌ Ошибка получения описания температуры: $e');
      return 'Комнатная температура';
    }
  }

  // ИСПРАВЛЕННОЕ получение описания вредителей и болезней
  String _getPestsDescription() {
    if (widget.plantData == null) return 'Вредители и болезни не обнаружены';
    
    try {
      final plantInfo = widget.plantData as PlantInfo;
      print('🐛 === ИСПРАВЛЕННЫЙ АНАЛИЗ ВРЕДИТЕЛЕЙ И БОЛЕЗНЕЙ ===');
      
      if (!plantInfo.pestsAndDiseases.containsKey('common_pests') && 
          !plantInfo.pestsAndDiseases.containsKey('common_diseases') &&
          !plantInfo.pestsAndDiseases.containsKey('detected')) {
        print('❌ Нет данных о вредителях и болезнях');
        return 'Вредители и болезни не обнаружены';
      }
      
      int totalPests = 0;
      int totalDiseases = 0;
      int detectedProblems = 0;
      
      // Считаем common_pests
      if (plantInfo.pestsAndDiseases.containsKey('common_pests')) {
        final pests = plantInfo.pestsAndDiseases['common_pests'];
        if (pests is List) {
          totalPests = pests.length;
          print('🐛 common_pests найдено: $totalPests');
        } else if (pests is Map) {
          totalPests = pests.keys.length;
          print('🐛 common_pests (Map) найдено: $totalPests');
        }
      }
      
      // Считаем common_diseases  
      if (plantInfo.pestsAndDiseases.containsKey('common_diseases')) {
        final diseases = plantInfo.pestsAndDiseases['common_diseases'];
        if (diseases is List) {
          totalDiseases = diseases.length;
          print('🦠 common_diseases найдено: $totalDiseases');
        } else if (diseases is Map) {
          totalDiseases = diseases.keys.length;
          print('🦠 common_diseases (Map) найдено: $totalDiseases');
        }
      }
      
      // Считаем detected проблемы
      if (plantInfo.pestsAndDiseases.containsKey('detected')) {
        final detected = plantInfo.pestsAndDiseases['detected'];
        if (detected is List) {
          detectedProblems = detected.length;
          print('⚠️ detected проблем: $detectedProblems');
        }
      }
      
      print('📊 Итого: $totalPests вредителей, $totalDiseases болезней, $detectedProblems обнаруженных');
      print('🐛 === КОНЕЦ ИСПРАВЛЕННОГО АНАЛИЗА ===');
      
      // Если есть обнаруженные проблемы - приоритет им
      if (detectedProblems > 0) {
        return 'Обнаружено проблем: $detectedProblems';
      }
      
      // Если есть потенциальные проблемы
      if (totalPests > 0 || totalDiseases > 0) {
        List<String> parts = [];
        if (totalPests > 0) parts.add('$totalPests возм. вредителей');
        if (totalDiseases > 0) parts.add('$totalDiseases возм. болезней');
        return parts.join(', ');
      }
      
      return 'Вредители и болезни не обнаружены';
    } catch (e) {
      print('❌ Ошибка анализа вредителей: $e');
      return 'Ошибка анализа вредителей и болезней';
    }
  }

  // Получение описания освещения
  String _getLightingDescription() {
    if (widget.plantData == null) return 'Яркий рассеянный свет';
    
    try {
      final plantInfo = widget.plantData as PlantInfo;
      
      if (plantInfo.growingConditions.containsKey('lighting') && 
          plantInfo.growingConditions['lighting'] is Map) {
        final lightData = plantInfo.growingConditions['lighting'] as Map;
        
        if (lightData.containsKey('description')) {
          return _truncateText(lightData['description'].toString(), 80);
        }
        
        if (lightData.containsKey('requirement')) {
          return lightData['requirement'].toString();
        }
      }
      
      return 'Яркий рассеянный свет';
    } catch (e) {
      return 'Яркий рассеянный свет';
    }
  }

  // Получение описания влажности
  String _getHumidityDescription() {
    if (widget.plantData == null) return 'Умеренная влажность';
    
    try {
      final plantInfo = widget.plantData as PlantInfo;
      
      if (plantInfo.growingConditions.containsKey('humidity') && 
          plantInfo.growingConditions['humidity'] is Map) {
        final humidityData = plantInfo.growingConditions['humidity'] as Map;
        
        if (humidityData.containsKey('description')) {
          return _truncateText(humidityData['description'].toString(), 80);
        }
        
        if (humidityData.containsKey('optimal_range')) {
          return 'Влажность: ${humidityData['optimal_range']}%';
        }
      }
      
      return 'Умеренная влажность 40-60%';
    } catch (e) {
      return 'Умеренная влажность';
    }
  }

  // Получение описания удобрений
  String _getFertilizingDescription() {
    if (widget.plantData == null) return 'Удобрение в период роста';
    
    try {
      final plantInfo = widget.plantData as PlantInfo;
      
      if (plantInfo.careInfo.containsKey('fertilizing') && 
          plantInfo.careInfo['fertilizing'] is Map) {
        final fertData = plantInfo.careInfo['fertilizing'] as Map;
        
        if (fertData.containsKey('description')) {
          return _truncateText(fertData['description'].toString(), 80);
        }
        
        // Составляем из automation данных
        if (fertData.containsKey('automation') && 
            fertData['automation'] is Map) {
          final automation = fertData['automation'] as Map;
          String interval = automation['interval_days']?.toString() ?? '';
          String type = automation['fertilizer_type']?.toString() ?? '';
          
          if (interval.isNotEmpty && type.isNotEmpty) {
            return 'Удобрение $type каждые $interval дней';
          }
        }
      }
      
      return 'Удобрение в период активного роста';
    } catch (e) {
      return 'Удобрение в период роста';
    }
  }

  // Методы для работы с коллекцией

  void _onAddPlantPressed() async {
    // Используем кэшированное состояние вместо повторного запроса
    bool isInCollection = _isPlantInCollection ?? false;
    
    if (isInCollection) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SetReminderScreen(
            plantData: widget.plantData,
            isPlantAlreadyInCollection: true,
            openFromWatering: false,
            fromScanHistory: widget.fromScanHistory, // Передаем параметр из виджета
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SetReminderScreen(
            plantData: widget.plantData,
            isPlantAlreadyInCollection: false,
            openFromWatering: false,
            fromScanHistory: widget.fromScanHistory, // Передаем параметр из виджета
          ),
        ),
      );
    }
  }

  // Проверка достижений на экране результата
  Future<void> _checkResultAchievements(BuildContext context) async {
    try {
      if (widget.plantData == null || !(widget.plantData is PlantInfo)) return;

      final plant = widget.plantData as PlantInfo;
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
    if (widget.fromScanHistory) {
      // Если пришли из истории сканирования - возвращаемся назад
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

  // Новые методы для диалогов
  void _showHealthDetailsDialog() {
    final title = widget.isHealthy ? 'Растение здорово' : 'Рекомендации по уходу';
    final content = _getFullHealthDescription();
    PlantResultDialogs.showHealthDetailsDialog(context, title, content, widget.isHealthy);
  }

  void _showWateringDetailsDialog() {
    final wateringInfo = _getFullWateringDescription();
    PlantResultDialogs.showWateringDetailsDialog(context, wateringInfo, widget.isHealthy);
  }

  void _showTemperatureDetailsDialog() {
    final temperatureInfo = PlantResultUtils.getTemperatureDetails(widget.plantData);
    PlantResultDialogs.showTemperatureDetailsDialog(context, temperatureInfo, widget.isHealthy);
  }

  void _showPestsDetailsDialog() {
    PlantResultDialogs.showPestsAndDiseasesDialog(context, widget.plantData, widget.isHealthy);
  }

  void _showLightingDetailsDialog() {
    final lightingInfo = _getFullLightingDescription();
    PlantResultDialogs.showLightingDetailsDialog(context, lightingInfo, widget.isHealthy);
  }

  void _showHumidityDetailsDialog() {
    final humidityInfo = _getFullHumidityDescription();
    PlantResultDialogs.showHumidityDetailsDialog(context, humidityInfo, widget.isHealthy);
  }

  void _showFertilizingDetailsDialog() {
    final fertilizingInfo = _getFullFertilizingDescription();
    PlantResultDialogs.showFertilizingDetailsDialog(context, fertilizingInfo, widget.isHealthy);
  }

  void _onCameraPressed() {
    Navigator.of(context).pushReplacement(
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
            duration: const Duration(seconds: 2),
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

  // НОВЫЕ методы для получения ПОЛНОЙ информации для диалогов
  String _getFullHealthDescription() {
    if (widget.plantData == null) return 'Нет данных о здоровье растения';
    
    try {
      final plantInfo = widget.plantData as PlantInfo;
      
      if (widget.isHealthy) {
        // Для здоровых растений - подробное описание ухода
        String fullDescription = 'Растение выглядит здоровым и не требует срочного вмешательства.\n\n';
        
        // Добавляем общие рекомендации по уходу
        if (plantInfo.description.isNotEmpty) {
          fullDescription += '📝 Общее описание:\n${plantInfo.description}\n\n';
        }
        
        // Добавляем рекомендации по уходу
        if (plantInfo.careInfo.containsKey('general')) {
          fullDescription += '🌿 Рекомендации по уходу:\n${plantInfo.careInfo['general']}\n\n';
        }
        
        return fullDescription;
      } else {
        // Для больных растений - все доступные рекомендации
        String fullDescription = '';
        
        // Ищем рекомендации в разных местах
        if (plantInfo.careInfo.containsKey('recommendations') && 
            plantInfo.careInfo['recommendations'] != null) {
          final recommendations = plantInfo.careInfo['recommendations'];
          if (recommendations is List && recommendations.isNotEmpty) {
            fullDescription += '📋 Рекомендации:\n${recommendations.join('\n\n')}\n\n';
          } else if (recommendations is String && recommendations.isNotEmpty) {
            fullDescription += '📋 Рекомендации:\n$recommendations\n\n';
          }
        }
        
        // Лечение болезней
        if (plantInfo.careInfo.containsKey('disease_treatment') && 
            plantInfo.careInfo['disease_treatment'] != null) {
          final treatment = plantInfo.careInfo['disease_treatment'];
          if (treatment is Map && treatment.containsKey('description')) {
            fullDescription += '💊 Лечение болезней:\n${treatment['description']}\n\n';
          }
        }
        
        // Борьба с вредителями
        if (plantInfo.careInfo.containsKey('pest_control') && 
            plantInfo.careInfo['pest_control'] != null) {
          final pestControl = plantInfo.careInfo['pest_control'];
          if (pestControl is Map && pestControl.containsKey('description')) {
            fullDescription += '🐛 Борьба с вредителями:\n${pestControl['description']}\n\n';
          }
        }
        
        if (fullDescription.isEmpty) {
          fullDescription = 'Обнаружены проблемы, требующие внимания. Рекомендуется обратиться к специалисту для получения детальных рекомендаций по лечению.';
        }
        
        return fullDescription.trim();
      }
    } catch (e) {
      print('❌ Ошибка получения полного описания здоровья: $e');
      return 'Не удалось получить информацию о здоровье растения';
    }
  }

  String _getFullWateringDescription() {
    if (widget.plantData == null) return 'Общие рекомендации по поливу';
    
    try {
      final plantInfo = widget.plantData as PlantInfo;
      String fullDescription = '';
      
      if (plantInfo.careInfo.containsKey('watering') && 
          plantInfo.careInfo['watering'] is Map) {
        final wateringData = plantInfo.careInfo['watering'] as Map;
        
        // Основное описание
        if (wateringData.containsKey('description') && 
            wateringData['description'] != null) {
          fullDescription += '💧 Основные правила полива:\n${wateringData['description']}\n\n';
        }
        
        // Automation данные
        if (wateringData.containsKey('automation') && 
            wateringData['automation'] is Map) {
          final automation = wateringData['automation'] as Map;
          fullDescription += '🤖 Автоматизированный уход:\n';
          if (automation['interval_days'] != null) {
            fullDescription += '• Частота: каждые ${automation['interval_days']} дней\n';
          }
          if (automation['time_of_day'] != null) {
            fullDescription += '• Время: ${_translateValue(automation['time_of_day'])}\n';
          }
          if (automation['amount'] != null) {
            fullDescription += '• Количество: ${automation['amount']}\n';
          }
          if (automation['water_type'] != null) {
            fullDescription += '• Тип воды: ${automation['water_type']}\n';
          }
          fullDescription += '\n';
        }
        
        // Сезонные корректировки
        if (wateringData.containsKey('seasonal_adjustments') && 
            wateringData['seasonal_adjustments'] is Map) {
          final seasonal = wateringData['seasonal_adjustments'] as Map;
          fullDescription += '🌤️ Сезонные особенности:\n';
          seasonal.forEach((season, adjustment) {
            if (adjustment != null && adjustment.toString().isNotEmpty) {
              fullDescription += '• ${_translateValue(season.toString()).toUpperCase()}: $adjustment\n';
            }
          });
        }
      }
      
      if (fullDescription.isEmpty) {
        return 'Поливайте растение регулярно, контролируя влажность почвы. Избегайте пересыхания и переувлажнения.';
      }
      
      return fullDescription.trim();
    } catch (e) {
      print('❌ Ошибка получения полного описания полива: $e');
      return 'Общие рекомендации по поливу';
    }
  }

  // Функция для перевода значений на русский язык
  String _translateValue(dynamic value) {
    if (value == null) return 'Не указано';
    
    // Словарь переводов
    const Map<String, String> translations = {
      // Время суток
      'morning': 'утром',
      'afternoon': 'днем', 
      'evening': 'вечером',
      'any': 'в любое время',
      
      // Сезоны
      'spring': 'весна',
      'summer': 'лето',
      'autumn': 'осень',
      'winter': 'зима',
    };
    
    String stringValue = value.toString().toLowerCase();
    return translations[stringValue] ?? value.toString();
  }

  String _getFullLightingDescription() {
    if (widget.plantData == null) return 'Общие рекомендации по освещению';
    
    try {
      final plantInfo = widget.plantData as PlantInfo;
      String fullDescription = '';
      
      if (plantInfo.growingConditions.containsKey('lighting') && 
          plantInfo.growingConditions['lighting'] is Map) {
        final lightData = plantInfo.growingConditions['lighting'] as Map;
        
        if (lightData.containsKey('description') && lightData['description'] != null) {
          fullDescription += '☀️ Требования к освещению:\n${lightData['description']}\n\n';
        }
        
        if (lightData.containsKey('requirement') && lightData['requirement'] != null) {
          fullDescription += '💡 Тип освещения: ${lightData['requirement']}\n\n';
        }
        
        if (lightData.containsKey('hours_per_day') && lightData['hours_per_day'] != null) {
          fullDescription += '⏰ Продолжительность: ${lightData['hours_per_day']} часов в день\n\n';
        }
        
        if (lightData.containsKey('direction') && lightData['direction'] != null) {
          fullDescription += '🧭 Направление: ${lightData['direction']}\n\n';
        }
      }
      
      if (fullDescription.isEmpty) {
        return 'Большинство растений предпочитают яркий рассеянный свет. Избегайте прямых солнечных лучей, которые могут вызвать ожоги листьев.';
      }
      
      return fullDescription.trim();
    } catch (e) {
      print('❌ Ошибка получения описания освещения: $e');
      return 'Общие рекомендации по освещению';
    }
  }

  String _getFullHumidityDescription() {
    if (widget.plantData == null) return 'Общие рекомендации по влажности';
    
    try {
      final plantInfo = widget.plantData as PlantInfo;
      String fullDescription = '';
      
      if (plantInfo.growingConditions.containsKey('humidity') && 
          plantInfo.growingConditions['humidity'] is Map) {
        final humidityData = plantInfo.growingConditions['humidity'] as Map;
        
        if (humidityData.containsKey('description') && humidityData['description'] != null) {
          fullDescription += '💨 Требования к влажности:\n${humidityData['description']}\n\n';
        }
        
        if (humidityData.containsKey('optimal_range') && humidityData['optimal_range'] != null) {
          fullDescription += '📊 Оптимальный диапазон: ${humidityData['optimal_range']}%\n\n';
        }
        
        if (humidityData.containsKey('methods') && humidityData['methods'] != null) {
          fullDescription += '🛠️ Способы поддержания:\n${humidityData['methods']}\n\n';
        }
      }
      
      if (fullDescription.isEmpty) {
        return 'Поддерживайте влажность воздуха 40-60%. Используйте увлажнитель, поддон с водой или опрыскивание (если растение это переносит).';
      }
      
      return fullDescription.trim();
    } catch (e) {
      print('❌ Ошибка получения описания влажности: $e');
      return 'Общие рекомендации по влажности';
    }
  }

  String _getFullFertilizingDescription() {
    if (widget.plantData == null) return 'Общие рекомендации по удобрениям';
    
    try {
      final plantInfo = widget.plantData as PlantInfo;
      String fullDescription = '';
      
      if (plantInfo.careInfo.containsKey('fertilizing') && 
          plantInfo.careInfo['fertilizing'] is Map) {
        final fertData = plantInfo.careInfo['fertilizing'] as Map;
        
        if (fertData.containsKey('description') && fertData['description'] != null) {
          fullDescription += '🌱 Рекомендации по подкормке:\n${fertData['description']}\n\n';
        }
        
        // Automation данные
        if (fertData.containsKey('automation') && 
            fertData['automation'] is Map) {
          final automation = fertData['automation'] as Map;
          fullDescription += '🤖 Автоматизированное удобрение:\n';
          if (automation['interval_days'] != null) {
            fullDescription += '• Частота: каждые ${automation['interval_days']} дней\n';
          }
          if (automation['fertilizer_type'] != null) {
            fullDescription += '• Тип удобрения: ${automation['fertilizer_type']}\n';
          }
          if (automation['concentration'] != null) {
            fullDescription += '• Концентрация: ${automation['concentration']}\n';
          }
          if (automation['time_of_day'] != null) {
            fullDescription += '• Время внесения: ${automation['time_of_day']}\n';
          }
          fullDescription += '\n';
        }
        
        // Сезонные особенности
        if (fertData.containsKey('seasonal_adjustments') && 
            fertData['seasonal_adjustments'] is Map) {
          final seasonal = fertData['seasonal_adjustments'] as Map;
          fullDescription += '🌤️ Сезонные особенности:\n';
          seasonal.forEach((season, adjustment) {
            if (adjustment != null && adjustment.toString().isNotEmpty) {
              fullDescription += '• ${season.toString().toUpperCase()}: $adjustment\n';
            }
          });
        }
      }
      
      if (fullDescription.isEmpty) {
        return 'Подкармливайте растение в период активного роста (весна-лето) раз в 2-4 недели комплексным удобрением. Зимой подкормки сократите или прекратите.';
      }
      
      return fullDescription.trim();
    } catch (e) {
      print('❌ Ошибка получения описания удобрений: $e');
      return 'Общие рекомендации по удобрениям';
    }
  }

  // Проверка, нужно ли показывать рекомендации препаратов
  bool _shouldShowTreatmentRecommendations() {
    print('🤖 === ПРОВЕРКА ПОКАЗА РЕКОМЕНДАЦИЙ ИИ ===');
    print('📊 isHealthy параметр: ${widget.isHealthy}');
    
    if (widget.plantData is PlantInfo) {
      final plantInfo = widget.plantData as PlantInfo;
      print('🌱 PlantInfo.isHealthy: ${plantInfo.isHealthy}');
      print('🌱 PlantInfo.name: ${plantInfo.name}');
      
      // Используем значение из plantData, а не из параметра конструктора
      final shouldShow = !plantInfo.isHealthy;
      print('🤖 Показывать рекомендации: $shouldShow');
      print('🤖 === КОНЕЦ ПРОВЕРКИ ===');
      return shouldShow;
    }
    
    // Fallback на параметр конструктора
    final shouldShow = !widget.isHealthy;
    print('🤖 Fallback - показывать рекомендации: $shouldShow');
    print('🤖 === КОНЕЦ ПРОВЕРКИ ===');
    return shouldShow;
  }

  // Построение карточки с рекомендациями препаратов
  Widget _buildTreatmentRecommendationsCard() {
    print('💊 === СОЗДАНИЕ КАРТОЧКИ РЕКОМЕНДАЦИЙ ===');
    print('💊 plantData: ${widget.plantData != null}');
    print('💊 plantData тип: ${widget.plantData?.runtimeType}');
    
    // Проверяем здоровье растения - показываем рекомендации только для больных растений
    bool isHealthy = true;
    if (widget.plantData is PlantInfo) {
      final plantInfo = widget.plantData as PlantInfo;
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
    } else if (widget.plantData is Map) {
      isHealthy = widget.plantData['is_healthy'] ?? true;
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
    final diseases = treatmentService.extractDiseaseNames(widget.plantData);
    
    print('💊 Найдены болезни для лечения: $diseases');
    print('💊 Количество болезней: ${diseases.length}');
    print('💊 Создаем Container...');
    
    final container = Container(
      width: MediaQuery.of(context).size.width - 44,
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
}