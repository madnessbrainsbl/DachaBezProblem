import 'package:flutter/material.dart';

class HomeStyles {
  // Цвета
  static const Color primaryGreen = Color(0xFF63A36C);
  static const Color lightGreen = Color(0xFFB7E0A4);
  static const Color bgGradientStart = Color(0xFFEBF5DB);
  static const Color bgGradientEnd = Color(0xFFB7E0A4);
  static const Color buttonGradientStart = Color(0xFF78B065);
  static const Color buttonGradientEnd = Color(0xFF388D78);
  static const Color redAlert = Color(0xFFD30000);
  static const Color grayText = Color(0xFF979797);
  static const Color lightGray = Color(0xFFDDDDDD);

  // Тексты
  static const TextStyle titleStyle = TextStyle(
    fontFamily: 'Gilroy',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );

  static const TextStyle subTitleStyle = TextStyle(
    fontFamily: 'Gilroy',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Colors.black,
  );

  static const TextStyle buttonTextStyle = TextStyle(
    fontFamily: 'Gilroy',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const TextStyle calendarDayStyle = TextStyle(
    fontFamily: 'Gilroy',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Color(0xFFDDDDDD),
  );

  static const TextStyle dateStyle = TextStyle(
    fontFamily: 'Gilroy',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );

  static const TextStyle selectedDateStyle = TextStyle(
    fontFamily: 'Gilroy',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const TextStyle bottomNavLabelStyle = TextStyle(
    fontFamily: 'Gilroy',
    fontSize: 9,
    fontWeight: FontWeight.w400,
    color: Colors.black,
  );

  // Градиенты
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgGradientStart, bgGradientEnd],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [buttonGradientStart, buttonGradientEnd],
  );

  static const LinearGradient treatButtonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF0074A6), Color(0xFF19C85F)],
  );

  static const LinearGradient addPlantButtonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF78B065), Color(0xFF388D78)],
  );

  // Декорации
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: [
      BoxShadow(
        color: Color(0x1931873F),
        blurRadius: 20,
        offset: Offset(0, 4),
      )
    ],
  );

  static BoxDecoration addButtonDecoration = BoxDecoration(
    gradient: buttonGradient,
    borderRadius: BorderRadius.circular(30),
    boxShadow: [
      BoxShadow(
        color: Color(0x1931873F),
        blurRadius: 20,
        offset: Offset(0, 4),
      )
    ],
  );
}
