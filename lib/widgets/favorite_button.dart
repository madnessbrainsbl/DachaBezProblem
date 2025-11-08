import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api/favorites_service.dart';
import '../services/api/scan_service.dart';
import '../services/logger.dart';
import '../models/plant_info.dart';

class FavoriteButton extends StatefulWidget {
  final String plantId;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final VoidCallback? onToggle;
  final bool initialIsFavorite;
  final String? initialFavoriteId;
  final PlantInfo? plantData;

  const FavoriteButton({
    Key? key,
    required this.plantId,
    this.size = 24.0,
    this.activeColor,
    this.inactiveColor,
    this.onToggle,
    this.initialIsFavorite = false,
    this.initialFavoriteId,
    this.plantData,
  }) : super(key: key);

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  bool _isFavorite = false;
  String? _favoriteId;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  final FavoritesService _favoritesService = FavoritesService();

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.initialIsFavorite;
    _favoriteId = widget.initialFavoriteId;
    
    AppLogger.api('🔧 FavoriteButton.initState для plantId: ${widget.plantId}');
    AppLogger.api('📊 Начальные данные: isFavorite=${widget.initialIsFavorite}, favoriteId=${widget.initialFavoriteId}');
    
    _animationController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    // ИСПРАВЛЕНО: ВСЕГДА проверяем статус через API для получения актуального favoriteId
    AppLogger.api('🔍 Принудительно проверяем статус через API для получения favoriteId');
    _checkFavoriteStatus();
  }

  @override
  void didUpdateWidget(FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Если изменился plantId, перепроверяем статус
    if (oldWidget.plantId != widget.plantId) {
      AppLogger.api('🔄 PlantId изменился с ${oldWidget.plantId} на ${widget.plantId}, перепроверяем статус');
      _checkFavoriteStatus();
    }
    
    // Если изменились начальные данные, обновляем состояние
    if (oldWidget.initialIsFavorite != widget.initialIsFavorite || 
        oldWidget.initialFavoriteId != widget.initialFavoriteId) {
      AppLogger.api('🔄 Начальные данные изменились, обновляем состояние');
      setState(() {
        _isFavorite = widget.initialIsFavorite;
        _favoriteId = widget.initialFavoriteId;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkFavoriteStatus() async {
    if (widget.plantId.isEmpty) {
      AppLogger.api('❌ PlantId пустой, пропускаем проверку статуса');
      return;
    }
    
    try {
      AppLogger.api('🔍 === НАЧАЛО _checkFavoriteStatus ===');
      AppLogger.api('🆔 PlantId: "${widget.plantId}"');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        AppLogger.api('❌ Токен не найден, пропускаем проверку статуса');
        return;
      }
      
      AppLogger.api('✅ Токен найден, длина: ${token.length}');
      AppLogger.api('📞 Вызываем favoritesService.checkIsFavorite...');
      
      final result = await _favoritesService.checkIsFavorite(token, widget.plantId);
      
      AppLogger.api('📊 === РЕЗУЛЬТАТ checkIsFavorite ===');
      AppLogger.api('🔍 Полный результат: $result');
      AppLogger.api('💡 isFavorite: ${result['isFavorite']}');
      AppLogger.api('🆔 favoriteId: ${result['favoriteId']}');
      
      if (mounted) {
        AppLogger.api('🔄 Обновляем состояние FavoriteButton...');
        setState(() {
          _isFavorite = result['isFavorite'] ?? false;
          _favoriteId = result['favoriteId'];
        });
        AppLogger.api('✅ Состояние обновлено: _isFavorite=$_isFavorite, _favoriteId=$_favoriteId');
      }
      
      AppLogger.api('🏁 === КОНЕЦ _checkFavoriteStatus ===');
    } catch (e) {
      AppLogger.error('💥 Ошибка проверки статуса избранного: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading || widget.plantId.isEmpty) return;
    
    print('🚀 === КНОПКА ЛАЙКА НАЖАТА ===');
    print('🚀 Информация о компоненте:');
    print('🚀    • plantId: "${widget.plantId}"');
    print('🚀    • plantData.name: "${widget.plantData?.name ?? "null"}"');
    print('🚀    • plantData.scanId: "${widget.plantData?.scanId ?? "null"}"');
    print('🚀    • Текущий _isFavorite: $_isFavorite');
    print('🚀    • Текущий _favoriteId: $_favoriteId');
    print('🚀    • initialIsFavorite: ${widget.initialIsFavorite}');
    print('🚀    • initialFavoriteId: ${widget.initialFavoriteId}');
    
    AppLogger.api('🚀 === НАЧАЛО _toggleFavorite ===');
    AppLogger.api('🆔 PlantId: ${widget.plantId}');
    AppLogger.api('💡 Текущее состояние лайка: $_isFavorite');
    
    // КРИТИЧНО: Очищаем кэш перед ЛЮБЫМИ операциями
    FavoritesService.clearCache();
    print('🧹 Кэш избранного полностью очищен');
    AppLogger.api('🧹 Кэш избранного полностью очищен');
    
    // ОПТИМИСТИЧНОЕ ОБНОВЛЕНИЕ: Сразу меняем состояние для быстрого отклика UI
    final previousState = _isFavorite;
    final previousFavoriteId = _favoriteId;
    
    AppLogger.api('📊 Предыдущие значения: state=$previousState, favoriteId=$previousFavoriteId');
    
    setState(() {
      _isFavorite = !_isFavorite;  // Сразу переключаем состояние
      _isLoading = true;
      if (!_isFavorite) {
        _favoriteId = null;  // Если убираем лайк, очищаем ID
      }
    });
    
    AppLogger.api('✨ Состояние после оптимистичного обновления: $_isFavorite');
    
    // Запускаем анимацию
    if (_isFavorite) {
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
    }
    
    try {
      AppLogger.api('🔑 Получаем токен авторизации...');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        throw Exception('Необходимо войти в аккаунт');
      }
      
      AppLogger.api('✅ Токен получен, длина: ${token.length}');
      
      if (previousState && previousFavoriteId != null) {
        AppLogger.api('❌ УДАЛЕНИЕ из избранного, favoriteId: $previousFavoriteId');
        // Удаляем из избранного
        await _favoritesService.removeFromFavorites(token, previousFavoriteId);
        
        if (mounted) {
          AppLogger.api('✅ Успешно удалено из избранного');
          _showFeedback('Удалено из избранного');
        }
      } else {
        AppLogger.api('➕ ДОБАВЛЕНИЕ в избранное');
        // УПРОЩЕННАЯ ЛОГИКА: Просто добавляем в избранное напрямую
        String plantIdForFavorites = widget.plantId;
        
        AppLogger.api('🆔 Используем plantId напрямую: $plantIdForFavorites');
        
        // Добавляем в избранное без дополнительных проверок
        AppLogger.api('📞 Вызываем addToFavorites...');
        final result = await _favoritesService.addToFavorites(token, plantIdForFavorites);
        
        AppLogger.api('📊 Результат addToFavorites: ${result.keys}');
        AppLogger.api('✅ Success: ${result['success']}');
        AppLogger.api('📊 Data: ${result['data']}');
        
        if (result['success'] == true) {
          AppLogger.api('🎉 Избранное добавлено успешно!');
          
          if (mounted) {
            final favoriteId = result['data']?['_id']?.toString() ?? result['data']?['id']?.toString();
            AppLogger.api('🆔 Новый favoriteId: $favoriteId');
            
            setState(() {
              _favoriteId = favoriteId;
            });
            
            // Обновляем кэш
            FavoritesService.updateCache(plantIdForFavorites, true, favoriteId);
            
            AppLogger.api('✅ Состояние обновлено, показываем уведомление');
            _showFeedback('Добавлено в избранное');
            
            if (widget.onToggle != null) {
              AppLogger.api('📞 Вызываем callback onToggle');
              widget.onToggle!();
            }
          }
        } else {
          AppLogger.api('❌ Сервер вернул ошибку: ${result['message']}');
          throw Exception(result['message'] ?? 'Не удалось добавить в избранное');
        }
      }
      
      AppLogger.api('🎉 === _toggleFavorite ЗАВЕРШЕН УСПЕШНО ===');
    } catch (e, stackTrace) {
      AppLogger.error('💥 === ОШИБКА в _toggleFavorite ===');
      AppLogger.error('❌ Ошибка: $e');
      AppLogger.error('📍 StackTrace: $stackTrace');
      
      // ОТКАТ: Восстанавливаем предыдущее состояние при ошибке
      if (mounted) {
        AppLogger.api('🔄 Откатываем состояние: state=$previousState, favoriteId=$previousFavoriteId');
        setState(() {
          _isFavorite = previousState;
          _favoriteId = previousFavoriteId;
        });
        
        AppLogger.api('🔴 Показываем красное уведомление об ошибке');
        _showFeedback('Ошибка: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        AppLogger.api('🏁 Убираем индикатор загрузки');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isLoading ? null : _toggleFavorite,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.size * 1.5,
              height: widget.size * 1.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
              ),
              child: Center(
                child: _isLoading
                    ? SizedBox(
                        width: widget.size * 0.8,
                        height: widget.size * 0.8,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.activeColor ?? Color(0xFF63A36C),
                          ),
                        ),
                      )
                    : SvgPicture.asset(
                        'assets/images/plant_result_zdorovoe/Layer_2_00000154399694884061480560000015505170056280207754_.svg',
                        width: widget.size,
                        height: widget.size,
                        colorFilter: ColorFilter.mode(
                          _isFavorite
                              ? (widget.activeColor ?? Color(0xFF63A36C))
                              : (widget.inactiveColor ?? Color(0xFFBDBDBD)),
                          BlendMode.srcIn,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
} 