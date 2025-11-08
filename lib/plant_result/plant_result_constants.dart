import 'package:flutter/material.dart';

// Цвета, основанные на макете Figma
const Color plantResultBlack = Colors.black; // Черный цвет для большей части текста
const Color plantResultDarkText = Color(0xFF1F2024); // Цвет заголовков
const Color plantResultGreenAccent = Color(0xFF63A36C); // Основной зеленый акцент
const Color plantResultWhite = Colors.white; // Белый цвет фонов и элементов
const Color plantResultLightGreenBg = Color(0xFFEBF5DB); // Цвет фона градиента
const Color plantResultPlaceholderGrey = Color(0xFFD9D9D9); // Плейсхолдер аватара
const Color plantResultTagToxicRed = Color(0xFFD30000); // Красный для токсичных тегов
const Color plantResultSliderBgGrey = Color(0xFFF6F6F6); // Фон слайдера температуры
const Color plantResultSliderTextGrey = Color(0xFFAEAEAE); // Текст слайдера
const Color plantResultShadowColor = Color(0x1931873F); // Цвет теней
const Color plantResultGradientGreen1 = Color(0xFF78B065); // Начало градиента кнопок
const Color plantResultGradientGreen2 = Color(0xFF388D78); // Конец градиента кнопок

// Цвета для нездорового состояния
const Color plantResultRedAccent = Color(0xFFE46564); // Акцент для латинского названия
const Color plantResultTagRed = Color(0xFFE67372); // Цвет для тегов
const Color plantResultBorderRed = Color(0xFFECA5A4); // Бордер кнопки
const Color plantResultGradientRed1 = Color(0xFFECA5A4); // Градиент температуры (начало)
const Color plantResultGradientRed2 = Color(0xFFDF4040); // Градиент температуры (конец)
const Color plantResultBgRed = Color(0xFFF2CCC5); // Фон градиента

// Градиенты
const LinearGradient plantResultBackgroundGradient = LinearGradient(
  begin: Alignment(0.00, -1.00),
  end: Alignment(0, 1),
  colors: [plantResultWhite, plantResultLightGreenBg],
);

const LinearGradient plantResultButtonGradient = LinearGradient(
  begin: Alignment(0.00, -1.00),
  end: Alignment(0, 1),
  colors: [plantResultGradientGreen1, plantResultGradientGreen2],
);

const LinearGradient plantResultSliderGradient = LinearGradient(
  begin: Alignment(0.00, -1.00),
  end: Alignment(0, 1),
  colors: [plantResultGradientGreen1, plantResultGradientGreen2],
);

// Базовые стили текста
const String plantResultFontFamily = 'Gilroy';

// Пути к ассетам
const String plantResultAssetPath = 'assets/images/plant_result_zdorovoe/';

// Ассеты изображений
const String plantResultMainImageAsset = '${plantResultAssetPath}image 12.png';
const String plantResultAvatarAsset = '${plantResultAssetPath}still-life-with-indoor-plants 2.png';
const String plantResultCloseIconAsset = '${plantResultAssetPath}Group 63.svg';
const String plantResultPlusIconAsset = '${plantResultAssetPath}+.svg';
const String plantResultMinusIconAsset = '${plantResultAssetPath}minus.svg';
const String plantResultBookIconAsset = '${plantResultAssetPath}Vector.svg';
const String plantResultWaterDropIconAsset = '${plantResultAssetPath}Union.svg';
const String plantResultTempIconAsset = '${plantResultAssetPath}Group 130.svg';
const String plantResultPestIconAsset = '${plantResultAssetPath}Group 8.svg';
const String plantResultArrowRightAsset = '${plantResultAssetPath}Vector 15.svg';
const String plantResultPestDividerAsset1 = '${plantResultAssetPath}Vector 13.svg';
const String plantResultBottomCameraAsset = '${plantResultAssetPath}Group 117.svg';
const String plantResultBottomHeartAsset = '${plantResultAssetPath}Layer_2_00000154399694884061480560000015505170056280207754_.svg';
const String plantResultBottomShareAsset = '${plantResultAssetPath}Group.svg'; 