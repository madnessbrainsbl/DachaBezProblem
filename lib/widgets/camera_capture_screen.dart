import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:video_player/video_player.dart';
import '../services/image_crop_service.dart';

/// Экран кастомной камеры, который повторяет UI сканера с рамкой.
/// После съёмки показывает превью с возможностью «Переснять» или «Использовать фото».
/// Возвращает строку с путём к сделанному фото через Navigator.pop(context, path).
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({Key? key}) : super(key: key);

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _cameraUnavailable = false; // Эмулятор без камеры
  XFile? _capturedFile;
  List<CameraDescription> _cameras = [];

  // Размер рамки (квадрат) как в сканере
  static const double _frameSize = 300;

  // Анимированный шарик
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    print('▶ CameraCaptureScreen.initState');
    _initializeVideoPlayer();
    _initCamera();
    // Не блокируем ориентацию — на iOS это может давать чёрный экран превью
  }

  @override
  void dispose() {
    _controller?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    print('⚙️ [_initCamera] старт');
    try {
      _cameras = await availableCameras();
      print('⚙️ [_initCamera] найдено камер: ${_cameras.length}');
      if (_cameras.isEmpty) {
        print('❌ [_initCamera] список камер пуст');
        if (!mounted) return;
        setState(() {
          _cameraUnavailable = true;
        });
        return;
      }
      final back = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      _controller = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await _controller!.initialize();
      print('✅ [_initCamera] CameraController.initialize() завершился. isInitialized=${_controller!.value.isInitialized}');
      if (_controller!.value.isInitialized) {
        try {
          await _controller!.setFocusMode(FocusMode.auto);
          print('✅ [_initCamera] setFocusMode(AUTO) установлен');
        } catch (e) {
          print('⚠️ [_initCamera] setFocusMode error: $e');
        }
      }
      if (!mounted) return;
      setState(() => _isCameraInitialized = true);
      print('✅ [_initCamera] _isCameraInitialized = true');
    } catch (e) {
      print('❌ [_initCamera] Exception: $e');
      if (!mounted) return;
      setState(() {
        _cameraUnavailable = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Камера недоступна: $e')),
      );
    }
  }

  Future<void> _takePicture() async {
    if (!_isCameraInitialized || _controller == null || _controller!.value.isTakingPicture) return;
    try {
      final XFile file = await _controller!.takePicture();
      if (!mounted) return;
      setState(() {
        _capturedFile = file;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сделать фото: $e')),
      );
    }
  }

  void _retake() {
    setState(() {
      _capturedFile = null;
    });
  }

  void _usePhoto() {
    if (_capturedFile != null) {
      () async {
        try {
          final screenSize = MediaQuery.of(context).size;
          final frameWidth = screenSize.width * 0.9;
          final frameHeight = screenSize.height * 0.7;
          final cropPath = await ImageCropService.createCropFromFrame(
            originalImagePath: _capturedFile!.path,
            screenSize: screenSize,
            frameWidth: frameWidth,
            frameHeight: frameHeight,
          );
          if (!mounted) return;
          Navigator.of(context).pop(cropPath);
        } catch (e) {
          if (!mounted) return;
          Navigator.of(context).pop(_capturedFile!.path);
        }
      }();
    }
  }

  void _initializeVideoPlayer() {
    _videoController = VideoPlayerController.asset(
      'assets/mp4/shar.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )
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

  @override
  Widget build(BuildContext context) {
    print('📐 build: _isCameraInitialized=$_isCameraInitialized, captured=${_capturedFile != null}');
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          if (_capturedFile == null) ...[
            // Превью камеры (если доступно) - на весь экран без искажений
            if (_isCameraInitialized)
              Positioned.fill(
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.width * _controller!.value.aspectRatio,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                  ),
                ),
              ),

              // Если камеры нет – фон уже серый (Container выше)
              if (!_isCameraInitialized && !_cameraUnavailable)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF63A36C)),
                ),
              if (_cameraUnavailable)
                Container(color: Colors.grey[800]),

              // Полупрозрачная маска с вырезом (всегда)
              Positioned.fill(
                child: ClipPath(
                  clipper: _InvertedRoundedRectClipper(frameSize: _frameSize),
                  child: Container(color: Colors.black.withOpacity(0.5)),
                ),
              ),
              // Градиентная рамка (всегда, по центру)
              Center(
                child: SizedBox(
                  width: _frameSize,
                  height: _frameSize,
                  child: CustomPaint(
                    painter: _GradientRoundedRectBorderPainter(
                      strokeWidth: 3,
                      borderRadius: 30,
                    ),
                  ),
                ),
              ),
              // Кнопка спуска затвора (всегда показываем видео-шарик)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _cameraUnavailable ? null : (_isCameraInitialized ? _takePicture : null),
                  child: Center(
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: ClipOval(
                        child: _isVideoInitialized
                            ? VideoPlayer(_videoController)
                            : Container(width: 70, height: 70, color: Color(0xFF91FF5E)),
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Превью сделанного фото
              Positioned.fill(
                child: kIsWeb
                    ? Image.network(
                        _capturedFile!.path,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(_capturedFile!.path),
                        fit: BoxFit.cover,
                      ),
              ),
              // Кнопки действия
              Positioned(
                bottom: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white70),
                      onPressed: _retake,
                      child: const Text('Переснять', style: TextStyle(color: Colors.black)),
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF63A36C)),
                      onPressed: _usePhoto,
                      child: const Text('Использовать фото'),
                    ),
                  ],
                ),
              ),
            ],
            // Кнопка закрытия
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 10,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: Image.asset(
                  'assets/images/camera/krestik_camera.png',
                  width: 24,
                  height: 24,
                  color: Colors.white,
                ),
              ),
            ),
          ],
      ),
    );
  }
}

// ==== Вспомогательные классы (скопированы из scanner_screen.dart) ====
class _InvertedRoundedRectClipper extends CustomClipper<Path> {
  final double frameSize;
  final double borderRadius;
  _InvertedRoundedRectClipper({required this.frameSize, this.borderRadius = 30});

  @override
  Path getClip(Size size) {
    final Rect centerRect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: frameSize,
      height: frameSize,
    );
    final RRect centerRRect = RRect.fromRectAndRadius(centerRect, Radius.circular(borderRadius));
    return Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(centerRRect)
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _GradientRoundedRectBorderPainter extends CustomPainter {
  final double strokeWidth;
  final double borderRadius;
  // Используем SweepGradient для красивых цветов, как в сканере
  final Gradient gradient;

  _GradientRoundedRectBorderPainter({this.strokeWidth = 3, this.borderRadius = 30, Gradient? gradient})
      : gradient = gradient ?? const SweepGradient(
          center: Alignment.center,
          colors: [
            Colors.transparent,
            Color(0xFFD4FFC0),
            Colors.transparent,
            Color(0xFF91FF5E),
            Colors.transparent,
            Colors.white,
            Colors.transparent,
            Color(0xFFD4FFC0),
            Colors.transparent,
          ],
          stops: [0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1],
        );

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = gradient.createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 