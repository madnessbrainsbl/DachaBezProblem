import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'home_styles.dart';
import '../services/api/useful_info_service.dart';
import '../models/useful_info_model.dart';

class UsefulInfoComponent extends StatefulWidget {
  const UsefulInfoComponent({Key? key}) : super(key: key);

  @override
  State<UsefulInfoComponent> createState() => _UsefulInfoComponentState();
}

class _UsefulInfoComponentState extends State<UsefulInfoComponent> {
  final UsefulInfoService _usefulInfoService = UsefulInfoService();
  UsefulInfoData? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsefulInfo();
  }

  Future<void> _loadUsefulInfo() async {
    try {
      final result = await _usefulInfoService.getUsefulInfo();
      if (mounted) {
        setState(() {
          if (result.success && result.data != null) {
            _data = result.data!;
            _error = null;
          } else {
            _error = result.message ?? 'Не удалось загрузить данные';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка загрузки: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Игнорируем ошибки открытия URL
    }
  }

  @override
  Widget build(BuildContext context) {
    // Получаем размер экрана для адаптивности
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Определяем тип экрана
    final isSmallScreen = screenWidth < 375;
    
    // Адаптивные размеры
    final horizontalPadding = isSmallScreen ? 12.0 : 20.0;
    final cardPadding = isSmallScreen ? 12.0 : 16.0;
    final titleFontSize = isSmallScreen ? 13.0 : 14.0;
    
    // Вычисляем размер элементов в зависимости от ширины экрана
    final availableWidth = screenWidth - (horizontalPadding * 2) - (cardPadding * 2);
    final itemSpacing = isSmallScreen ? 4.0 : 6.0;
    final avatarSpacing = isSmallScreen ? 4.0 : 6.0;
    
    // Размер для основных элементов (3 картинки)
    final mainItemsWidth = availableWidth - (itemSpacing * 2) - (avatarSpacing) - (isSmallScreen ? 44 : 50);
    final itemSize = (mainItemsWidth / 3).clamp(50.0, 78.0);
    
    // Вычисляем размер аватара
    final avatarSize = isSmallScreen ? 18.0 : 22.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        elevation: 2,
        color: Colors.white,
        shadowColor: Color(0x1931873F),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            minHeight: isSmallScreen ? 120 : 135,
          ),
          child: _isLoading
              ? _buildLoadingState()
              : _error != null
                  ? _buildErrorState()
                  : _buildContent(context, cardPadding, titleFontSize, isSmallScreen, itemSpacing, itemSize, avatarSpacing, avatarSize),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF31873F)),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Полезная информация',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 14.0,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Не удалось загрузить данные',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, double cardPadding, double titleFontSize, bool isSmallScreen, double itemSpacing, double itemSize, double avatarSpacing, double avatarSize) {
    if (_data == null) return _buildErrorState();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(top: isSmallScreen ? 8 : 10),
          child: Text(
            _data!.title,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: titleFontSize,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(height: isSmallScreen ? 3 : 5),
        Flexible(
          child: Padding(
            padding: EdgeInsets.fromLTRB(cardPadding, 5, cardPadding, cardPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _buildMainItems(context, itemSize, itemSpacing),
                  ),
                ),
                SizedBox(width: avatarSpacing),
                Flexible(
                  flex: 1,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _buildSideItems(context, avatarSize, isSmallScreen),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMainItems(BuildContext context, double itemSize, double itemSpacing) {
    final items = <Widget>[];
    
    for (int i = 0; i < _data!.mainItems.length && i < 3; i++) {
      if (i > 0) items.add(SizedBox(width: itemSpacing));
      items.add(
        Flexible(
          child: _buildInfoItem(context, _data!.mainItems[i], itemSize),
        ),
      );
    }
    
    // ИСПРАВЛЕНИЕ: НЕ добавляем пустые элементы, показываем только реальные данные
    // Удаляем логику создания заглушек которая вызывала дублирование
    
    return items;
  }

  List<Widget> _buildSideItems(BuildContext context, double avatarSize, bool isSmallScreen) {
    final items = <Widget>[];
    
    // Находим элементы для боковой панели
    final wbItem = _data!.sideItems.firstWhere(
      (item) => item.type == 'wildberries',
      orElse: () => SideInfoItem(id: '', type: 'wildberries', link: ''),
    );
    
    final yandexItem = _data!.sideItems.firstWhere(
      (item) => item.type == 'yandex_market',
      orElse: () => SideInfoItem(id: '', type: 'yandex_market', link: ''),
    );
    
    items.add(_buildAvatar(context, avatarSize, 'WB', wbItem.link));
    items.add(SizedBox(height: isSmallScreen ? 4 : 6));
    items.add(_buildYandexMarketIcon(context, avatarSize, yandexItem.link));
    
    return items;
  }

  Widget _buildInfoItem(BuildContext context, MainInfoItem item, double size) {
    return GestureDetector(
      onTap: () => _openUrl(item.link),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: size,
            maxHeight: size,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Color(0xFFD9D9D9),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              item.imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF31873F)),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Icon(
                    Icons.image_not_supported,
                    color: Colors.grey[400],
                    size: size * 0.4,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyInfoItem(BuildContext context, double size) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: size,
          maxHeight: size,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Color(0xFFD9D9D9),
        ),
        child: Center(
          child: Icon(
            Icons.image,
            color: Colors.grey[400],
            size: size * 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, double size, String text, String link) {
    return GestureDetector(
      onTap: () => _openUrl(link),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size / 2),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6F01FB),
              Color(0xFFFF49D7),
            ],
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.45,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYandexMarketIcon(BuildContext context, double size, String link) {
    return GestureDetector(
      onTap: () => _openUrl(link),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size / 2),
          color: Colors.orange,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: Image.asset(
            'assets/images/home/yamarket.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
