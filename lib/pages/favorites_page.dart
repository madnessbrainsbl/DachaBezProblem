import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../homepage/UsefulInfoComponent.dart';
import '../homepage/BottomNavigationComponent.dart';
import '../homepage/home_screen.dart';
import '../scanner/scanner_screen.dart';
import 'collection_detail_page.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Расширяем body под нижнюю навигацию
      body: Container(
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
              // Основной контент с прокруткой
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Верхняя часть с заголовком и кнопкой "Создать подборку"
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
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
                              'Моя дача',
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
                        InkWell(
                          onTap: () {
                            // Действие при нажатии "Создать подборку"
                          },
                          child: Row(
                            children: [
                              Text(
                                'Создать подборку',
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF63A36C),
                                ),
                              ),
                              SizedBox(width: 4),
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Color(0xFF63A36C),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.add,
                                  size: 10,
                                  color: Color(0xFF63A36C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Основной контент с прокруткой
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 8),
                            // Горизонтальный ряд подборок
                            SizedBox(
                              height: 40,
                              child: ListView(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _buildCollectionTabFigmaStyle(
                                    title: 'Моя подборка 1',
                                    width: 130,
                                    context: context,
                                  ),
                                  SizedBox(width: 8),
                                  _buildCollectionTabFigmaStyle(
                                    title: 'Моя подборка 2',
                                    width: 130,
                                    context: context,
                                  ),
                                  SizedBox(width: 8),
                                  _buildCollectionTabFigmaStyle(
                                    title: 'Моя подборка 3',
                                    width: 130,
                                    context: context,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),
                            // Карточки растений
                            _buildPlantCard(
                              imagePath: 'assets/images/favorites/plant3.png',
                              name: 'Зантедеския',
                              condition: 'хорошее',
                              wateringInfo: 'следующего полив 1 декабря',
                            ),
                            _buildPlantCard(
                              imagePath: 'assets/images/favorites/plant6.png',
                              name: 'Зантедеския',
                              condition: 'болен',
                              wateringInfo: 'следующего полив 1 декабря',
                              isOnTreatment: true,
                            ),
                            _buildPlantCard(
                              imagePath: 'assets/images/favorites/plant1.png',
                              name: 'Зантедеския',
                              condition: 'хорошее',
                              wateringInfo: 'пропущено 12 дней',
                              missedWatering: true,
                            ),
                            _buildPlantCard(
                              imagePath: 'assets/images/favorites/plant4.png',
                              name: 'Зантедеския',
                              condition: 'хорошее',
                              wateringInfo: 'следующего полив 1 декабря',
                            ),
                            // Отступ снизу для полезной информации
                            SizedBox(height: 150),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Градиентный фон для плавного перехода в UsefulInfoComponent
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 220,
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
        selectedIndex: 3,
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

  // Таб для подборки в стиле Figma: аватарки наложены друг на друга слева, текст справа
  Widget _buildCollectionTabFigmaStyle(
      {required String title,
      required double width,
      required BuildContext context}) {
    // Аватарки с прозрачной рамкой для визуального наложения
    final List<String> avatarPaths = [
      'assets/images/favorites/plant1.png',
      'assets/images/favorites/plant2.png',
      'assets/images/favorites/plant3.png',
      'assets/images/favorites/plant4.png',
    ];

    // Размеры аватарок и отступы
    const double avatarSize = 32.0; // диаметр аватарки
    const double avatarOverlap =
        22.0; // насколько аватарки перекрывают друг друга (увеличено)
    final double totalAvatarsWidth =
        avatarSize + (avatarPaths.length - 1) * (avatarSize - avatarOverlap);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CollectionDetailPage(
              collectionTitle: title,
            ),
          ),
        );
      },
      child: Container(
        width: width,
        height: 40,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Color(0x1931873F),
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Аватарки с наложением (слева)
            for (int i = 0; i < avatarPaths.length; i++)
              Positioned(
                left: 4.0 +
                    i *
                        (avatarSize -
                            avatarOverlap), // меньшее значение для большего наложения
                top: 4,
                child: Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    image: DecorationImage(
                      image: AssetImage(avatarPaths[i]),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

            // Текст подборки (справа от аватарок)
            Positioned(
              left: totalAvatarsWidth + 4, // меньший отступ от аватарок
              top: 14, // вертикальное центрирование
              right: 6, // добавлен правый отступ для контроля ширины
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: width -
                      totalAvatarsWidth -
                      10, // ограничение ширины текста
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10, // уменьшен размер шрифта
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Виджет для карточки растения
  Widget _buildPlantCard({
    required String imagePath,
    required String name,
    required String condition,
    required String wateringInfo,
    bool isOnTreatment = false,
    bool missedWatering = false,
  }) {
    // Создаем TextSpan для составных строк с различным форматированием
    TextSpan buildConditionText() {
      if (condition == 'хорошее') {
        return TextSpan(
          children: [
            TextSpan(
              text: 'Состояние: ',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            TextSpan(
              text: condition,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF63A36C),
              ),
            ),
          ],
        );
      } else if (condition == 'болен') {
        return TextSpan(
          children: [
            TextSpan(
              text: 'Состояние: ',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            TextSpan(
              text: condition,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.red,
              ),
            ),
          ],
        );
      } else {
        return TextSpan(
          text: 'Состояние: $condition',
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        );
      }
    }

    TextSpan buildWateringText() {
      // Безопасно разделяем строку, чтобы получить значение после ": "
      String valuePart = wateringInfo.contains(': ')
          ? wateringInfo.split(': ').last
          : wateringInfo;
      bool isMissed = wateringInfo.contains('пропущено');

      return TextSpan(
        children: [
          TextSpan(
            text: 'Полив: ',
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          TextSpan(
            text: valuePart, // Используем извлеченное значение
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 10,
              fontWeight: FontWeight.w700, // Жирный шрифт
              color: isMissed
                  ? Colors.red
                  : Colors.black, // Красный, если пропущено, иначе черный
            ),
          ),
        ],
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              imagePath,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  RichText(
                    text: buildConditionText(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  RichText(
                    text: buildWateringText(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isOnTreatment)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF63A36C),
                              Color(0xFF63A36C).withOpacity(0.5)
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              'assets/images/favorites/plus.svg',
                              color: Colors.white,
                              width: 8,
                              height: 8,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'На лечении',
                              style: TextStyle(
                                fontFamily: 'Gilroy',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Класс для рисования полос на желтом прямоугольнике
class StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    double startY = -size.height;
    double endY = size.height * 2;

    // Рисуем диагональные полосы
    for (double i = -size.width * 0.5; i < size.width * 1.5; i += 12) {
      canvas.drawLine(
        Offset(i, startY),
        Offset(i + size.width, endY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
