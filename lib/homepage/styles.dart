import 'package:flutter/material.dart';

class AppStyles {
  static const TextStyle calendarTextStyle = TextStyle(
    fontFamily: 'Gilroy',
    fontWeight: FontWeight.w600,
    fontSize: 14,
    color: Colors.black,
  );

  static const TextStyle plantInfoTextStyle = TextStyle(
    fontFamily: 'Gilroy',
    fontWeight: FontWeight.w500,
    fontSize: 14,
    color: Colors.white,
  );

  static const TextStyle diseaseAlertTextStyle = TextStyle(
    fontFamily: 'Gilroy',
    fontWeight: FontWeight.w600,
    fontSize: 14,
    color: Colors.white,
  );

  static const TextStyle usefulInfoTextStyle = TextStyle(
    fontFamily: 'Gilroy',
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: Colors.black,
  );

  static const BoxDecoration containerDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFEBF5DB), Color(0xFFB7E0A4)],
    ),
  );
}

