class Achievement {
  final String id;
  final String userId;
  final AchievementTemplate? template;
  final String name;
  final String description;
  final String iconUrl;
  final int points;
  final Map<String, dynamic>? metadata;
  final DateTime date;

  Achievement({
    required this.id,
    required this.userId,
    this.template,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.points,
    this.metadata,
    required this.date,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['_id'] ?? '',
      userId: json['user'] ?? '',
      template: json['template'] != null 
          ? AchievementTemplate.fromJson(json['template'])
          : null,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      iconUrl: json['iconUrl'] ?? '',
      points: json['points'] ?? 0,
      metadata: json['metadata'],
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'user': userId,
      'template': template?.toJson(),
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'points': points,
      'metadata': metadata,
      'date': date.toIso8601String(),
    };
  }
}

class AchievementTemplate {
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final int points;
  final String achievementType;
  final String category;

  AchievementTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.points,
    required this.achievementType,
    required this.category,
  });

  factory AchievementTemplate.fromJson(Map<String, dynamic> json) {
    return AchievementTemplate(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      iconUrl: json['iconUrl'] ?? '',
      points: json['points'] ?? 0,
      achievementType: json['achievementType'] ?? '',
      category: json['category'] ?? _getCategoryFromType(json['achievementType'] ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'points': points,
      'achievementType': achievementType,
      'category': category,
    };
  }

  // Определить категорию на основе типа достижения
  static String _getCategoryFromType(String achievementType) {
    if (achievementType.contains('scan') || achievementType.contains('plant')) {
      return 'Сканирование';
    } else if (achievementType.contains('reminder') || achievementType.contains('care')) {
      return 'Напоминания';
    } else if (achievementType.contains('daily') || achievementType.contains('login')) {
      return 'Активность';
    } else if (achievementType.contains('chat') || achievementType.contains('ai')) {
      return 'Чат с ИИ';
    } else if (achievementType.contains('favorite') || achievementType.contains('like')) {
      return 'Избранное';
    } else {
      return 'Общие';
    }
  }
}

class AchievementStats {
  final int totalAchievements;
  final int totalPoints;
  final Map<String, int> achievementsByType;
  final List<Achievement> recentAchievements;

  AchievementStats({
    required this.totalAchievements,
    required this.totalPoints,
    required this.achievementsByType,
    required this.recentAchievements,
  });

  factory AchievementStats.fromJson(Map<String, dynamic> json) {
    return AchievementStats(
      totalAchievements: json['totalAchievements'] ?? 0,
      totalPoints: json['totalPoints'] ?? 0,
      achievementsByType: Map<String, int>.from(json['achievementsByType'] ?? {}),
      recentAchievements: (json['recentAchievements'] as List<dynamic>?)
          ?.map((item) => Achievement.fromJson(item))
          .toList() ?? [],
    );
  }
}

// НОВЫЕ МОДЕЛИ ДЛЯ ПРОГРЕССА

class AchievementProgress {
  final int current;
  final int next;
  final List<int> thresholds;
  final double progress; // Прогресс до следующего достижения (0.0 - 1.0)

  AchievementProgress({
    required this.current,
    required this.next,
    required this.thresholds,
  }) : progress = next > 0 ? current / next : 1.0;

  factory AchievementProgress.fromJson(Map<String, dynamic> json) {
    return AchievementProgress(
      current: json['current'] ?? 0,
      next: json['next'] ?? 1,
      thresholds: List<int>.from(json['thresholds'] ?? []),
    );
  }

  // Получить процент для отображения
  String get progressPercent => '${(progress * 100).toInt()}%';
  
  // Проверить, достигнут ли следующий порог
  bool get isNextThresholdReached => current >= next;
}

class UserProgress {
  final AchievementProgress scan;
  final AchievementProgress reminder;
  final AchievementProgress daily;
  final AchievementProgress chat;
  final AchievementProgress favorite;

  UserProgress({
    required this.scan,
    required this.reminder,
    required this.daily,
    required this.chat,
    required this.favorite,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      scan: AchievementProgress.fromJson(json['scan'] ?? {}),
      reminder: AchievementProgress.fromJson(json['reminder'] ?? {}),
      daily: AchievementProgress.fromJson(json['daily'] ?? {}),
      chat: AchievementProgress.fromJson(json['chat'] ?? {}),
      favorite: AchievementProgress.fromJson(json['favorite'] ?? {}),
    );
  }

  // Получить прогресс по типу
  AchievementProgress getProgressByType(String type) {
    switch (type.toLowerCase()) {
      case 'scan':
        return scan;
      case 'reminder':
        return reminder;
      case 'daily':
        return daily;
      case 'chat':
        return chat;
      case 'favorite':
        return favorite;
      default:
        return scan; // Fallback
    }
  }
} 