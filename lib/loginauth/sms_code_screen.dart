import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'auth_screen_styles.dart';
import '../services/api/auth_service.dart';
import '../services/api/api_exceptions.dart';
import '../services/api/network_error_widget.dart';
import '../services/logger.dart';

class SmsCodeScreen extends StatefulWidget {
  final bool isPhoneSelected; // Определение способа входа
  final String contactInfo; // Добавляем контактную информацию для отображения

  const SmsCodeScreen({
    Key? key,
    required this.isPhoneSelected,
    required this.contactInfo,
  }) : super(key: key);

  @override
  State<SmsCodeScreen> createState() => _SmsCodeScreenState();
}

class _SmsCodeScreenState extends State<SmsCodeScreen> with WidgetsBindingObserver {
  // Контроллеры для полей ввода кода
  final List<TextEditingController> _controllers =
      List.generate(6, (index) => TextEditingController());

  // Фокус-ноды для каждого поля
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  // Скрытое поле для системного авто-заполнения кода (iOS/Android)
  final TextEditingController _fullCodeController = TextEditingController();
  final FocusNode _fullCodeFocusNode = FocusNode();

  // Таймер для обратного отсчета
  int _secondsRemaining = 600; // 10 минут
  bool _isTimerRunning = true;
  Timer? _timer;

  // Сервис аутентификации
  final AuthService _authService = AuthService();

  // Состояние загрузки
  bool _isLoading = false;

  // Состояние ошибки
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Подписываемся на события жизненного цикла, чтобы восстанавливать фокус
    WidgetsBinding.instance.addObserver(this);

    // Слушаем скрытое поле: распределяем цифры по ячейкам, поддерживаем удаление/вставку/автозаполнение
    _fullCodeController.addListener(_onFullCodeChanged);

    // Запускаем таймер
    _startTimer();
    
