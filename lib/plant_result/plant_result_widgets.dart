import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'plant_result_constants.dart';
import '../widgets/favorite_button.dart';
import '../models/plant_info.dart';

// Универсальный виджет для иконок карточек (кроме плюсика и температуры)
class PlantResultCardIconCircle extends StatelessWidget {
  final String asset;
  final Color color;
  final double bgSize;
  final double iconSize;
  
  const PlantResultCardIconCircle({
    Key? key,
    required this.asset,
    required this.color,
    required this.bgSize,
    required this.iconSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double targetSize = iconSize;
    final double pad = (bgSize - targetSize) / 2;

    return Container(
      width: bgSize,
      height: bgSize,
      padding: EdgeInsets.all(pad),
      decoration: const BoxDecoration(
        color: Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: SvgPicture.asset(
        asset,
        width: targetSize,
        height: targetSize,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}

// Виджет кнопки для карточек
class PlantResultCardButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color borderColor;

  const PlantResultCardButton({
    Key? key,
    required this.text,
    required this.onPressed,
    required this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 146, // Ширина из жесткого кода
      height: 27, // Высота из жесткого кода
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(width: 1.50, color: borderColor),
          borderRadius: BorderRadius.circular(30),
        ),
        shadows: const [
          BoxShadow(
              color: plantResultShadowColor,
              blurRadius: 20,
              offset: Offset(0, 4),
              spreadRadius: 0)
        ],
      ),
      child: Material(
        // Для InkWell эффекта
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          child: Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: plantResultBlack,
                fontSize: 12,
                fontFamily: plantResultFontFamily,
                fontWeight: FontWeight.w500,
                height: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Виджет тега
class PlantResultTag extends StatelessWidget {
  final String text;
  final Color textColor;
  final bool isHealthy;

  const PlantResultTag({
    Key? key,
    required this.text,
    required this.textColor,
    required this.isHealthy,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const double height = 28.0;
    final isToxic = text.startsWith('Токс');
    final Color borderColor =
        isToxic ? plantResultTagToxicRed : (isHealthy ? plantResultGreenAccent : plantResultTagRed);
    final Color realTextColor =
        isToxic ? plantResultTagToxicRed : (isHealthy ? plantResultGreenAccent : plantResultTagRed);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30),
      side: isToxic
          ? const BorderSide(color: plantResultTagToxicRed, width: 1)
          : BorderSide(color: borderColor, width: 1),
    );
    const shadow = BoxShadow(
      color: plantResultShadowColor,
      blurRadius: 20,
      offset: Offset(0, 4),
      spreadRadius: 0,
    );

    return Container(
      height: height,
      decoration: ShapeDecoration(
        color: plantResultWhite,
        shape: shape,
        shadows: const [shadow],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: realTextColor,
            fontSize: 14,
            fontFamily: plantResultFontFamily,
            fontWeight: FontWeight.w400,
            height: 0,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// Виджет иконки для нижней навигации
class PlantResultBottomNavIcon extends StatelessWidget {
  final String asset;
  final double size;
  final VoidCallback? onTap;

  const PlantResultBottomNavIcon({
    Key? key,
    required this.asset,
    required this.size,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size * 1.5, // Контейнер шире, чем иконка
        height: size * 1.5,
        child: Center(
          child: SvgPicture.asset(
            asset,
            width: size,
            height: size,
            colorFilter: const ColorFilter.mode(plantResultGreenAccent, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}

// Виджет кнопки избранного для нижней навигации
class PlantResultFavoriteButton extends StatelessWidget {
  final double size;
  final dynamic plantData;
  final bool? isInCollection;
  final VoidCallback? onFavoriteToggled;

  const PlantResultFavoriteButton({
    Key? key,
    required this.size,
    required this.plantData,
    this.isInCollection,
    this.onFavoriteToggled,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (plantData != null && plantData is PlantInfo) {
      return FavoriteButton(
        plantId: plantData.scanId ?? '',
        size: size,
        activeColor: plantResultGreenAccent,
        inactiveColor: plantResultGreenAccent.withOpacity(0.3),
        plantData: plantData as PlantInfo, // Передаем данные растения
        onToggle: onFavoriteToggled, // Передаем callback для обновления состояния
      );
    } else {
      // Если нет данных растения, показываем неактивную иконку
      return SizedBox(
        width: size * 1.5,
        height: size * 1.5,
        child: Center(
          child: SvgPicture.asset(
            plantResultBottomHeartAsset,
            width: size,
            height: size,
            colorFilter: ColorFilter.mode(plantResultGreenAccent.withOpacity(0.3), BlendMode.srcIn),
          ),
        ),
      );
    }
  }
}

// Индикатор загрузки для изображений
class PlantResultLoadingIndicator extends StatelessWidget {
  final bool isMainImage;
  final bool isHealthy;

  const PlantResultLoadingIndicator({
    Key? key,
    required this.isMainImage,
    required this.isHealthy,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: isHealthy ? plantResultGreenAccent : plantResultRedAccent,
            strokeWidth: 3,
          ),
          const SizedBox(height: 12),
          Text(
            isMainImage ? 'Загружаем фото растения...' : 'Обработка изображения...',
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 12,
              fontFamily: plantResultFontFamily,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// НОВОЕ: Виджет для стрелки с увеличенной областью клика
class PlantResultClickableArrow extends StatelessWidget {
  final double screenWidth;
  final Color iconColor;
  final VoidCallback? onTap;

  const PlantResultClickableArrow({
    Key? key,
    required this.screenWidth,
    required this.iconColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(screenWidth * 0.03), // Увеличиваем область клика
        child: SvgPicture.asset(
          plantResultArrowRightAsset,
          width: screenWidth * 0.018,
          height: screenWidth * 0.033,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        ),
      ),
    );
  }
} 