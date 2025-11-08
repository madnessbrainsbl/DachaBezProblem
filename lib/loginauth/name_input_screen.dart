import 'package:flutter/material.dart';
import 'auth_screen_styles.dart';
import 'region_select_screen.dart';
import '../services/logger.dart';

class NameInputScreen extends StatefulWidget {
  final String initialName;
  final String initialCity;

  const NameInputScreen(
      {Key? key, this.initialName = '', this.initialCity = ''})
      : super(key: key);

  @override
  State<NameInputScreen> createState() => _NameInputScreenState();
}

class _NameInputScreenState extends State<NameInputScreen> {
  // Контроллер для поля ввода имени
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    AppLogger.ui(
        'Открыт экран ввода имени. Начальное имя: ${widget.initialName}, город: ${widget.initialCity}');
  }

  @override
  void dispose() {
    // Очистка ресурсов
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Отключаем автоматическую подстройку под клавиатуру
      resizeToAvoidBottomInset: false,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 83),

                    // Заголовок
                    Text(
                      'Как вас зовут?',
                      style: AuthScreenStyles.nameScreenTitleStyle,
                    ),

                    SizedBox(height: 20),

                    // Поле ввода имени
                    Container(
                      height: 87,
                      width: double.infinity,
                      decoration: AuthScreenStyles.nameInputDecoration,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          // Поле ввода
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              style: TextStyle(
                                fontFamily: 'Gilroy',
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1F2024),
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Введите ваше имя',
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

                    SizedBox(height: 40),

                    // Кнопка продолжить
                    Center(
                      child: Container(
                        width: 200,
                        height: 42,
                        decoration: AuthScreenStyles.continueButtonDecoration,
                        child: ElevatedButton(
                          onPressed: () {
                            // Действие при нажатии кнопки
                            final name = _nameController.text.trim();
                            if (name.isEmpty) {
                              // Показать сообщение об ошибке
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Пожалуйста, введите ваше имя'),
                                ),
                              );
                              return;
                            }

                            if (name.length < 2) {
                              // Показать сообщение об ошибке
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Имя должно содержать не менее 2 символов'),
                                ),
                              );
                              return;
                            }

                            AppLogger.ui(
                                'Введено имя: $name, переход к выбору города');

                            // Переход на экран выбора региона
                            Navigator.pushNamed(
                              context,
                              '/region_select',
                              arguments: {
                                'userName': name,
                                'initialCity': widget.initialCity,
                              },
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            'Продолжить',
                            style: AuthScreenStyles.continueButtonTextStyle,
                          ),
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
}