    // После первого кадра фокусируем первую пустую ячейку, чтобы открыть клавиатуру
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusFirstEmptyCell();
    });
  }

  void _onFullCodeChanged() {
    final text = _fullCodeController.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Обрезаем до 6 символов
    final normalized = text.length > 6 ? text.substring(0, 6) : text;

    // Если было лишнее, откатим контроллер к нормализованному значению, сохранив каретку
    if (normalized != _fullCodeController.text) {
      _fullCodeController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(
          offset: normalized.length.clamp(0, normalized.length),
        ),
      );
    }

    // Распределяем символы по ячейкам
    for (int i = 0; i < 6; i++) {
      final char = i < normalized.length ? normalized[i] : '';
      if (_controllers[i].text != char) {
        _controllers[i].text = char;
      }
    }

    // Если ввели все 6 символов — проверяем код
    if (normalized.length == 6) {
      _verifyCode();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _isTimerRunning = false;
        });
        _timer?.cancel();
        AppLogger.ui('Таймер истек, код более недействителен');
      }
    });
  }

  // Обновление кода - повторный запрос
  Future<void> _resendCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    AppLogger.ui('Повторная отправка кода для ${widget.contactInfo}');

    try {
      final bool success = await _authService.sendAuthCode(
        phone: widget.isPhoneSelected ? widget.contactInfo : null,
        email: widget.isPhoneSelected ? null : widget.contactInfo,
      );

      if (success && mounted) {
        // Сбрасываем таймер
        setState(() {
          _secondsRemaining = 600;
          _isTimerRunning = true;

          // Очищаем поля ввода
          for (var controller in _controllers) {
            controller.clear();
          }
          _fullCodeController.clear();
          // Фокус на первом поле
          _requestHiddenFocus();
        });

        _startTimer();

        AppLogger.ui('Новый код успешно отправлен');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Новый код отправлен')),
        );
      }
    } on NoInternetException catch (e) {
      if (mounted) {
        AppLogger.ui('Отображение ошибки соединения');
        context.showNetworkError(
          e.message,
          () => _resendCode(),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        AppLogger.ui('Ошибка при повторной отправке кода: ${e.message}');
        setState(() {
          _errorMessage = e.message;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Проверка введенного кода
  Future<void> _verifyCode() async {
    // Собираем код из всех полей
    final code = _controllers.map((c) => c.text).join();

    // Валидация ввода
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Введите полный код подтверждения';
      });
      AppLogger.ui('Неполный код: $code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    AppLogger.ui('Проверка кода: $code');

    try {
      final response = await _authService.verifyAuthCode(code: code);

      if (mounted) {
        if (response['success'] == true) {
          AppLogger.ui('Код успешно проверен, анализ данных профиля');

          final bool isProfileComplete = response['isProfileComplete'] ?? false;
          final String? name = response['name'];
          final String? city = response['city'];

          AppLogger.ui(
              'Статус профиля: isComplete=$isProfileComplete, name=$name, city=$city');

          if (isProfileComplete) {
            // Если профиль полностью заполнен - сразу переходим на главный экран
            AppLogger.ui('Профиль заполнен, переход на главный экран');
            // TODO: Заменить на переход на главный экран
            Navigator.pushNamedAndRemoveUntil(
                context, '/home', (route) => false);
          } else if (name != null &&
              name.isNotEmpty &&
              (city == null || city.isEmpty)) {
            // Если имя заполнено, но город нет - переходим на выбор города
            AppLogger.ui('Имя заполнено, переход на выбор города');
            Navigator.pushNamed(context, '/region_select',
                arguments: {'userName': name});
          } else {
            // Если имя не заполнено - переходим на экран ввода имени
            AppLogger.ui('Имя не заполнено, переход на ввод имени');
            Navigator.pushNamed(context, '/name_input');
          }
        } else {
          // Ошибка верификации
          setState(() {
            _errorMessage = 'Неверный код подтверждения';
          });
        }
      }
    } on NoInternetException catch (e) {
      if (mounted) {
        AppLogger.ui('Отображение ошибки соединения');
        context.showNetworkError(
          e.message,
          () => _verifyCode(),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        AppLogger.ui('Ошибка при проверке кода: ${e.message}');
        setState(() {
          _errorMessage = e.message;
        });
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
  void dispose() {
    // Очистка ресурсов
    _timer?.cancel();
    _fullCodeController.removeListener(_onFullCodeChanged);
    _fullCodeController.dispose();
    _fullCodeFocusNode.dispose();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    AppLogger.ui('Экран ввода кода закрыт');
    super.dispose();
  }

  // Форматирование таймера в формат 1:00
  String get formattedTime {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: SingleChildScrollView(
            child: Container(
              height: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Кнопка «Назад» в стиле приложения
                    SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: SvgPicture.asset(
                            'assets/images/favorites/back_arrow.svg',
                            width: 24,
                            height: 24,
                            color: Color(0xFF63A36C),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 43),

                    // Заголовок - динамический в зависимости от способа входа
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.isPhoneSelected
                            ? 'Введите код из СМС'
                            : 'Введите код из письма',
                        style: AuthScreenStyles.smsCodeTitleStyle,
                      ),
                    ),

                    SizedBox(height: 8),

                    // Отображаем контактную информацию
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Код отправлен на ${widget.contactInfo}',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                    ),

                    SizedBox(height: 27),

                    // Группа автозаполнения и скрытое поле с oneTimeCode
                    AutofillGroup(
                      child: Column(
                        children: [
                          // Скрытое поле для автозаполнения (оставляем, но без фокуса по умолчанию)
                          SizedBox(
                            height: 0,
                            width: 0,
                            child: TextField(
                              controller: _fullCodeController,
                              focusNode: _fullCodeFocusNode,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              maxLength: 6,
                              decoration: const InputDecoration(
                                counterText: '',
                                border: InputBorder.none,
                              ),
                            ),
                          ),

                          // Поля для визуального ввода кода (readOnly, синхронизируются со скрытым)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 0),
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: _requestHiddenFocus,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(6, (index) => _buildCodeInput(index)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Сообщение об ошибке
                    if (_errorMessage != null) ...[
                      SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    SizedBox(height: 40),

                    // Таймер повторной отправки или кнопка повторной отправки
                    _isTimerRunning
                        ? Text(
                            'Повторная отправка через: ${formattedTime}',
                            textAlign: TextAlign.center,
                            style: AuthScreenStyles.resendTimerStyle,
                          )
                        : GestureDetector(
                            onTap: _isLoading ? null : _resendCode,
                            child: Text(
                              'Отправить код повторно',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Gilroy',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF63A36C),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),

                    SizedBox(height: 20),

                    // Кнопка продолжить
                    Container(
                      width: 200,
                      height: 42,
                      decoration: AuthScreenStyles.continueButtonDecoration,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyCode,
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _requestHiddenFocus() {
    // Снимаем текущий фокус, затем повторно запрашиваем фокус у скрытого поля
    FocusScope.of(context).unfocus();
    Future.delayed(const Duration(milliseconds: 10), () {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_fullCodeFocusNode);
      // Явно просим показать клавиатуру (полезно после возврата из другого приложения)
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  void _focusFirstEmptyCell() {
    for (int i = 0; i < _controllers.length; i++) {
      if (_controllers[i].text.isEmpty) {
        _focusNodes[i].requestFocus();
        SystemChannels.textInput.invokeMethod('TextInput.show');
        return;
      }
    }
    // Если все ячейки заполнены, ставим фокус на последнюю
    _focusNodes.last.requestFocus();
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  // Виджет для поля ввода одной цифры кода
  Widget _buildCodeInput(int index) {
    return Container(
      width: 45,
      height: 60,
      decoration: AuthScreenStyles.smsCodeInputDecoration,
      child: Center(
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          autofocus: index == 0,
          readOnly: false,
          enableInteractiveSelection: false,
          keyboardType: TextInputType.number,
          maxLength: 1,
          decoration: InputDecoration(
            border: InputBorder.none,
            counterText: '',
            hintText: '',
          ),
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2024),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onTap: () => SystemChannels.textInput.invokeMethod('TextInput.show'),
          onChanged: (val) {
            final text = val.replaceAll(RegExp(r'[^0-9]'), '');
            if (text.isEmpty) {
              _controllers[index].clear();
              if (index > 0) _focusNodes[index - 1].requestFocus();
              return;
            }
            // Берём только первую цифру
            if (_controllers[index].text != text[0]) {
              _controllers[index].text = text[0];
              _controllers[index].selection = TextSelection.collapsed(offset: 1);
            }
            if (index < _controllers.length - 1) {
              _focusNodes[index + 1].requestFocus();
            } else {
              // Последняя цифра — проверяем код
              _verifyCode();
            }
          },
        ),
      ),
    );
  }
}
