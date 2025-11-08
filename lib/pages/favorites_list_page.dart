import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api/favorites_service.dart';
import '../services/logger.dart';
import '../widgets/favorite_button.dart';
import 'plant_detail_page.dart';

class FavoritesListPage extends StatefulWidget {
  const FavoritesListPage({Key? key}) : super(key: key);

  @override
  State<FavoritesListPage> createState() => _FavoritesListPageState();
}

class _FavoritesListPageState extends State<FavoritesListPage> {
  static const String baseUrl = 'http://89.110.92.227:3002';
  
  bool _isLoading = true;
  List<dynamic> _favorites = [];
  String _errorMessage = '';
  
  final FavoritesService _favoritesService = FavoritesService();

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Необходимо войти в аккаунт';
        });
        return;
      }
      
      final favorites = await _favoritesService.getFavorites(token);
      
      print('🔍 === АНАЛИЗ ОТВЕТА API ИЗБРАННОГО ===');
      print('📊 Всего избранных элементов: ${favorites.length}');
      
      if (favorites.isNotEmpty) {
        print('📋 Структура первого элемента:');
        final firstFavorite = favorites.first;
        print('   • Ключи верхнего уровня: ${firstFavorite.keys.join(", ")}');
        
                 if (firstFavorite['item'] != null) {
           final item = firstFavorite['item'];
           if (item is Map) {
             print('   • Ключи item: ${item.keys.join(", ")}');
             
             // Проверяем поле photo
             print('   • photo: "${item['photo']}"');
             
             // Проверяем другие потенциальные поля с изображениями
             final otherFields = ['image_url', 'image', 'picture', 'avatar'];
             for (String field in otherFields) {
               if (item.containsKey(field)) {
                 print('   • $field: "${item[field]}"');
               }
             }
             
             if (item['images'] != null && item['images'] is Map) {
               final images = item['images'] as Map;
               print('   • Доступные изображения в images:');
               images.forEach((key, value) {
                 print('     - $key: "$value"');
               });
             } else {
               print('   • ❌ Нет изображений в item');
             }
           } else {
             print('   • ❌ item не является Map');
           }
         } else {
           print('   • ❌ Нет поля item');
         }
      }
      print('🔍 === КОНЕЦ АНАЛИЗА ОТВЕТА API ===');
      
      setState(() {
        _favorites = favorites;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Ошибка при загрузке избранного: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Не удалось загрузить избранное';
      });
    }
  }

  Future<void> _removeFromFavorites(String favoriteId, int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        _showMessage('Необходимо войти в аккаунт', isError: true);
        return;
      }
      
      await _favoritesService.removeFromFavorites(token, favoriteId);
      
      // Удаляем из локального списка
      setState(() {
        _favorites.removeAt(index);
      });
      
      _showMessage('Удалено из избранного');
    } catch (e) {
      AppLogger.error('Ошибка при удалении из избранного: $e');
      _showMessage('Ошибка при удалении', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Color(0xFF63A36C),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _openPlantDetail(Map<String, dynamic> favorite) {
    try {
      // ИСПРАВЛЕНИЕ: PlantDetailPage ожидает данные растения напрямую, а не в поле 'item'
      final item = favorite['item'] as Map<String, dynamic>?;
      if (item == null) {
        print('❌ Избранное: нет данных растения в поле item');
        _showMessage('Ошибка: данные растения отсутствуют', isError: true);
        return;
      }
      
      print('🔍 Открываем детали растения из избранного: ${item['name']}');
      print('📊 Структура данных для PlantDetailPage: ${item.keys.join(", ")}');
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlantDetailPage(plant: item), // Передаем item напрямую
        ),
      );
    } catch (e) {
      print('❌ Ошибка при открытии деталей растения: $e');
      _showMessage('Ошибка при открытии растения', isError: true);
    }
  }

  String _getSafeImageUrl(Map<String, dynamic> favorite) {
    try {
      final item = favorite['item'] as Map<String, dynamic>?;
      if (item == null) return '';
      
      // Сначала проверяем поле photo (возможно изображение там)
      if (item['photo'] != null && item['photo'].toString().isNotEmpty) {
        String photoUrl = item['photo'].toString();
        
        // Если это относительный путь, добавляем базовый URL
        if (photoUrl.startsWith('/uploads/')) {
          photoUrl = '$baseUrl$photoUrl';
          print('🖼️ Избранное: Преобразуем относительный путь в полный URL: $photoUrl');
        } else {
          print('🖼️ Избранное: Используем изображение из photo: $photoUrl');
        }
        
        return photoUrl;
      }
      
      final images = item['images'] as Map<String, dynamic>?;
      if (images == null) {
        print('⚠️ Избранное: Нет поля images в item');
        return '';
      }
      
      // ИСПРАВЛЕНО: thumbnail (кроп) должен быть приоритетным для списков
      // Приоритет: thumbnail (кроп) > crop > main_image > original > user_image
      final imageKeys = ['thumbnail', 'crop', 'main_image', 'original', 'user_image'];
      
      for (String key in imageKeys) {
        if (images[key] != null && images[key].toString().isNotEmpty) {
          String imageUrl = images[key].toString();
          
          // Если это относительный путь, добавляем базовый URL
          if (imageUrl.startsWith('/uploads/')) {
            imageUrl = '$baseUrl$imageUrl';
            print('🖼️ Избранное: Преобразуем относительный путь $key в полный URL: $imageUrl');
          } else {
            print('🖼️ Избранное: Используем изображение $key: $imageUrl');
          }
          
          return imageUrl;
        }
      }
      
      // Если ничего не нашли из приоритетного списка, берем первое непустое значение
      if (images.values.isNotEmpty) {
        for (var value in images.values) {
          if (value != null && value.toString().isNotEmpty) {
            String imageUrl = value.toString();
            
            // Если это относительный путь, добавляем базовый URL
            if (imageUrl.startsWith('/uploads/')) {
              imageUrl = '$baseUrl$imageUrl';
              print('🖼️ Избранное: Преобразуем относительный fallback-путь в полный URL: $imageUrl');
            } else {
              print('🖼️ Избранное: Используем первое доступное изображение: $imageUrl');
            }
            
            return imageUrl;
          }
        }
      }
      
      print('⚠️ Избранное: Нет доступных изображений в структуре images: $images');
      
      // Последняя попытка - проверяем другие возможные поля с изображениями
      final otherImageFields = ['image_url', 'image', 'picture', 'avatar'];
      for (String field in otherImageFields) {
        if (item[field] != null && item[field].toString().isNotEmpty) {
          String imageUrl = item[field].toString();
          
          // Если это относительный путь, добавляем базовый URL
          if (imageUrl.startsWith('/uploads/')) {
            imageUrl = '$baseUrl$imageUrl';
            print('🖼️ Избранное: Преобразуем относительный путь $field в полный URL: $imageUrl');
          } else {
            print('🖼️ Избранное: Используем изображение из поля $field: $imageUrl');
          }
          
          return imageUrl;
        }
      }
      
      print('❌ Избранное: Не найдено ни одного изображения во всех проверенных полях');
      return '';
    } catch (e) {
      AppLogger.error('Ошибка при получении изображения: $e');
      return '';
    }
  }

  String _getSafePlantName(Map<String, dynamic> favorite) {
    try {
      final item = favorite['item'] as Map<String, dynamic>?;
      return item?['name']?.toString() ?? 'Неизвестное растение';
    } catch (e) {
      return 'Неизвестное растение';
    }
  }

  String _getSafePlantInfo(Map<String, dynamic> favorite) {
    try {
      final item = favorite['item'] as Map<String, dynamic>?;
      if (item == null) return 'Растение';
      
      // Пытаемся получить тип из тегов
      final tags = item['tags'] as List?;
      if (tags != null && tags.isNotEmpty) {
        return tags[0].toString();
      }
      
      // Или из латинского названия
      final latinName = item['latin_name']?.toString();
      if (latinName != null && latinName.isNotEmpty) {
        return latinName;
      }
      
      return 'Растение';
    } catch (e) {
      return 'Растение';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;

    return Scaffold(
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
          child: Column(
            children: [
              // Заголовок
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: SvgPicture.asset(
                        'assets/images/favorites/back_arrow.svg',
                        width: 24,
                        height: 24,
                        color: Color(0xFF63A36C),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 12 : 16),
                    Text(
                      'Избранное',
                      style: TextStyle(
                        color: Color(0xFF1F2024),
                        fontSize: isSmallScreen ? 16 : 18,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.005,
                      ),
                    ),
                  ],
                ),
              ),

              // Основной контент
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 22),
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 15),
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
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF63A36C),
                          ),
                        )
                      : _errorMessage.isNotEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: Colors.red,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    _errorMessage,
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 16,
                                      fontFamily: 'Gilroy',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadFavorites,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF63A36C),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      'Повторить',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _favorites.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SvgPicture.asset(
                                        'assets/images/plant_result_zdorovoe/Layer_2_00000154399694884061480560000015505170056280207754_.svg',
                                        width: 48,
                                        height: 48,
                                        colorFilter: ColorFilter.mode(
                                          Color(0xFF63A36C).withOpacity(0.5),
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'У вас пока нет избранных растений',
                                        style: TextStyle(
                                          color: Color(0xFF63A36C),
                                          fontSize: 16,
                                          fontFamily: 'Gilroy',
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Добавьте растения в избранное, чтобы\nони появились здесь',
                                        style: TextStyle(
                                          color: Color(0xFF63A36C).withOpacity(0.7),
                                          fontSize: 14,
                                          fontFamily: 'Gilroy',
                                          fontWeight: FontWeight.w400,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _loadFavorites,
                                  color: Color(0xFF63A36C),
                                  child: ListView.builder(
                                    itemCount: _favorites.length,
                                    itemBuilder: (context, index) {
                                      final favorite = _favorites[index] as Map<String, dynamic>;
                                      return _buildFavoriteItem(favorite, index);
                                    },
                                  ),
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteItem(Map<String, dynamic> favorite, int index) {
    print('🖼️ === ПОСТРОЕНИЕ ЭЛЕМЕНТА ИЗБРАННОГО ===');
    print('📊 Структура favorite: ${favorite.keys.join(", ")}');
    if (favorite['item'] != null && favorite['item'] is Map) {
      final item = favorite['item'] as Map;
      print('📊 Структура item: ${item.keys.join(", ")}');
      if (item['images'] != null && item['images'] is Map) {
        final images = item['images'] as Map;
        print('🖼️ Доступные изображения: ${images.keys.join(", ")}');
        images.forEach((key, value) {
          print('   • $key: $value');
        });
      } else {
        print('❌ Нет images в item или images не Map');
      }
    } else {
      print('❌ Нет item в favorite или item не Map');
    }
    
    final imageUrl = _getSafeImageUrl(favorite);
    final plantName = _getSafePlantName(favorite);
    final plantInfo = _getSafePlantInfo(favorite);
    final favoriteId = favorite['_id']?.toString() ?? '';
    final item = favorite['item'] as Map<String, dynamic>?;
    
    print('🎯 Итоговый imageUrl: "$imageUrl"');
    print('🎯 Имя растения: "$plantName"');
    print('🖼️ === КОНЕЦ АНАЛИЗА ЭЛЕМЕНТА ИЗБРАННОГО ===');

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFFF0F0F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1031873F),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Изображение растения
          GestureDetector(
            onTap: () {
              if (item != null) {
                _openPlantDetail(favorite); // Передаем весь favorite, а не только item
              }
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Color(0xFFF0F0F0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl.isNotEmpty
                    ? (imageUrl.startsWith('http')
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('❌ Ошибка загрузки изображения в избранном: $error');
                              return _buildPlaceholderImage();
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Color(0xFFF0F0F0),
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF63A36C)),
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : Image.asset(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPlaceholderImage();
                            },
                          ))
                    : _buildPlaceholderImage(),
              ),
            ),
          ),
          
          SizedBox(width: 12),
          
          // Информация о растении
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (item != null) {
                  _openPlantDetail(favorite); // Передаем весь favorite, а не только item
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plantName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Gilroy',
                      color: Color(0xFF1F2024),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    plantInfo,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Gilroy',
                      color: Color(0xFF63A36C),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item?['is_healthy'] != null)
                    Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (item!['is_healthy'] ?? true) 
                                  ? Color(0xFF4CAF50) 
                                  : Color(0xFFFF9800),
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            (item['is_healthy'] ?? true) ? 'Здоровое' : 'Требует внимания',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Gilroy',
                              color: (item['is_healthy'] ?? true) 
                                  ? Color(0xFF4CAF50) 
                                  : Color(0xFFFF9800),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Кнопка удаления
          GestureDetector(
            onTap: () {
              if (favoriteId.isNotEmpty) {
                _showRemoveConfirmation(favoriteId, index, plantName);
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.1),
              ),
              child: Center(
                child: Icon(
                  Icons.favorite,
                  size: 20,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRemoveConfirmation(String favoriteId, int index, String plantName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Удалить из избранного?',
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Растение "$plantName" будет удалено из избранного.',
            style: TextStyle(
              fontFamily: 'Gilroy',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Отмена',
                style: TextStyle(
                  color: Color(0xFF63A36C),
                  fontFamily: 'Gilroy',
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _removeFromFavorites(favoriteId, index);
              },
              child: Text(
                'Удалить',
                style: TextStyle(
                  color: Colors.red,
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 60,
      height: 60,
      color: Color(0xFFF0F0F0),
      child: Center(
        child: Icon(
          Icons.eco_outlined,
          size: 24,
          color: Color(0xFF63A36C),
        ),
      ),
    );
  }
} 