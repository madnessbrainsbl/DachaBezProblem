import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'scanner_service.dart';
import 'package:dacha_bez_problem/plant_result/plant_result_healthy_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api/scan_service.dart';
import '../services/api/api_exceptions.dart';
import '../services/api/api_client.dart';
import '../services/logger.dart';
import '../models/plant_info.dart';
import '../services/api/achievement_service.dart';
import '../widgets/achievement_notification.dart';
import '../services/achievement_manager.dart';
import '../services/user_preferences_service.dart';
import '../services/image_crop_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

// --- Класс для "вырезания" центральной области ---
class InvertedRoundedRectClipper extends CustomClipper<Path> {
  final double frameWidth;
  final double frameHeight;
  final double borderRadius;

  InvertedRoundedRectClipper(
      {required this.frameWidth, required this.frameHeight, this.borderRadius = 30.0});

  @override
  Path getClip(Size size) {
    // Определяем центральный прямоугольник
    final Rect centerRect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: frameWidth,
      height: frameHeight,
    );
    final RRect centerRRect =
        RRect.fromRectAndRadius(centerRect, Radius.circular(borderRadius));

    // Создаем путь, который покрывает весь экран, а затем вычитаем центральную область
    return Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height)) // Весь экран
      ..addRRect(centerRRect) // Центральная область
      ..fillType = PathFillType.evenOdd; // Вырезаем внутреннюю область
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
// --------------------------------------------------

// --- Класс для отрисовки градиентной рамки ---
class GradientRoundedRectBorderPainter extends CustomPainter {
  final double strokeWidth;
  final double borderRadius;
  final Gradient gradient;

