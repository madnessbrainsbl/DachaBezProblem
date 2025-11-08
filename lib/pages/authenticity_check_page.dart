import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../homepage/BottomNavigationComponent.dart';
import '../homepage/home_screen.dart';
import '../scanner/scanner_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class AuthenticityCheckPage extends StatefulWidget {
  const AuthenticityCheckPage({Key? key}) : super(key: key);

  @override
  State<AuthenticityCheckPage> createState() => _AuthenticityCheckPageState();
}

class _AuthenticityCheckPageState extends State<AuthenticityCheckPage> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  File? _image;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _getImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Выберите источник'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  child: Text('Камера'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _getImage(ImageSource.camera);
                  },
                ),
                Padding(padding: EdgeInsets.all(8.0)),
                GestureDetector(
                  child: Text('Галерея'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _getImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Расширяем body под нижнюю навигацию
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE0F2D0),
              Color(0xFFC1E5AE),
              Color(0xFFABDC95),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Основной контент
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Верхняя часть с заголовком
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: SvgPicture.asset(
                            'assets/images/favorites/back_arrow.svg',
                            width: 24,
                            height: 24,
                            color: Color(0xFF63A36C),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Проверка подлинности',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.005,
                            color: Color(0xFF1F2024),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Основной контент с прокруткой
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: 16),
                            // Текст над полем ввода
                            Text(
                              'Уникальный код препарата',
                              style: TextStyle(
                                color: Color(0xFF63A36C),
                                fontSize: 14,
                                fontFamily: 'Gilroy',
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 10),

                            // Поле для ввода кода
                            Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(50),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x1931873F),
                                    blurRadius: 20,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      child: TextField(
                                        controller: _codeController,
                                        focusNode: _codeFocus,
                                        textAlign: TextAlign.center,
                                        decoration: InputDecoration(
                                          hintText: 'Введите 10 значный код',
                                          hintStyle: TextStyle(
                                            fontFamily: 'Gilroy',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFFDDDDDD),
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        style: TextStyle(
                                          fontFamily: 'Gilroy',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.black,
                                        ),
                                        keyboardType: TextInputType.number,
                                        maxLength: 10,
                                        buildCounter: (BuildContext context,
                                            {required int currentLength,
                                            required bool isFocused,
                                            required int? maxLength}) {
                                          return null; // скрываем счетчик символов
                                        },
                                      ),
                                    ),
                                  ),
                                  // Иконка карандаша для фокуса на ввод
                                  Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: InkWell(
                                      onTap: () {
                                        // Устанавливаем фокус на текстовое поле
                                        FocusScope.of(context)
                                            .requestFocus(_codeFocus);
                                      },
                                      child: SvgPicture.asset(
                                        'assets/images/authenticity/edit_icon.svg',
                                        width: 18,
                                        height: 18,
                                        color: Color(0xFF63A36C),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),

                            // Область для изображения
                            GestureDetector(
                              onTap: _showImageSourceDialog,
                              child: Container(
                                width: double.infinity,
                                height: 229,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x1931873F),
                                      blurRadius: 20,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: _image != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: Image.file(
                                          _image!,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Center(
                                        child: SvgPicture.asset(
                                          'assets/images/authenticity/image_placeholder.svg',
                                          width: 48,
                                          height: 48,
                                          color: Color(0xFFD1E7C4),
                                        ),
                                      ),
                              ),
                            ),
                            SizedBox(height: 16),

                            // Пояснительный текст
                            Text(
                              'Уникальный код препарата должен выглядеть так,\nнаходится на обратной стороне упаковки',
                              style: TextStyle(
                                fontFamily: 'Gilroy',
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF232323),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 32),

                            // Кнопка проверки
                            Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(-0.00, -1.00),
                                  end: Alignment(0, 1),
                                  colors: [
                                    Color(0xFF78B065),
                                    Color(0xFF388D78)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x1931873F),
                                    blurRadius: 20,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    // Логика проверки подлинности
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('Проверка подлинности...')),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(30),
                                  child: Center(
                                    child: Text(
                                      'Проверить подлинность',
                                      style: TextStyle(
                                        fontFamily: 'Gilroy',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Градиентный фон для плавного перехода
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 120,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00ABDC95), // Полностью прозрачный вначале
                        Color(
                            0xFFABDC95), // Такой же цвет как в конце основного градиента
                      ],
                      stops: [0.0, 0.5],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Colors.transparent,
        ),
        child: BottomNavigationComponent(
          selectedIndex: 3, // Индекс текущей вкладки
          onItemTapped: (index) {
            if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ScannerScreen()),
              );
              return;
            }
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => HomeScreen(initialIndex: index)),
            );
          },
        ),
      ),
    );
  }
}
