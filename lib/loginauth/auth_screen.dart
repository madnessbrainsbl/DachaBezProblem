import 'package:flutter/material.dart';
import 'dart:io';
import 'auth_screen_styles.dart';
import 'sms_code_screen.dart';
import 'name_input_screen.dart';
import '../services/api/auth_service.dart';
import '../services/api/api_exceptions.dart';
import '../services/api/network_error_widget.dart';
import '../services/logger.dart';
import '../services/social_auth_service.dart';
import 'package:flutter/services.dart';
import '../widgets/safe_asset_icon.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with WidgetsBindingObserver {
  // Состояние для отслеживания выбранного способа входа
  bool isPhoneSelected = true;
  // Контроллер для поля ввода
  final TextEditingController _inputController = TextEditingController();
  // Фокус нода для управления клавиатурой и её повторным открытием при смене типа
  final FocusNode _inputFocusNode = FocusNode();
  void _onInputFocusChanged() {
    if (_inputFocusNode.hasFocus) {
      SystemChannels.textInput.invokeMethod('TextInput.show');
    }
  }
  // Сервис аутентификации
  final AuthService _authService = AuthService();
  // Сервис социальной аутентификации для проверки доступности
  final SocialAuthService _socialAuthService = SocialAuthService();
  // Состояние загрузки
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Добавляем слушатель для автоматического переключения режима ввода
    _inputController.addListener(_detectInputType);
    _inputFocusNode.addListener(_onInputFocusChanged);

    AppLogger.ui('Экран авторизации открыт');
    // Первичный фокус на поле ввода, чтобы показать клавиатуру
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _requestInputFocus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _requestInputFocus();
      });
    }
  }

  // Определяет тип ввода (телефон или email) и переключает режим
  void _detectInputType() {
    final input = _inputController.text.trim();

    if (input.isEmpty) return;

    // Проверяем, похож ли ввод на email
    final bool looksLikeEmail = input.contains('@') && input.contains('.');

    // Проверяем, похож ли ввод на телефон (содержит преимущественно цифры и + в начале)
    final nonDigitChars = input.replaceAll(RegExp(r'[0-9+]'), '');
    final bool looksLikePhone = nonDigitChars.length <=
        input.length * 0.2; // допускаем до 20% нецифровых символов

    // Переключаем режим, если текущий не соответствует вводу
    if (looksLikeEmail && isPhoneSelected) {
      AppLogger.ui('Обнаружен ввод email, переключаемся с телефона на email');
      setState(() {
        isPhoneSelected = false;
      });
      _refreshKeyboard();
    } else if (looksLikePhone && !isPhoneSelected && input.length > 3) {
      AppLogger.ui('Обнаружен ввод телефона, переключаемся с email на телефон');
      setState(() {
        isPhoneSelected = true;
      });
      _refreshKeyboard();
    }
  }

  // Перезапускает клавиатуру, чтобы она мгновенно переключила раскладку
  void _refreshKeyboard() {
    if (_inputFocusNode.hasFocus) {
      _inputFocusNode.unfocus();
      // Короткая задержка, чтобы Flutter успел закрыть текущую клавиатуру
      Future.delayed(const Duration(milliseconds: 1), () {
        if (mounted) {
          FocusScope.of(context).requestFocus(_inputFocusNode);
        }
      });
    }
  }

  void _requestInputFocus() {
    // Снимаем фокус и повторно запрашиваем, затем явно просим показать клавиатуру
    FocusScope.of(context).unfocus();
    Future.delayed(const Duration(milliseconds: 10), () {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_inputFocusNode);
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  @override
  void dispose() {
    _inputController.removeListener(_detectInputType);
    _inputController.dispose();
    _inputFocusNode.removeListener(_onInputFocusChanged);
    _inputFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Метод для отправки кода подтверждения
  Future<void> _sendAuthCode() async {
    final input = _inputController.text.trim();

    // Валидация ввода
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isPhoneSelected
                ? 'Введите номер телефона'
                : 'Введите адрес электронной почты')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    AppLogger.ui('Отправка кода подтверждения для: $input');

    try {
      final bool success = await _authService.sendAuthCode(
        phone: isPhoneSelected ? input : null,
        email: isPhoneSelected ? null : input,
      );

      if (success && mounted) {
        AppLogger.ui('Код успешно отправлен, переход на экран ввода кода');

        // Переход на экран ввода кода
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SmsCodeScreen(
              isPhoneSelected: isPhoneSelected,
              contactInfo: input,
            ),
          ),
        );
      }
    } on NoInternetException catch (e) {
      if (mounted) {
        AppLogger.ui('Отображение ошибки соединения');
        context.showNetworkError(
          e.message,
          () => _sendAuthCode(),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        AppLogger.ui('Отображение ошибки API: ${e.message}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Метод для входа через Google
  Future<void> _signInWithGoogle() async {
    if (!_socialAuthService.isGoogleSignInAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Вход через Google недоступен на этой платформе'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.signInWithGoogle();

      if (result['success'] == true && mounted) {
        // Если профиль не заполнен, переходим на экран ввода имени и региона
        if (!result['isProfileComplete']) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NameInputScreen(
                initialName: result['name'] ?? '',
                initialCity: result['city'] ?? '',
              ),
            ),
          );
        } else {
          // Если профиль заполнен, переходим на главный экран
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else if (mounted) {
        // Показываем ошибку
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Ошибка при входе через Google'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on NoInternetException catch (e) {
      if (mounted) {
        context.showNetworkError(
          e.message,
          () => _signInWithGoogle(),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Метод для входа через Apple
  Future<void> _signInWithApple() async {
    if (!_socialAuthService.isAppleSignInAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Вход через Apple недоступен на этой платформе'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.signInWithApple();

      if (result['success'] == true && mounted) {
        // Если профиль не заполнен, переходим на экран ввода имени и региона
        if (!result['isProfileComplete']) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NameInputScreen(
                initialName: result['name'] ?? '',
                initialCity: result['city'] ?? '',
              ),
            ),
          );
        } else {
          // Если профиль заполнен, переходим на главный экран
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else if (mounted) {
        // Показываем ошибку
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              // Показываем специальное сообщение для ошибки симулятора
              result['simulator_error'] == true
                  ? 'Вход через Apple не работает в симуляторе. Пожалуйста, используйте другой способ входа или запустите приложение на реальном устройстве.'
                  : (result['message'] ?? 'Ошибка при входе через Apple')
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5), // Увеличиваем время отображения сообщения
          ),
        );
      }
    } on NoInternetException catch (e) {
      if (mounted) {
        context.showNetworkError(
          e.message,
          () => _signInWithApple(),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Метод для входа через Яндекс
  Future<void> _signInWithYandex() async {
    if (!_socialAuthService.isYandexSignInAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Вход через Яндекс недоступен на этой платформе'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.signInWithYandex();

      if (result['success'] == true && mounted) {
        // Если профиль не заполнен, переходим на экран ввода имени и региона
        if (!result['isProfileComplete']) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NameInputScreen(
                initialName: result['name'] ?? '',
                initialCity: result['city'] ?? '',
              ),
            ),
          );
        } else {
          // Если профиль заполнен, переходим на главный экран
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else if (mounted) {
        // Показываем ошибку
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Ошибка при входе через Яндекс'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on NoInternetException catch (e) {
      if (mounted) {
        context.showNetworkError(
          e.message,
          () => _signInWithYandex(),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Разрешаем подстройку при появлении клавиатуры
      resizeToAvoidBottomInset: true,
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
          // Оборачиваем весь контент в SingleChildScrollView для возможности прокрутки
          child: SingleChildScrollView(
            child: Container(
              // Минимальная высота равна высоте экрана минус отступы безопасной зоны
              height: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
              child: Column(
                children: [
                  // Logo Image
                  Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 220,
                      height: 160,
                    ),
                  ),

                  // Welcome Text
                  Padding(
                    padding: EdgeInsets.only(top: 26),
                    child: Text(
                      'Добро пожаловать',
                      style: AuthScreenStyles.welcomeStyle,
                    ),
                  ),

                  // Helper Text
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      'Вспомогательный текст о приложении',
                      style: AuthScreenStyles.helperTextStyle,
                    ),
                  ),

                  // Phone/Email Input
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Номер телефона или почта',
                          style: AuthScreenStyles.inputLabelStyle,
                          textAlign: TextAlign.center,
                        ),

                        // Объединенное поле с иконками и вводом
                        Container(
                          margin: EdgeInsets.only(top: 8),
                          height: 50,
                          decoration: AuthScreenStyles.inputDecoration,
                          child: Row(
                            children: [
                              // Селектор телефон/почта (внутри формы слева)
                              Container(
                                width: 70,
                                child: _buildPhoneMailSelector(),
                              ),

                              // Вертикальный разделитель
                              Container(
                                height: 30,
                                width: 1,
                                color: Colors.transparent,
                              ),

                              // Поле ввода (в центре)
                              Expanded(
                                child: TextField(
                                  key: ValueKey(isPhoneSelected),
                                  controller: _inputController,
                                  textAlign: TextAlign.center,
                                  keyboardType: isPhoneSelected
                                      ? TextInputType.phone
                                      : TextInputType.emailAddress,
                                  focusNode: _inputFocusNode,
                                  autofocus: true,
                                  textInputAction: TextInputAction.done,
                                  scrollPadding: EdgeInsets.only(bottom: 120),
                                  inputFormatters: isPhoneSelected
                                      ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))]
                                      : null,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 15),
                                    hintText: isPhoneSelected
                                        ? 'Введите номер телефона'
                                        : 'Введите email',
                                  ),
                                  onTap: _requestInputFocus,
                                ),
                              ),

                              // Иконка карандаша (справа)
                              Padding(
                                padding: EdgeInsets.only(right: 15),
                                child: Icon(Icons.edit, size: 20, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Continue Button
                  Container(
                    width: 200,
                    height: 42,
                    decoration: AuthScreenStyles.continueButtonDecoration,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendAuthCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Продолжить',
                              style: AuthScreenStyles.continueButtonTextStyle,
                            ),
                    ),
                  ),

                  // Social Login Section - использует Spacer вместо Expanded
                  Spacer(), // Заполняет доступное пространство

                  Text(
                    'Или войти через',
                    style: AuthScreenStyles.socialLoginTextStyle,
                  ),

                  Padding(
                    padding: EdgeInsets.only(top: 14, bottom: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSocialButton(
                            'Google', 'assets/images/google_icon.png'),
                        SizedBox(width: 12),
                        _buildSocialButton(
                            'Apple', 'assets/images/apple_icon.png'),
                        SizedBox(width: 12),
                        _buildSocialButton(
                            'Яндекс', 'assets/images/yandex_icon.png'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Виджет переключателя телефон/почта
  Widget _buildPhoneMailSelector() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Фоновое изображение телефона (под иконками)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 5),
          child: Icon(Icons.smartphone, size: 40, color: Colors.grey.withOpacity(0.3)),
        ),

        // Левая иконка (телефон)
        Positioned(
          left: 10,
          child: GestureDetector(
            onTap: () {
              setState(() {
                isPhoneSelected = true;
              });
              _refreshKeyboard();
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPhoneSelected ? Color(0xFF63A36C) : Color(0xFFDDDDDD),
              ),
              child: Center(
                child: Icon(Icons.phone, size: 13, color: Colors.white),
              ),
            ),
          ),
        ),

        // Правая иконка (почта)
        Positioned(
          right: 10,
          child: GestureDetector(
            onTap: () {
              setState(() {
                isPhoneSelected = false;
              });
              _refreshKeyboard();
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: !isPhoneSelected ? Color(0xFF63A36C) : Color(0xFFDDDDDD),
              ),
              child: Center(
                child: Icon(Icons.email, size: 13, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Обновленный метод для создания кнопок соц. сетей с проверкой платформы
  Widget _buildSocialButton(String name, String iconAsset) {
    // Проверяем доступность в зависимости от платформы
    bool isAvailable = true;
    VoidCallback? onTap;
    IconData iconData;

    if (name == 'Google') {
      isAvailable = _socialAuthService.isGoogleSignInAvailable;
      onTap = isAvailable ? _signInWithGoogle : null;
      iconData = Icons.g_mobiledata;
    } else if (name == 'Apple') {
      isAvailable = _socialAuthService.isAppleSignInAvailable;
      onTap = isAvailable ? _signInWithApple : null;
      iconData = Icons.apple;
    } else {
      isAvailable = _socialAuthService.isYandexSignInAvailable;
      onTap = isAvailable ? _signInWithYandex : null;
      iconData = Icons.language;
    }

    // Если кнопка недоступна, делаем ее неактивной
    return Opacity(
      opacity: isAvailable ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 103,
          height: 37,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(iconData, size: name == 'Яндекс' ? 16 : 17, color: Colors.black87),
              SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