  GradientRoundedRectBorderPainter({
    this.strokeWidth = 2.0,
    this.borderRadius = 30.0,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Определяем прямоугольник и закругленный прямоугольник для рамки
    final Rect rect = Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2,
        size.width - strokeWidth, size.height - strokeWidth);
    final RRect rrect = RRect.fromRectAndRadius(
        rect, Radius.circular(borderRadius - strokeWidth / 2));

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = gradient.createShader(rect); // Применяем градиент к рамке

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
// --------------------------------------------------

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({Key? key}) : super(key: key);

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isProcessing = false;

  // Контроллер для видео кнопки
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;

  final ScannerService _scannerService = ScannerService();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() {
    _videoController = VideoPlayerController.asset(
      'assets/mp4/shar.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )
      ..setVolume(0.0) // Отключаем звук полностью, чтобы избежать лишних логов
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
          });
          _videoController.setLooping(true);
          _videoController.play();
        }
      });
  }

  Future<void> _initializeCamera() async {
    try {
      // Получаем список доступных камер
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Камера не найдена на устройстве')),
          );
        }
        return;
      }

      // Инициализируем камеру с задней камерой (если доступна)
      final backCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print('Ошибка инициализации камеры: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось инициализировать камеру: $e')),
        );
      }
    }
  }

  // Новый метод для захвата изображения и перехода на экран обработки
  Future<void> _captureImage() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Делаем снимок
      final XFile photo = await _cameraController!.takePicture();
      
      print('🖼️ ==== НАЧАЛО ПРОЦЕССА КРОПА ====');
      print('📷 Фото сделано: ${photo.path}');
      
      // НОВОЕ: Создаем кроп изображения согласно рамке фокусировки
      final Size screenSize = MediaQuery.of(context).size;
      final double frameWidth = screenSize.width * 0.9;
      final double frameHeight = screenSize.height * 0.7;
      print('📱 Размер экрана: ${screenSize.width}x${screenSize.height}');
      
      final String cropPath = await ImageCropService.createCropFromFrame(
        originalImagePath: photo.path,
        screenSize: screenSize,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
      );
      
      print('✅ Кроп создан: $cropPath');
      print('🖼️ ==== КРОП СОЗДАН УСПЕШНО ====');

      // Переходим на экран обработки с настоящим AI
      // Передаем как оригинальное фото, так и кроп
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageProcessingScreen(
              imageFile: File(photo.path),
              cropFile: File(cropPath), // НОВОЕ: передаем кроп
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Ошибка при захвате снимка: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при захвате изображения: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Делаем снимок
      final XFile photo = await _cameraController!.takePicture();

      // Обрабатываем снимок
      final result = await _scannerService.processImage(File(photo.path));

      if (mounted && result['success'] == true) {
        // Показываем результат в диалоге
        _showResultDialog(result['plantInfo']);
      }
    } catch (e) {
      print('Ошибка при захвате снимка: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при захвате изображения: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showResultDialog(Map<String, dynamic> plantInfo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text('Растение распознано'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Название: ${plantInfo['name']}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 5),
              Text('Латинское название: ${plantInfo['scientificName']}'),
              SizedBox(height: 5),
              Text('Состояние: ${plantInfo['health']}'),
              SizedBox(height: 10),
              Text('Рекомендации:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...List<Widget>.from(
                (plantInfo['recommendations'] as List<String>).map(
                  (rec) => Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text(rec)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Закрыть'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Добавить в мои растения'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Возвращаемся на главный экран
              },
            ),
          ],
        );
      },
    );
  }

  // Добавляем новый метод для выбора фото из галереи
  Future<void> _pickImageFromGallery() async {
    print('🖼️ ==== НАЧАЛО ВЫБОРА ФОТО ИЗ ГАЛЕРЕИ ====');
    final ImagePicker picker = ImagePicker();
    print('📷 ImagePicker создан');
    
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90, // Высокое качество
    );
    print('📸 Результат выбора фото: ${pickedFile == null ? "ФОТО НЕ ВЫБРАНО" : "Выбрано фото: ${pickedFile.path}"}');

    if (pickedFile != null) {
      print('🖼️ ==== НАЧАЛО ПРОЦЕССА КРОПА ДЛЯ ГАЛЕРЕИ ====');
      
      try {
        // НОВОЕ: Создаем кроп для фото из галереи тоже
        final Size screenSize = MediaQuery.of(context).size;
        final double frameWidth = screenSize.width * 0.9;
        final double frameHeight = screenSize.height * 0.7;
        print('📱 Размер экрана: ${screenSize.width}x${screenSize.height}');
        
        final String cropPath = await ImageCropService.createCropFromFrame(
          originalImagePath: pickedFile.path,
          screenSize: screenSize,
          frameWidth: frameWidth,
          frameHeight: frameHeight,
        );
        
        print('✅ Кроп из галереи создан: $cropPath');
        
        // Передаем выбранное фото на экран обработки
        if (mounted) {
          print('🚀 Переход на экран ImageProcessingScreen с файлом: ${pickedFile.path}');
          print('✂️ И кропом: $cropPath');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ImageProcessingScreen(
                imageFile: File(pickedFile.path),
                cropFile: File(cropPath), // НОВОЕ: передаем кроп
              ),
            ),
          );
        }
        
      } catch (e) {
        print('❌ Ошибка при создании кропа из галереи: $e');
        
        // Если кроп не удался, передаем без кропа
        if (mounted) {
          print('⚠️ Переход без кропа из-за ошибки');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ImageProcessingScreen(
                imageFile: File(pickedFile.path),
              ),
            ),
          );
        }
      }
    }
    print('🖼️ ==== ЗАВЕРШЕНИЕ ВЫБОРА ФОТО ИЗ ГАЛЕРЕИ ====');
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Размер центральной рамки (прямоугольник)
    final screenSize = MediaQuery.of(context).size;
    final double frameWidth = screenSize.width * 0.9;
    final double frameHeight = screenSize.height * 0.7;

    return Scaffold(
      body: Stack(
        children: [
          // Фон с серым цветом (на случай если камера не инициализирована)
          Container(
            color: const Color(0xFFAFB4A5),
          ),

          // Камера на весь экран (если инициализирована)
          if (_isCameraInitialized && _cameraController != null)
            Positioned.fill(
              child: AspectRatio(
                // Используем aspect ratio контроллера, чтобы избежать искажений
                aspectRatio: _cameraController!.value.aspectRatio,
                // Оборачиваем CameraPreview в FittedBox, чтобы он заполнил AspectRatio
                child: FittedBox(
                  fit: BoxFit.cover, // Масштабируем, чтобы покрыть всю область
                  child: SizedBox(
                    // SizedBox нужен для задания размера для FittedBox
                    width: _cameraController!
                        .value.previewSize!.height, // Размеры из превью
                    height: _cameraController!.value.previewSize!.width,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
            ),

          // Слой затемнения по краям (поверх камеры)
          ClipPath(
            clipper: InvertedRoundedRectClipper(
                frameWidth: frameWidth, frameHeight: frameHeight, borderRadius: 30.0),
            child: Container(
              color:
                  Colors.black.withOpacity(0.4), // Полупрозрачный черный цвет
            ),
          ),

          // Центральная рамка фокусировки (поверх затемнения)
          Center(
            child: CustomPaint(
              size: Size(frameWidth, frameHeight),
              painter: GradientRoundedRectBorderPainter(
                strokeWidth:
                    2.0, // Можно немного увеличить для заметности, например 2.5 или 3.0
                borderRadius: 30.0,
                gradient: const SweepGradient(
                  // Центр градиента совпадает с центром рамки
                  center: Alignment.center,
                  // Начинаем с середины правой стороны (0.0)
                  colors: [
                    // Углы будут яркими, середины сторон - прозрачными
                    Colors.transparent, // 0.0   (Середина Правой стороны)
                    Color(
                        0xFFD4FFC0), // 0.125 (Угол Нижний Правый) - Светло-зеленый
                    Colors.transparent, // 0.25  (Середина Нижней стороны)
                    Color(0xFF91FF5E), // 0.375 (Угол Нижний Левый) - Зеленый
                    Colors.transparent, // 0.5   (Середина Левой стороны)
                    Color(0xFFFFFFFF), // 0.625 (Угол Верхний Левый) - Белый
                    Colors.transparent, // 0.75  (Середина Верхней стороны)
                    Color(
                        0xFFD4FFC0), // 0.875 (Угол Верхний Правый) - Светло-зеленый
                    Colors.transparent, // 1.0   (Середина Правой стороны)
                  ],
                  stops: [
                    0.0, // Середина Правой стороны
                    0.125, // Угол НП
                    0.25, // Середина Нижней стороны
                    0.375, // Угол НЛ
                    0.5, // Середина Левой стороны
                    0.625, // Угол ВЛ
                    0.75, // Середина Верхней стороны
                    0.875, // Угол ВП
                    1.0, // Завершение на середине Правой стороны
                  ],
                  // Убираем transform, т.к. настроили цвета по нужным углам
                  // transform: GradientRotation(math.pi / 2),
                ),
              ),
            ),
          ),

          // Верхние кнопки и текст
          SafeArea(
            child: Padding(
              // Увеличиваем вертикальный отступ, чтобы опустить крестик
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start, // Выравнивание по левому краю
                children: [
                  // Верхняя полоса с кнопкой закрытия
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start, // Кнопка слева
                    children: [
                      // Крестик для закрытия экрана
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: EdgeInsets.all(
                              8), // Небольшой отступ для удобства нажатия
                          child: Image.asset(
                            'assets/images/camera/krestik_camera.png', // Новый ассет
                            width: 24, // Размер иконки по дизайну
                            height: 24,
                            color: Colors.white, // Оставляем белый цвет
                          ),
                        ),
                      ),
                    ],
                  ),

                  Spacer(), // Занимает всё доступное пространство

                  // Нижняя панель с кнопками
                  Container(
                    height: 80,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30), // Увеличил горизонтальный паддинг
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Левая кнопка (галерея) - меняем обработчик нажатия
                        InkWell(
                          onTap: _pickImageFromGallery, // Используем новый метод
                          child: Image.asset(
                            'assets/images/camera/gallery.png', // Новый ассет
                            width: 32, // Размер иконки по дизайну
                            height: 32,
                            color: Colors.white, // Цвет иконки
                          ),
                        ),

                        // Центральная кнопка сканирования с видео
                        GestureDetector(
                          onTap: _isProcessing ? null : _captureImage,
                          child: Container(
                            width: 70,
                            height: 70,
                            child: Center(
                              child: _isProcessing
                                  ? SizedBox(
                                      width: 54,
                                      height: 54,
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF91FF5E),
                                        strokeWidth: 2, // Уменьшил толщину
                                      ),
                                    )
                                  : ClipOval(
                                      child: _isVideoInitialized
                                          ? VideoPlayer(_videoController)
                                          : Container(
                                              width: 70,
                                              height: 70,
                                              color: Color(0xFF91FF5E),
                                            ),
                                    ),
                            ),
                          ),
                        ),

                        // Правая кнопка (вспышка)
                        InkWell(
                          onTap: () {
                            // TODO: Добавить логику включения/выключения вспышки
                            print("Flash tapped");
                          },
                          child: Image.asset(
                            'assets/images/camera/molniya.png', // Новый ассет
                            width: 32, // Размер иконки по дизайну
                            height: 32,
                            color: Colors.white, // Цвет иконки
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20), // Отступ снизу
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Класс для экрана обработки изображения
class ImageProcessingScreen extends StatefulWidget {
  final File imageFile;
  final File? cropFile; // НОВОЕ: кроп изображения
  
  const ImageProcessingScreen({Key? key, required this.imageFile, this.cropFile}) : super(key: key);

  @override
  State<ImageProcessingScreen> createState() => _ImageProcessingScreenState();
}

class _ImageProcessingScreenState extends State<ImageProcessingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isProcessingDone = false;
  bool _isProcessing = true; // Флаг для отслеживания состояния обработки
  
  String _errorMessage = ''; // Сообщение об ошибке
  Map<String, dynamic>? _scanResult; // Результат сканирования
  
  final ScanService _scanService = ScanService(); // Экземпляр сервиса сканирования
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    // Вместо имитации - реальный запрос к API
    _scanPlantImage();
  }
  
  // Метод для сканирования растения
  Future<void> _scanPlantImage() async {
    print('🌟 ===== НАЧАЛО СКАНИРОВАНИЯ В ImageProcessingScreen =====');
    print('📱 ImageProcessingScreen: НАЧАЛО СКАНИРОВАНИЯ РАСТЕНИЯ');
    print('📸 Файл изображения: ${widget.imageFile.path}');
    print('📏 Размер файла: ${await widget.imageFile.length()} байт');
    
    try {
      // ИСПРАВЛЕНИЕ: Используем новый метод для получения токена с проверкой состояния
      print('🔐 ImageProcessingScreen: Получение токена с проверкой состояния авторизации...');
      
      // ДИАГНОСТИКА: Получаем детальную информацию о токене
      final tokenInfo = await ApiClient.getTokenInfo();
      print('📊 Диагностика токена: $tokenInfo');
      
      final token = await UserPreferencesService.getAuthToken();
      print('🔐 ImageProcessingScreen: Токен получен: ${token == null || token.isEmpty ? "ТОКЕН ПУСТОЙ ИЛИ НЕДЕЙСТВИТЕЛЕН!" : "Токен длиной ${token.length}"}');
      
      if (token == null || token.isEmpty) {
        print('❌ ImageProcessingScreen: Ошибка - токен отсутствует или недействителен.');
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Необходимо войти в аккаунт заново. Сессия истекла.';
        });
        
        // Показываем диалог и перенаправляем на авторизацию
        _showAuthErrorDialog();
        return;
      }
      
      // Получаем информацию об устройстве (безопасно для Web)
      final deviceInfo = (() {
        if (kIsWeb) return 'Web';
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            return 'Android';
          case TargetPlatform.iOS:
            return 'iOS';
          case TargetPlatform.macOS:
            return 'macOS';
          case TargetPlatform.windows:
            return 'windows';
          case TargetPlatform.linux:
            return 'linux';
          default:
            return 'unknown';
        }
      })();
      print('📱 ImageProcessingScreen: Информация об устройстве: $deviceInfo');
      
      AppLogger.api('ImageProcessingScreen: Начинаем запрос на сканирование растения...');
      print('🚀 ImageProcessingScreen: Вызов _scanService.scanPlant...');
      
      // Отправляем запрос на API
      print('⏳ ImageProcessingScreen: Отправляем изображение на сервер...');
      final result = await _scanService.scanPlant(
        imageFile: widget.imageFile,
        cropFile: widget.cropFile, // НОВОЕ: передаем кроп
        token: token,
        deviceInfo: deviceInfo,
      );
      print('✅ ImageProcessingScreen: Ответ от _scanService.scanPlant получен!');
      print('📊 ImageProcessingScreen: Результат сканирования: ${result['success']}');
      
      // Логируем структуру полученного результата
      print('🔍 ===== АНАЛИЗ СТРУКТУРЫ РЕЗУЛЬТАТА =====');
      print('🎯 Success: ${result['success']}');
      print('📝 Message: ${result['message'] ?? "нет сообщения"}');
      
      // Проверяем наличие данных о растении
      if (result.containsKey('plant_info') && result['plant_info'] != null) {
        print('✅ plant_info найден в корне результата');
        final plantInfo = result['plant_info'];
        print('🌱 Название: ${plantInfo['name'] ?? "не указано"}');
        print('🔬 Латинское название: ${plantInfo['latin_name'] ?? "не указано"}');
        print('💚 Здоровое: ${plantInfo['is_healthy'] ?? "не указано"}');
        
        // Проверяем изображения
        if (plantInfo.containsKey('images') && plantInfo['images'] != null) {
          print('🖼️ Изображения найдены в plant_info:');
          final images = plantInfo['images'] as Map<String, dynamic>;
          images.forEach((key, value) {
            print('  $key: ${value ?? "ПУСТОЕ"}');
          });
        } else {
          print('⚠️ Изображения НЕ найдены в plant_info');
        }
      } else if (result.containsKey('data') && result['data'] != null) {
        print('✅ Данные найдены в data');
        final data = result['data'];
        if (data.containsKey('plant_info') && data['plant_info'] != null) {
          print('✅ plant_info найден в data');
          final plantInfo = data['plant_info'];
          print('🌱 Название: ${plantInfo['name'] ?? "не указано"}');
          print('💚 Здоровое: ${plantInfo['is_healthy'] ?? "не указано"}');
        }
      } else {
        print('❌ Данные о растении НЕ найдены в результате!');
      }
      print('🔍 ===== КОНЕЦ АНАЛИЗА СТРУКТУРЫ =====');
      
      if (mounted) {
        print('🎨 ImageProcessingScreen: Обновляем UI - сканирование завершено');
        setState(() {
          _isProcessing = false;
          _isProcessingDone = true;
          _scanResult = result;
        });
        _animationController.stop();
        print('⏹️ ImageProcessingScreen: Анимация остановлена');
        
        // ОБНОВЛЕННЫЙ МЕТОД: Проверка достижений за сканирование с использованием AchievementManager
        print('🏆 ImageProcessingScreen: Проверяем достижения...');
        await _checkScanAchievements(token, result);
        
        AppLogger.api('ImageProcessingScreen: Сканирование завершено успешно. Нажмите "Продолжить" для просмотра результатов.');
        print('🎉 ImageProcessingScreen: Сканирование завершено. Устанавливаем _isProcessingDone = true.');
      }
    } catch (e, stackTrace) {
      AppLogger.error('ImageProcessingScreen: Ошибка при сканировании растения', e);
      print('💥 ImageProcessingScreen: КРИТИЧЕСКАЯ ОШИБКА: $e');
      print('📚 StackTrace: $stackTrace');
      
      // Детальное логирование типа ошибки
      print('🔍 Тип ошибки: ${e.runtimeType}');
      if (e is ServerException) {
        print('🔍 ServerException.message: ${e.message}');
      } else if (e is ApiException) {
        print('🔍 ApiException.message: ${e.message}');
      }
      
      if (mounted) {
        print('❌ ImageProcessingScreen: Обновляем UI - показываем ошибку');
        setState(() {
          _isProcessing = false;
          _errorMessage = _getErrorMessage(e);
        });
        _animationController.stop();
        print('⏹️ ImageProcessingScreen: Анимация остановлена из-за ошибки');
      }
    }
    print('🌟 ===== ЗАВЕРШЕНИЕ СКАНИРОВАНИЯ В ImageProcessingScreen =====');
  }
  
  // Метод для получения понятного сообщения об ошибке
  String _getErrorMessage(dynamic error) {
    print('🔍 _getErrorMessage вызван с ошибкой типа: ${error.runtimeType}');
    print('🔍 Содержимое ошибки: $error');
    
    if (error is NoInternetException) {
      return 'Нет соединения с интернетом. Проверьте подключение и попробуйте снова.';
    } else if (error is ApiTimeoutException) {
      return 'Время обработки истекло. Нейросеть может быть перегружена. Попробуйте позже.';
    } else if (error is BadRequestException) {
      return 'Неверный формат запроса: ${error.message}';
    } else if (error is UnauthorizedException) {
      return 'Необходима авторизация. Пожалуйста, войдите в аккаунт заново.';
    } else if (error is ServerException) {
      // Показываем детальное сообщение из ServerException
      final msg = error.message;
      print('🔍 ServerException.message: $msg');
      
      // Если это проблема с API распознавания
      if (msg.contains('Сервис распознавания временно недоступен')) {
        return msg; // Уже понятное сообщение
      }
      
      // Если это старое сообщение об ошибке анализа
      if (msg.contains('Ошибка при анализе растения')) {
        return 'Не удалось распознать растение. Попробуйте:\n• Сфотографировать растение крупнее\n• Улучшить освещение\n• Выбрать другое фото';
      }
      
      return msg;
    } else {
      // Для неизвестных ошибок показываем более понятное сообщение
      final errorStr = error.toString();
      if (errorStr.contains('SocketException') || errorStr.contains('Connection')) {
        return 'Проблема с подключением к серверу. Проверьте интернет и попробуйте снова.';
      }
      return 'Не удалось обработать изображение. Попробуйте снова или выберите другое фото.';
    }
  }

  // Метод для показа диалога об ошибке авторизации
  void _showAuthErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Сессия истекла',
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          content: Text(
            'Необходимо войти в аккаунт заново для продолжения работы с приложением.',
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Закрываем диалог
                Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
              },
              child: Text(
                'Войти в аккаунт',
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF63A36C),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  // ОБНОВЛЕННЫЙ МЕТОД: Проверка достижений за сканирование с использованием AchievementManager
  Future<void> _checkScanAchievements(String token, Map<String, dynamic> scanResult) async {
    try {
      print('🏆 Проверка достижений за сканирование...');
      
      // Извлекаем данные для метаданных
      String? plantName;
      double? confidence;
      
      // Пытаемся извлечь название растения из результата
      if (scanResult.containsKey('data') && 
          scanResult['data'] != null &&
          scanResult['data'].containsKey('analysis') &&
          scanResult['data']['analysis'] != null &&
          scanResult['data']['analysis'].containsKey('plant_info') &&
          scanResult['data']['analysis']['plant_info'] != null) {
        
        final plantInfo = scanResult['data']['analysis']['plant_info'];
        plantName = plantInfo['name'] ?? plantInfo['common_name'];
        confidence = plantInfo['confidence']?.toDouble();
      } else if (scanResult.containsKey('plant_info') && scanResult['plant_info'] != null) {
        final plantInfo = scanResult['plant_info'];
        plantName = plantInfo['name'] ?? plantInfo['common_name'];
        confidence = plantInfo['confidence']?.toDouble();
      }
      
      print('🏆 Метаданные для достижений: plantName=$plantName, confidence=$confidence');
      
      // Используем AchievementManager для проверки достижений
      final achievementManager = AchievementManager();
      await achievementManager.checkScanAchievements(
        context,
        plantName: plantName,
        confidence: confidence,
        scanType: 'camera',
      );
      
      print('🏆 Проверка достижений завершена');
    } catch (e) {
      print('❌ Ошибка при проверке достижений: $e');
      AppLogger.error('Ошибка проверки достижений за сканирование', e);
      // Не показываем ошибку пользователю, так как это не критично
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Получаем размеры экрана
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFFAFB4A5), // Тот же цвет фона, что и в ScannerScreen
      body: SafeArea(
        child: Stack(
          children: [
            // Верхняя кнопка "назад"
            Positioned(
              top: 15,
              left: 20,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    'assets/images/camera/krestik_camera.png',
                    width: 24,
                    height: 24,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            
            // Центральное содержимое
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Контейнер с изображением (показываем кроп, если доступен)
                  Container(
                    width: screenSize.width * 0.8,
                    height: screenSize.width * 0.8,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(
                        widget.cropFile ?? widget.imageFile, // Показываем кроп, если есть
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Показываем различные состояния UI в зависимости от прогресса
                  if (_isProcessing)
                    // Анимация обработки
                    _buildProcessingUI()
                  else if (_errorMessage.isNotEmpty)
                    // Отображение ошибки
                    _buildErrorUI()
                  else if (_isProcessingDone && _scanResult != null)
                    // Кнопка "Продолжить"
                    _buildResultButton()
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Виджет для отображения анимации обработки
  Widget _buildProcessingUI() {
    return Column(
      children: [
        // Анимированный индикатор
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: const [
                    Colors.transparent,
                    Color(0xFF91FF5E),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                  transform: GradientRotation(_animationController.value * 2 * math.pi),
                ),
              ),
              child: const Center(
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFAFB4A5),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        // Текст "Обработка"
        const Text(
          'Идет обработка, подождите 2–3 минуты',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Gilroy',
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
  
  // Виджет для кнопки продолжения
  Widget _buildResultButton() {
    return ElevatedButton(
      onPressed: () async {
        // Создаем модель PlantInfo из полученного JSON
        try {
          print('🎬 ===== НАЧАЛО ОБРАБОТКИ КНОПКИ "ПРОДОЛЖИТЬ" =====');
          print('📱 Нажата кнопка "Продолжить"');
          print('📊 Полный ответ API для анализа:');
          print(_scanResult);
          
          // Извлекаем данные растения из ответа API
          Map<String, dynamic> plantInfoData;
          String? foundScanId;
          
          print('🔍 ===== ПОИСК ДАННЫХ О РАСТЕНИИ В ОТВЕТЕ =====');
          
          // Проверяем, это ручной ввод или результат сканирования
          final isManualEntry = _scanResult!['manual_entry'] == true;
          print('📝 Ручной ввод: $isManualEntry');
          
          // Новая структура: данные в data.analysis.plant_info
          if (_scanResult!.containsKey('data') && 
              _scanResult!['data'] != null &&
              _scanResult!['data'].containsKey('analysis') &&
              _scanResult!['data']['analysis'] != null &&
              _scanResult!['data']['analysis'].containsKey('plant_info') &&
              _scanResult!['data']['analysis']['plant_info'] != null) {
            
            // Данные растения находятся в data.analysis.plant_info
            plantInfoData = Map<String, dynamic>.from(_scanResult!['data']['analysis']['plant_info']);
            print('✅ Найдены данные растения в новой структуре data.analysis.plant_info');
            print('🌱 Название растения: ${plantInfoData['name'] ?? "НЕ УКАЗАНО"}');
            print('🔬 Латинское название: ${plantInfoData['latin_name'] ?? "НЕ УКАЗАНО"}');
            print('💚 Здоровое: ${plantInfoData['is_healthy'] ?? "НЕ УКАЗАНО"}');
            
            // Ищем scan_id в data
            if (_scanResult!['data'].containsKey('scan_id') && _scanResult!['data']['scan_id'] != null) {
              foundScanId = _scanResult!['data']['scan_id'].toString();
              print('✅ Найден scan_id в data: $foundScanId');
            }
            else {
              print('⚠️ scan_id не найден в data');
            }
          }
          // Старая структура: данные в корне под plant_info
          else if (_scanResult!.containsKey('plant_info') && _scanResult!['plant_info'] != null) {
            // Данные растения находятся прямо в plant_info
            plantInfoData = Map<String, dynamic>.from(_scanResult!['plant_info']);
            print('✅ Найдены данные растения в старой структуре plant_info');
            print('🌱 Название растения: ${plantInfoData['name'] ?? "НЕ УКАЗАНО"}');
            print('🔬 Латинское название: ${plantInfoData['latin_name'] ?? "НЕ УКАЗАНО"}');
            print('💚 Здоровое: ${plantInfoData['is_healthy'] ?? "НЕ УКАЗАНО"}');
            
            // Ищем scan_id в разных местах ответа
            if (_scanResult!.containsKey('scan_id') && _scanResult!['scan_id'] != null) {
              foundScanId = _scanResult!['scan_id'].toString();
              print('✅ Найден scan_id в корне ответа: $foundScanId');
            }
            else if (_scanResult!.containsKey('_id') && _scanResult!['_id'] != null) {
              foundScanId = _scanResult!['_id'].toString();
              print('✅ Найден _id в корне ответа: $foundScanId');
            }
            else {
              print('⚠️ scan_id не найден в старой структуре');
            }
          }
          // Совместимость: данные в data.plant_info
          else if (_scanResult!.containsKey('data') && 
                   _scanResult!['data'] != null &&
                   _scanResult!['data'].containsKey('plant_info') &&
                   _scanResult!['data']['plant_info'] != null) {
            
            // Данные растения находятся в data.plant_info
            plantInfoData = Map<String, dynamic>.from(_scanResult!['data']['plant_info']);
            print('✅ Найдены данные растения в совместимой структуре data.plant_info');
            print('🌱 Название растения: ${plantInfoData['name'] ?? "НЕ УКАЗАНО"}');
            print('🔬 Латинское название: ${plantInfoData['latin_name'] ?? "НЕ УКАЗАНО"}');
            print('💚 Здоровое: ${plantInfoData['is_healthy'] ?? "НЕ УКАЗАНО"}');
            
            // Ищем scan_id в data
            if (_scanResult!['data'].containsKey('scan_id') && _scanResult!['data']['scan_id'] != null) {
              foundScanId = _scanResult!['data']['scan_id'].toString();
              print('✅ Найден scan_id в data: $foundScanId');
            }
            else {
              print('⚠️ scan_id не найден в data');
            }
          } 
          else {
            // Используем данные напрямую (на случай, если структура отличается)
            plantInfoData = Map<String, dynamic>.from(_scanResult!);
            print('⚠️ Неизвестная структура, используем данные напрямую из ответа');
            print('🌱 Название растения: ${plantInfoData['name'] ?? "НЕ УКАЗАНО"}');
            
            // Ищем scan_id везде
            if (_scanResult!.containsKey('scan_id') && _scanResult!['scan_id'] != null) {
              foundScanId = _scanResult!['scan_id'].toString();
              print('✅ Найден scan_id в корне: $foundScanId');
            }
            else if (_scanResult!.containsKey('data') && 
                     _scanResult!['data'] != null &&
                     _scanResult!['data'].containsKey('scan_id') &&
                     _scanResult!['data']['scan_id'] != null) {
              foundScanId = _scanResult!['data']['scan_id'].toString();
              print('✅ Найден scan_id в data: $foundScanId');
            }
            else {
              print('❌ scan_id не найден нигде');
            }
          }
          
          print('🔍 ===== КОНЕЦ ПОИСКА ДАННЫХ О РАСТЕНИИ =====');
          
          // Проверяем изображения в данных перед созданием PlantInfo
          if (plantInfoData.containsKey('images') && plantInfoData['images'] != null) {
            print('🖼️ ===== ИЗОБРАЖЕНИЯ В ДАННЫХ ДЛЯ PLANTINFO =====');
            final images = plantInfoData['images'] as Map<String, dynamic>;
            images.forEach((key, value) {
              print('  $key: ${value ?? "ПУСТОЕ"}');
              
              // Проверяем доступность каждого изображения
              if (value != null && value.toString().isNotEmpty && value.toString().startsWith('http')) {
                print('  🔍 Быстрая проверка доступности $key...');
                _quickImageCheck(value.toString(), key);
              }
            });
            print('🖼️ ===== КОНЕЦ СПИСКА ИЗОБРАЖЕНИЙ =====');
          } else {
            print('⚠️ Изображения НЕ найдены в данных для PlantInfo!');
          }
          
          // Добавляем найденный scan_id
          if (foundScanId != null && foundScanId.isNotEmpty) {
            plantInfoData['scan_id'] = foundScanId;
            print('🆔 scan_id успешно добавлен в plantInfoData: $foundScanId');
          } else {
            plantInfoData['scan_id'] = '';
            print('❌ scan_id остается пустым в plantInfoData');
          }
          
          print('📦 ===== ФИНАЛЬНЫЕ ДАННЫЕ ДЛЯ СОЗДАНИЯ PLANTINFO =====');
          print('🌱 name: ${plantInfoData['name']}');
          print('🔬 latin_name: ${plantInfoData['latin_name']}');
          print('💚 is_healthy: ${plantInfoData['is_healthy']}');
          print('🆔 scan_id: ${plantInfoData['scan_id']}');
          print('🖼️ images count: ${plantInfoData['images']?.length ?? 0}');
          
          // ИСПРАВЛЕНИЕ: Переносим photo_url в поля images если они пустые
          print('🔧 ===== ИСПРАВЛЕНИЕ ПУСТЫХ ИЗОБРАЖЕНИЙ =====');
          if (_scanResult!.containsKey('data') && 
              _scanResult!['data'] != null &&
              _scanResult!['data'].containsKey('photo_url') &&
              _scanResult!['data']['photo_url'] != null &&
              _scanResult!['data']['photo_url'].toString().isNotEmpty) {
            
            final photoUrl = _scanResult!['data']['photo_url'].toString();
            final fullPhotoUrl = photoUrl.startsWith('http') ? photoUrl : 'http://89.110.92.227:3002$photoUrl';
            
            print('📸 Найден photo_url в data: $photoUrl');
            print('🔗 Полный URL: $fullPhotoUrl');
            
            // Создаем или обновляем объект images
            if (plantInfoData['images'] == null) {
              plantInfoData['images'] = <String, dynamic>{};
              print('🆕 Создан новый объект images');
            }
            
            final images = plantInfoData['images'] as Map<String, dynamic>;
            
            // Заполняем пустые поля изображений
            if (images['user_image'] == null || images['user_image'].toString().isEmpty) {
              images['user_image'] = fullPhotoUrl;
              print('✅ Установлен user_image: $fullPhotoUrl');
            }
            
            if (images['original_image'] == null || images['original_image'].toString().isEmpty) {
              images['original_image'] = fullPhotoUrl;
              print('✅ Установлен original_image: $fullPhotoUrl');
            }
            
            if (images['scan_image'] == null || images['scan_image'].toString().isEmpty) {
              images['scan_image'] = fullPhotoUrl;
              print('✅ Установлен scan_image: $fullPhotoUrl');
            }
            
            if (images['main_image'] == null || images['main_image'].toString().isEmpty) {
              images['main_image'] = fullPhotoUrl;
              print('✅ Установлен main_image: $fullPhotoUrl');
            }
            
            if (images['thumbnail'] == null || images['thumbnail'].toString().isEmpty) {
              images['thumbnail'] = fullPhotoUrl;
              print('✅ Установлен thumbnail: $fullPhotoUrl');
            }
            
            // Обновляем plantInfoData
            plantInfoData['images'] = images;
            print('🔄 Обновлены данные plantInfoData с новыми изображениями');
            
            // Проверяем доступность изображения
            print('🔍 Проверяем доступность нового изображения...');
            _quickImageCheck(fullPhotoUrl, 'исправленное_изображение');
          } else {
            print('⚠️ photo_url не найден в data или пустой');
          }
          print('🔧 ===== КОНЕЦ ИСПРАВЛЕНИЯ ПУСТЫХ ИЗОБРАЖЕНИЙ =====');
          
          // НОВОЕ: Добавляем кроп в изображения если он существует
          print('✂️ ===== ДОБАВЛЕНИЕ КРОПА В ИЗОБРАЖЕНИЯ =====');
          if (widget.cropFile != null && await widget.cropFile!.exists()) {
            print('✅ Найден файл кропа: ${widget.cropFile!.path}');
            
            // Создаем или обновляем объект images
            if (plantInfoData['images'] == null) {
              plantInfoData['images'] = <String, dynamic>{};
              print('🆕 Создан новый объект images для кропа');
            }
            
            final images = plantInfoData['images'] as Map<String, dynamic>;
            
            // Добавляем кроп, но НЕ перезаписываем серверные HTTP URLs
            final cropPath = widget.cropFile!.path;
            
            // Добавляем локальный кроп только если нет серверного
            if (images['crop'] == null || images['crop'].toString().isEmpty || !images['crop'].toString().startsWith('http')) {
              images['crop'] = cropPath;
              print('✅ Добавлен локальный crop: $cropPath');
            } else {
              print('🔗 Используем серверный crop: ${images['crop']}');
            }
            
            // Для thumbnail используем серверный, если есть
            if (images['thumbnail'] == null || images['thumbnail'].toString().isEmpty || !images['thumbnail'].toString().startsWith('http')) {
              images['thumbnail'] = cropPath;
              print('✅ Добавлен локальный thumbnail: $cropPath');
            } else {
              print('🔗 Используем серверный thumbnail: ${images['thumbnail']}');
            }
            
            // Обновляем plantInfoData
            plantInfoData['images'] = images;
            print('🔄 Данные plantInfoData обновлены с кропом');
          } else {
            print('⚠️ Файл кропа отсутствует или недоступен');
            if (widget.cropFile != null) {
              print('  Путь к кропу: ${widget.cropFile!.path}');
              print('  Файл существует: ${await widget.cropFile!.exists()}');
            } else {
              print('  widget.cropFile == null');
            }
          }
          print('✂️ ===== КОНЕЦ ДОБАВЛЕНИЯ КРОПА =====');
          
          print('📦 ===== КОНЕЦ ФИНАЛЬНЫХ ДАННЫХ =====');
          
          print('🔨 Создаем PlantInfo из данных...');
          final plantInfo = PlantInfo.fromJson(plantInfoData);
          print('✅ PlantInfo создан успешно!');
          print('🆔 PlantInfo.scanId: "${plantInfo.scanId}"');
          print('🌱 PlantInfo.name: "${plantInfo.name}"');
          print('💚 PlantInfo.isHealthy: ${plantInfo.isHealthy}');
          print('🖼️ PlantInfo.images: ${plantInfo.images.keys.join(", ")}');
          
          // Переходим на экран результатов с данными о растении
          print('🚀 Переходим на PlantResultHealthyScreen...');
          print('📱 isHealthy: ${plantInfo.isHealthy}');
          print('📱 plantData: PlantInfo объект передается');
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlantResultHealthyScreen(
                isHealthy: plantInfo.isHealthy,
                plantData: plantInfo,
                fromScanHistory: false, // Вызов ПОСЛЕ сканирования
              ),
            ),
          ).then((_) {
            // Когда возвращаемся с экрана результата
            AppLogger.ui('🔄 Возврат с PlantResultHealthyScreen в ScannerScreen');
            // Можно добавить любую логику обновления, если нужно
          });
          
          print('✅ Переход на PlantResultHealthyScreen выполнен!');
          print('🎬 ===== КОНЕЦ ОБРАБОТКИ КНОПКИ "ПРОДОЛЖИТЬ" =====');
        } catch (e) {
          AppLogger.error('Ошибка при парсинге данных о растении', e);
          print('💥 КРИТИЧЕСКАЯ ОШИБКА при создании PlantInfo: $e');
          print('📊 Stack trace: ${e.toString()}');
          setState(() {
            _errorMessage = 'Не удалось обработать данные о растении. Пожалуйста, попробуйте снова.';
          });
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF91FF5E),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      ),
      child: const Text(
        'Продолжить',
        style: TextStyle(
          fontFamily: 'Gilroy',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  
  // Виджет для отображения ошибки
  Widget _buildErrorUI() {
    // Проверяем, является ли ошибка проблемой сервера распознавания
    final isRecognitionError = _errorMessage.contains('Сервис распознавания') || 
                                _errorMessage.contains('Не удалось распознать');
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.error_outline,
          color: Colors.white,
          size: 50,
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Gilroy',
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 30),
        // Кнопка повторить
        ElevatedButton(
          onPressed: () {
            setState(() {
              _isProcessing = true;
              _errorMessage = '';
              _animationController.repeat();
            });
            _scanPlantImage();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF91FF5E),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          ),
          child: const Text(
            'Повторить',
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Если ошибка распознавания - предлагаем ручной ввод
        if (isRecognitionError) ...[
          const SizedBox(height: 15),
          TextButton(
            onPressed: () {
              _showManualPlantEntryDialog();
            },
            child: const Text(
              'Ввести название вручную',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Gilroy',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ],
    );
  }
  
  // Диалог ручного ввода названия растения
  void _showManualPlantEntryDialog() {
    final TextEditingController nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Введите название растения',
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Например: Фикус',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                final plantName = nameController.text.trim();
                if (plantName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Введите название растения')),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop();
                _createManualPlantResult(plantName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF63A36C),
              ),
              child: const Text('Продолжить'),
            ),
          ],
        );
      },
    );
  }
  
  // Создаем результат с ручным вводом названия
  void _createManualPlantResult(String plantName) {
    print('📝 Создаем результат с ручным вводом: $plantName');
    
    setState(() {
      _isProcessing = false;
      _isProcessingDone = true;
      _errorMessage = '';
      
      // Создаем минимальный результат для перехода на экран результата
      _scanResult = {
        'success': true,
        'manual_entry': true,
        'plant_info': {
          'name': plantName,
          'latin_name': '',
          'is_healthy': true,
          'description': 'Информация введена вручную',
          'images': {
            'original': widget.imageFile.path,
          },
        },
      };
    });
    
    _animationController.stop();
    print('✅ Результат с ручным вводом создан');
  }
  
  // Вспомогательный метод для быстрой проверки изображения
  void _quickImageCheck(String imageUrl, String imageKey) async {
    try {
      print('    🔍 Проверяем $imageKey: $imageUrl');
      final response = await http.head(Uri.parse(imageUrl)).timeout(Duration(seconds: 2));
      if (response.statusCode == 200) {
        print('    ✅ $imageKey ДОСТУПНО (${response.statusCode})');
      } else {
        print('    ⚠️ $imageKey НЕДОСТУПНО (${response.statusCode})');
      }
    } catch (e) {
      print('    ❌ Ошибка проверки $imageKey: $e');
    }
  }
}
