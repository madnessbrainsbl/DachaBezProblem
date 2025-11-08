import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../pages/achievements_page.dart';
import 'dart:async';

class AchievementNotification {
  static void show(BuildContext context, Achievement achievement) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFEAF5DA),
                  Color(0xFFB6DFA3),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Иконка достижения с анимацией
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 100,
                        height: 100,
                        child: Stack(
                          children: [
                            // Пульсирующий эффект
                            AnimatedContainer(
                              duration: Duration(milliseconds: 1000),
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(50),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF63A36C).withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                            // Основная иконка
                            Center(
                              child: achievement.iconUrl.isNotEmpty
                                ? Image.network(
                                    achievement.iconUrl,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: Color(0xFF63A36C).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(40),
                                        ),
                                        child: Icon(
                                          Icons.emoji_events,
                                          size: 50,
                                          color: Color(0xFF63A36C),
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Color(0xFF63A36C).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(40),
                                    ),
                                    child: Icon(
                                      Icons.emoji_events,
                                      size: 50,
                                      color: Color(0xFF63A36C),
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                
                SizedBox(height: 16),
                
                // Заголовок с анимацией
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  builder: (context, opacity, child) {
                    return Opacity(
                      opacity: opacity,
                      child: Text(
                        '🎉 Новое достижение!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D5016),
                          fontFamily: 'Gilroy',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
                
                SizedBox(height: 8),
                
                // Название достижения
                Text(
                  achievement.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2024),
                    fontFamily: 'Gilroy',
                  ),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: 8),
                
                // Описание
                Text(
                  achievement.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                    fontFamily: 'Gilroy',
                  ),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: 16),
                
                // Баллы с анимацией
                DelayedAnimationBuilder(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 800),
                  delay: Duration(milliseconds: 200),
                  curve: Curves.bounceOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Color(0xFF63A36C).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              color: Color(0xFF63A36C),
                              size: 20,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '+${achievement.points} баллов',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF63A36C),
                                fontFamily: 'Gilroy',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                
                SizedBox(height: 24),
                
                // Кнопки
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Закрыть',
                          style: TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 16,
                            fontFamily: 'Gilroy',
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // Переход к странице достижений
                          Navigator.push(
                            context, 
                            MaterialPageRoute(
                              builder: (context) => AchievementsPage()
                            )
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF63A36C),
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Посмотреть',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Gilroy',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // НОВЫЙ МЕТОД: Простое уведомление в виде снэкбара для менее важных достижений
  static void showSnackbar(BuildContext context, Achievement achievement) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFF63A36C).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.emoji_events,
                  color: Color(0xFF63A36C),
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🎉 ${achievement.name}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Gilroy',
                      ),
                    ),
                    if (achievement.points > 0)
                      Text(
                        '+${achievement.points} баллов',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFamily: 'Gilroy',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Color(0xFF63A36C),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Посмотреть',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (context) => AchievementsPage()
              )
            );
          },
        ),
      ),
    );
  }

  // НОВЫЙ МЕТОД: Toast уведомление для достижений при сканировании
  static void showToast(BuildContext context, Achievement achievement, {Duration? duration}) {
    if (!context.mounted) return;

    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => _AchievementToast(
        achievement: achievement,
        duration: duration ?? Duration(seconds: 4),
      ),
    );

    overlay.insert(overlayEntry);

    // Автоматически убираем toast через указанное время
    Timer(duration ?? Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}

// НОВЫЙ КЛАСС: Анимация для TweenAnimationBuilder с задержкой
class DelayedAnimationBuilder extends StatefulWidget {
  final Widget Function(BuildContext, double, Widget?) builder;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final Tween<double> tween;

  const DelayedAnimationBuilder({
    Key? key,
    required this.builder,
    required this.duration,
    this.delay = Duration.zero,
    this.curve = Curves.linear,
    required this.tween,
  }) : super(key: key);

  @override
  State<DelayedAnimationBuilder> createState() => _DelayedAnimationBuilderState();
}

class _DelayedAnimationBuilderState extends State<DelayedAnimationBuilder> {
  late double _value;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    _value = widget.tween.begin ?? 0.0;
    
    Future.delayed(widget.delay, () {
      if (mounted) {
        setState(() {
          _hasStarted = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: _hasStarted ? widget.tween : Tween<double>(begin: _value, end: _value),
      duration: widget.duration,
      curve: widget.curve,
      builder: widget.builder,
    );
  }
}

// Вспомогательный класс для анимации с задержкой
class _AchievementToast extends StatefulWidget {
  final Achievement achievement;
  final Duration duration;

  const _AchievementToast({
    Key? key,
    required this.achievement,
    required this.duration,
  }) : super(key: key);

  @override
  _AchievementToastState createState() => _AchievementToastState();
}

class _AchievementToastState extends State<_AchievementToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 300),
      reverseDuration: Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, -1),
      end: Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));

    // Запускаем анимацию появления
    _controller.forward();

    // Запускаем анимацию исчезновения за 300мс до конца
    Timer(widget.duration - Duration(milliseconds: 300), () {
      if (mounted) {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF63A36C),
                  Color(0xFF52934B),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Иконка достижения
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.emoji_events,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                // Текст достижения
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '🎉 ${widget.achievement.name}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Gilroy',
                        ),
                      ),
                      if (widget.achievement.points > 0)
                        Text(
                          '+${widget.achievement.points} баллов',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontFamily: 'Gilroy',
                          ),
                        ),
                    ],
                  ),
                ),
                // Кнопка "Посмотреть"
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AchievementsPage(),
                        ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Посмотреть',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Gilroy',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 