import 'package:flutter/material.dart';

class AuthScreenStyles {
  static const TextStyle welcomeStyle = TextStyle(
    fontFamily: 'Gilroy',
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.12,
    color: Color(0xFF1F2024),
  );

  static const TextStyle helperTextStyle = TextStyle(
    fontFamily: 'Gilroy',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.14,
    color: Color(0xFF1F2024),
  );

  static const TextStyle inputLabelStyle = TextStyle(
    fontFamily: 'Gilroy',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.14,
    color: Color(0xFF63A36C),
  );

  static const TextStyle smsCodeTitleStyle = TextStyle(
    fontFamily: 'Gilroy',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.10,
    color: Color(0xFF1F2024),
  );

  static const TextStyle nameScreenTitleStyle = smsCodeTitleStyle;

  static const TextStyle resendTimerStyle = TextStyle(
    fontFamily: 'Gilroy',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.14,
    letterSpacing: 0.14,
    color: Color(0xFF63A36C),
  );

  static BoxDecoration inputDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(30),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 4,
        offset: Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration smsCodeInputDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: [
      BoxShadow(
        color: Color(0x1931873F),
        blurRadius: 20,
        offset: Offset(0, 4),
        spreadRadius: 0,
      ),
    ],
  );

  static BoxDecoration nameInputDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: [
      BoxShadow(
        color: Color(0x1931873F),
        blurRadius: 20,
        offset: Offset(0, 4),
        spreadRadius: 0,
      ),
    ],
  );

  static BoxDecoration continueButtonDecoration = BoxDecoration(
    borderRadius: BorderRadius.circular(30),
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF78B065),
        Color(0xFF388D79),
      ],
      stops: [0.0, 1.0],
    ),
    boxShadow: [
      BoxShadow(
        color: Color(0xFF63A36C).withOpacity(0.3),
        blurRadius: 4,
        offset: Offset(0, 2),
      ),
    ],
  );

  static const TextStyle continueButtonTextStyle = TextStyle(
    fontFamily: 'Gilroy',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const TextStyle socialLoginTextStyle = TextStyle(
    fontFamily: 'Gilroy',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.14,
    color: Color(0xFF1F2024),
  );

  static BoxDecoration socialButtonDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(30),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 4,
        offset: Offset(0, 2),
      ),
    ],
  );

  static const TextStyle socialButtonTextStyle = TextStyle(
    fontFamily: 'Gilroy',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.14,
    color: Color(0xFF63A36C),
  );
}
