import 'package:flutter/material.dart';
import 'home_styles.dart';
import 'package:video_player/video_player.dart';

class BottomNavigationComponent extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const BottomNavigationComponent({
    Key? key,
    required this.selectedIndex,
    required this.onItemTapped,
  }) : super(key: key);

  @override
  State<BottomNavigationComponent> createState() =>
      _BottomNavigationComponentState();
}

class _BottomNavigationComponentState extends State<BottomNavigationComponent> {
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() {
    _videoController = VideoPlayerController.asset('assets/mp4/shar.mp4')
      ..initialize().then((_) {
        setState(() {
          _isVideoInitialized = true;
        });
        _videoController.setLooping(true);
        _videoController.play();
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Получаем нижний отступ системной навигации
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // Добавляем декорацию для тени и белого фона
    return Container(
      height: 70 + bottomPadding, // Стандартная высота + системный отступ
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShapeShadow(
            color: Color(0x1931873F),
            blurRadius: 20,
            offset: Offset(0, -4), // Тень сверху
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding), // Отступ снизу для системной навигации
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceAround, // Равномерное распределение
          children: [
            _buildNavItem(
              context,
              index: 0,
              icon: 'assets/images/home/layer-2.png',
              label: 'Главная',
              fallbackIcon: Icons.home,
            ),
            _buildNavItem(
              context,
              index: 1,
              icon: 'assets/images/home/vector.png',
              label: 'Календарь',
              fallbackIcon: Icons.calendar_today,
            ),
            // Центральная кнопка сканера (пустое место или кастомный виджет)
            _buildScanButton(context),
            _buildNavItem(
              context,
              index: 3, // Пропускаем индекс 2 для сканера
              icon: 'assets/images/home/group-27.png',
              label: 'Моя дача',
              fallbackIcon: Icons.yard,
            ),
            _buildNavItem(
              context,
              index: 4,
              icon: 'assets/images/home/group.png',
              label: 'ИИ-чат',
              fallbackIcon: Icons.chat,
            ),
          ],
        ),
      ),
    );
  }

  // Виджет для обычной кнопки навигации
  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required String icon,
    required String label,
    required IconData fallbackIcon,
  }) {
    final bool isSelected = widget.selectedIndex == index;
    final Color color =
        isSelected ? HomeStyles.primaryGreen : Color(0xFFD1E7C4);

    return GestureDetector(
        onTap: () => widget.onItemTapped(index),
        behavior: HitTestBehavior.opaque, // Чтобы вся область была кликабельной
        child: Container(
          padding: EdgeInsets.symmetric(
              vertical: 10, horizontal: 5), // Добавляем отступы
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                MainAxisAlignment.center, // Центрируем содержимое
            children: [
              Image.asset(
                icon,
                width: 20,
                height: 20,
                color: color,
                errorBuilder: (context, error, stackTrace) => Icon(
                  fallbackIcon,
                  size: 20,
                  color: color,
                ),
              ),
              SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 9,
                  fontWeight: FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ));
  }

  // Виджет для центральной кнопки сканера
  Widget _buildScanButton(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onItemTapped(2), // Индекс 2 для сканера
      child: Container(
        width: 58,
        height: 58,
        margin: EdgeInsets.only(bottom: 15), // Поднимаем кнопку немного вверх
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white, // Белый фон для круга
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: ClipOval(
            child: _isVideoInitialized
                ? VideoPlayer(_videoController)
                : Image.asset(
                    'assets/images/home/sharikmenu.png',
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: HomeStyles.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(Icons.camera_alt, color: Colors.white, size: 30),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // Helper class for BoxShadow with BoxShape
  // (Required because standard BoxShadow doesn't work directly with BoxShape)
  static BoxShapeShadow(
      {required Color color,
      required double blurRadius,
      required Offset offset}) {
    return BoxShadow(
      color: color,
      blurRadius: blurRadius,
      offset: offset,
    );
  }
}
