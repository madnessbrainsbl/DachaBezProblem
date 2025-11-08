import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../homepage/UsefulInfoComponent.dart';
import '../homepage/BottomNavigationComponent.dart';
import '../homepage/home_screen.dart';
import '../scanner/scanner_screen.dart';
import '../services/api/user_service.dart';
import '../models/user_profile.dart';
import '../services/logger.dart';
import '../services/api/api_exceptions.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final UserService _userService = UserService();
  
  // Контроллеры для текстовых полей
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  // FocusNode для каждого поля ввода
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _cityFocus = FocusNode();

  // Состояние загрузки
  bool _isLoading = true;
  bool _isSaving = false;
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
      });

      AppLogger.ui('Загрузка профиля пользователя для настроек');
      
      // Сначала пробуем загрузить из кэша
      final cachedProfile = await _userService.getCachedProfile();
      if (cachedProfile != null) {
        _populateFields(cachedProfile);
        setState(() {
          _userProfile = cachedProfile;
          _isLoading = false;
        });
      }

      // Затем загружаем свежие данные с сервера
      final profile = await _userService.getUserProfile();
      if (profile != null) {
        _populateFields(profile);
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
        // Сохраняем в кэш
        await _userService.cacheProfile(profile);
        AppLogger.ui('Профиль пользователя загружен для настроек: ${profile.displayName}');
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('Ошибка загрузки профиля пользователя в настройках', e);
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        _showErrorSnackBar('Не удалось загрузить данные профиля');
      }
    }
  }

  void _populateFields(UserProfile profile) {
    _nameController.text = profile.name ?? '';
    _emailController.text = profile.email ?? '';
    _phoneController.text = profile.phone ?? '';
    _cityController.text = profile.city ?? '';
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    try {
      setState(() {
        _isSaving = true;
      });

      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();
      final city = _cityController.text.trim();

      // Бэкенд требует имя И город вместе
      if (name.isEmpty || city.isEmpty) {
        if (mounted) {
          _showErrorSnackBar('Необходимо указать имя и город');
        }
        return;
      }

      AppLogger.ui('Сохранение профиля: name=$name, email=$email, phone=$phone, city=$city');

      final success = await _userService.updateUserProfile(
        name: name,
        city: city,
        email: email.isNotEmpty ? email : null,
        phone: phone.isNotEmpty ? phone : null,
      );

      if (success) {
        if (mounted) {
          _showSuccessSnackBar('Настройки успешно сохранены');
          // Перезагружаем данные профиля
          await _loadUserProfile();
        }
      } else {
        if (mounted) {
          _showErrorSnackBar('Не удалось сохранить настройки');
        }
      }
    } on UnauthorizedException catch (e) {
      AppLogger.error('Ошибка авторизации при сохранении профиля', e);
      if (mounted) {
        _showErrorSnackBar('Необходимо войти в аккаунт заново');
        // Не делаем автоматический переход, пользователь сам решит
      }
    } on ServerException catch (e) {
      AppLogger.error('Ошибка сервера при сохранении профиля', e);
      if (mounted) {
        _showErrorSnackBar('Ошибка сервера: ${e.message}');
      }
    } on NoInternetException catch (e) {
      AppLogger.error('Ошибка сети при сохранении профиля', e);
      if (mounted) {
        _showErrorSnackBar('Ошибка сети: ${e.message}');
      }
    } catch (e) {
      AppLogger.error('Неизвестная ошибка при сохранении профиля', e);
      if (mounted) {
        _showErrorSnackBar('Ошибка: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Color(0xFF63A36C),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _cityFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Расширяем body под нижнюю навигацию
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(0.00, -1.00),
            end: Alignment(0, 1),
            colors: [Color(0xFFEAF5DA), Color(0xFFB6DFA3)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Верхняя часть с заголовком
              Positioned(
                left: 16,
                top: 16,
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
                    SizedBox(width: 16),
                    Text(
                      'Настройки',
                      style: TextStyle(
                        color: Color(0xFF1F2024),
                        fontSize: 18,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.005,
                      ),
                    ),
                  ],
                ),
              ),

              // Основной контент - форма настроек
              Positioned(
                left: 0,
                top: 60,
                right: 0,
                bottom: 0, // Убираем фиксированный отступ
                child: _isLoading 
                  ? _buildLoadingIndicator()
                  : SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 260, // Отступ снизу для полезной информации и навигации
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: 16),
                          // Поле для имени
                          _buildFieldLabel('Имя'),
                          SizedBox(height: 8),
                          _buildInputField(context, _nameController, _nameFocus,
                              'Имя пользователя'),
                          SizedBox(height: 24),

                          // Поле для почты
                          _buildFieldLabel('Почта'),
                          SizedBox(height: 8),
                          _buildInputField(context, _emailController, _emailFocus,
                              'user@example.com'),
                          SizedBox(height: 24),

                          // Поле для номера телефона
                          _buildFieldLabel('Номер телефона'),
                          SizedBox(height: 8),
                          _buildInputField(context, _phoneController, _phoneFocus,
                              '+7 (999) 123-45-67'),
                          SizedBox(height: 24),

                          // Поле для города
                          _buildFieldLabel('Город'),
                          SizedBox(height: 8),
                          _buildInputField(context, _cityController, _cityFocus,
                              'Москва'),
                          SizedBox(height: 40),

                          // Кнопка "Сохранить"
                          _buildSaveButton(context),
                          SizedBox(height: 20), // Дополнительный отступ после кнопки
                        ],
                      ),
                    ),
              ),

              // Градиентный фон для плавного перехода в UsefulInfoComponent
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 240,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(0.00, -1.00),
                      end: Alignment(0, 1),
                      colors: [
                        Color(0x00C7E6B5),
                        Color(0xFFC2E3B0),
                        Color(0xFFB7DFA5)
                      ],
                    ),
                  ),
                ),
              ),

              // Позиционируем компонент с полезной информацией
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: UsefulInfoComponent(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationComponent(
        selectedIndex: 3, // Соответствует индексу "Моя дача" в BottomNavigation
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
    );
  }

  // Метка поля формы
  Widget _buildFieldLabel(String label) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Gilroy',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Color(0xFF63A36C),
          letterSpacing: 0.01,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // Поле ввода с иконкой карандаша
  Widget _buildInputField(BuildContext context,
      TextEditingController controller, FocusNode focusNode, String hintText) {
    return Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          // Иконка карандаша для фокуса на ввод
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: () {
                // Устанавливаем фокус на текстовое поле
                FocusScope.of(context).requestFocus(focusNode);
              },
              child: SvgPicture.asset(
                'assets/images/my_dacha/karandashek.svg',
                width: 18,
                height: 18,
                color: Color(0xFF63A36C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Индикатор загрузки
  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF63A36C)),
          ),
          SizedBox(height: 16),
          Text(
            'Загрузка данных...',
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF63A36C),
            ),
          ),
        ],
      ),
    );
  }

  // Кнопка сохранения
  Widget _buildSaveButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: _isSaving
            ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade500])
            : LinearGradient(
                begin: Alignment(0.5, -0.95),
                end: Alignment(0.5, 2.0),
                colors: [Color(0xFF78B065), Color(0xFF388D79)],
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
          onTap: _isSaving ? null : _saveProfile,
          borderRadius: BorderRadius.circular(30),
          child: Center(
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Сохранить',
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
    );
  }
}
