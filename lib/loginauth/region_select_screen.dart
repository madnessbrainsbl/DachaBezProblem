import 'package:flutter/material.dart';
import 'dart:async';
import 'auth_screen_styles.dart';
import '../services/local_regions_service.dart';
import '../homepage/home_screen.dart';
import '../services/api/auth_service.dart';
import '../services/api/api_exceptions.dart';
import '../services/api/network_error_widget.dart';
import '../services/logger.dart';

class RegionSelectScreen extends StatefulWidget {
  final String userName; // Имя пользователя, переданное с предыдущего экрана
  final String initialCity; // Начальный город, если есть

  const RegionSelectScreen({
    Key? key,
    required this.userName,
    this.initialCity = '',
  }) : super(key: key);

  @override
  State<RegionSelectScreen> createState() => _RegionSelectScreenState();
}

class _RegionSelectScreenState extends State<RegionSelectScreen> {
  // Контроллер для поля выбора региона
  late final TextEditingController _regionController;

  // Сервис для получения подсказок регионов
  final LocalRegionsService _regionsService = LocalRegionsService();

  // Сервис для работы с API аутентификации
  final AuthService _authService = AuthService();

  // Список подсказок
  List<RegionSuggestion> _suggestions = [];

  // Флаг загрузки
  bool _isLoading = false;

  // Таймер для задержки запросов при вводе
  Timer? _debounceTimer;

  // Показывать ли список подсказок
  bool _showSuggestions = false;

  // Флаг для отслеживания, был ли выбран регион
  bool _regionSelected = false;

  // Последнее значение в текстовом поле
  String _lastTextValue = '';

  @override
  void initState() {
    super.initState();

    _regionController = TextEditingController(text: widget.initialCity);
    _lastTextValue = widget.initialCity;
    _regionSelected = widget.initialCity.isNotEmpty;

    AppLogger.ui(
        'Открыт экран выбора города. Имя пользователя: ${widget.userName}, начальный город: ${widget.initialCity}');

    // Слушатель изменений текста для получения подсказок
    _regionController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    // Очистка ресурсов
    _regionController.removeListener(_onSearchTextChanged);
    _regionController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Обработчик изменения текста в поле ввода
  void _onSearchTextChanged() {
    final currentText = _regionController.text;

    // Если текст изменился пользователем, сбрасываем флаг выбора региона
    if (currentText != _lastTextValue) {
      _regionSelected = false;
      _lastTextValue = currentText;
    }

    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      // Получаем подсказки по введенному тексту только если регион не был выбран
      if (currentText.length >= 2 && !_regionSelected) {
        _getSuggestions(currentText);
      } else if (currentText.length < 2) {
        setState(() {
          _suggestions = [];
          _showSuggestions = false;
        });
      }
    });
  }

  // Получение подсказок из сервиса
  Future<void> _getSuggestions(String query) async {
    // Если регион уже выбран, не показываем подсказки
    if (_regionSelected) return;

    setState(() {
      _isLoading = true;
      _showSuggestions = true;
    });

    try {
      final suggestions = await _regionsService.getSuggestions(query);

      // Проверяем, не был ли выбран регион во время ожидания ответа
      if (_regionSelected) {
        setState(() {
          _isLoading = false;
          _showSuggestions = false;
        });
        return;
      }

      setState(() {
        _suggestions = suggestions;
        _isLoading = false;

        // Если найдена только одна подсказка и она точно соответствует запросу,
        // автоматически выбираем её
        if (suggestions.length == 1 &&
            suggestions[0].value.toLowerCase() == query.toLowerCase()) {
          _selectRegion(suggestions[0]);
        }
      });
    } catch (e) {
      AppLogger.error('Ошибка при получении подсказок', e);
      setState(() {
        _isLoading = false;
        _suggestions = [];
      });
    }
  }

  // Выбор подсказки
  void _selectRegion(RegionSuggestion suggestion) {
    setState(() {
      _regionController.text = suggestion.value;
      _lastTextValue = suggestion.value;
      _showSuggestions = false;
      _suggestions = [];
      _regionSelected = true; // Устанавливаем флаг выбора региона

      // Снимаем фокус с текстового поля
      FocusScope.of(context).unfocus();
    });
  }

  // Обновление профиля и переход на главный экран
  Future<void> _updateProfileAndContinue() async {
    final city = _regionController.text.trim();

    // Проверка, выбран ли город
    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Пожалуйста, укажите ваш город')),
      );
      return;
    }

    // Проверка, что город был выбран из списка подсказок
    if (!_regionSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Пожалуйста, выберите город из списка')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    AppLogger.ui(
        'Отправка данных профиля: имя=${widget.userName}, город=$city');

    try {
      final success = await _authService.updateProfile(
        name: widget.userName,
        city: city,
      );

      if (success && mounted) {
        AppLogger.ui('Профиль успешно обновлен, переход на главный экран');

        // Переход на главный экран
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (route) => false, // Удаляем все предыдущие экраны из стека
        );
      }
    } on NoInternetException catch (e) {
      if (mounted) {
        AppLogger.ui('Отображение ошибки соединения');
        context.showNetworkError(
          e.message,
          () => _updateProfileAndContinue(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Разрешаем автоматическую подстройку под клавиатуру
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        // Скрываем подсказки при нажатии вне поля ввода
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() {
            _showSuggestions = false;
          });
        },
        child: Container(
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
            child: Stack(
              children: [
                // Основной контент
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 83),

                      // Заголовок
                      Text(
                        'Укажите ваш город',
                        style: AuthScreenStyles.nameScreenTitleStyle,
                      ),

                      SizedBox(height: 20),

                      // Поле ввода города
                      Container(
                        height: 87,
                        decoration: AuthScreenStyles.nameInputDecoration,
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            // Поле ввода
                            Expanded(
                              child: TextField(
                                controller: _regionController,
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1F2024),
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Начните вводить название города',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF979797),
                                    fontSize: 16,
                                    fontFamily: 'Gilroy',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),

                            // Иконка карандаша
                            Image.asset(
                              'assets/images/picmini/shape.png',
                              width: 20,
                              height: 20,
                            ),
                          ],
                        ),
                      ),

                      // Список подсказок
                      if (_showSuggestions &&
                          (_suggestions.isNotEmpty || _isLoading))
                        Expanded(
                          child: Container(
                            margin: EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: _isLoading
                                ? Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFF63A36C)),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _suggestions.length,
                                    itemBuilder: (context, index) {
                                      final suggestion = _suggestions[index];
                                      return ListTile(
                                        title: Text(suggestion.value),
                                        subtitle: suggestion.details != null
                                            ? Text(suggestion.details!)
                                            : null,
                                        onTap: () => _selectRegion(suggestion),
                                      );
                                    },
                                  ),
                          ),
                        ),

                      // Дополняем пространство, если нет подсказок
                      if (!_showSuggestions || _suggestions.isEmpty) Spacer(),

                      // Кнопка продолжить
                      Center(
                        child: Container(
                          width: 200,
                          height: 42,
                          margin: EdgeInsets.only(bottom: 40),
                          decoration: AuthScreenStyles.continueButtonDecoration,
                          child: ElevatedButton(
                            onPressed:
                                _isLoading ? null : _updateProfileAndContinue,
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
                                    style: AuthScreenStyles
                                        .continueButtonTextStyle,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
