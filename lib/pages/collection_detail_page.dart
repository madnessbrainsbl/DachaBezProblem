import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../homepage/UsefulInfoComponent.dart';
import '../homepage/BottomNavigationComponent.dart';
import '../homepage/home_screen.dart';
import '../scanner/scanner_screen.dart';

class CollectionDetailPage extends StatelessWidget {
  final String collectionTitle;

  const CollectionDetailPage({
    Key? key,
    required this.collectionTitle,
  }) : super(key: key);

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
                          'Избранное',
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

                  // Основной контент с прокруткой (сетка растений)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            SizedBox(height: 12),
                            _buildPlantsGrid(context),
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

  // Сетка растений
  Widget _buildPlantsGrid(BuildContext context) {
    final List<Map<String, String>> plants = [
      {
        'imagePath': 'assets/images/favorites/plant3.png',
        'name': 'Название',
      },
      {
        'imagePath': 'assets/images/favorites/plant6.png',
        'name': 'Название',
      },
      {
        'imagePath': 'assets/images/favorites/plant1.png',
        'name': 'Название',
      },
      {
        'imagePath': 'assets/images/favorites/plant4.png',
        'name': 'Название',
      },
      {
        'imagePath': 'assets/images/favorites/plant3.png',
        'name': 'Название',
      },
      {
        'imagePath': 'assets/images/favorites/plant6.png',
        'name': 'Название',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: plants.length,
      itemBuilder: (context, index) {
        return _buildPlantGridItem(
          context,
          plants[index]['imagePath']!,
          plants[index]['name']!,
        );
      },
    );
  }

  // Элемент сетки (карточка растения)
  Widget _buildPlantGridItem(
      BuildContext context, String imagePath, String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Изображение растения
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              imagePath,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
        // Название растения
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            name,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1F2024),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
