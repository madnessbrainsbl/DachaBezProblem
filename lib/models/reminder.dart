import 'plant_info.dart';

// Класс для данных о выполнении напоминания
class ReminderCompletion {
  final String? id;
  final String reminderId;
  final DateTime completionDate;
  final String? note;
  final DateTime completedAt;

  ReminderCompletion({
    this.id,
    required this.reminderId,
    required this.completionDate,
    this.note,
    required this.completedAt,
  });

  factory ReminderCompletion.fromJson(Map<String, dynamic> json) {
    return ReminderCompletion(
      id: json['_id'],
      reminderId: json['reminder'],
      completionDate: DateTime.parse(json['completionDate']),
      note: json['note'],
      completedAt: DateTime.parse(json['completedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'reminder': reminderId,
      'completionDate': completionDate.toIso8601String(),
      if (note != null) 'note': note,
      'completedAt': completedAt.toIso8601String(),
    };
  }
}

// Новый класс для информации о лечении/обработке
class Treatment {
  final String? method;
  final String? preparation;
  final String? concentration;
  final String? safetyNotes;
  
  Treatment({
    this.method,
    this.preparation,
    this.concentration,
    this.safetyNotes,
  });
  
  factory Treatment.fromJson(Map<String, dynamic> json) {
    return Treatment(
      method: json['method'],
      preparation: json['preparation'],
      concentration: json['concentration'],
      safetyNotes: json['safety_notes'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      if (method != null) 'method': method,
      if (preparation != null) 'preparation': preparation,
      if (concentration != null) 'concentration': concentration,
      if (safetyNotes != null) 'safety_notes': safetyNotes,
    };
  }
}

class Reminder {
  final String? id;
  final String userId;
  final String plantId;
  final String type; // watering, spraying, fertilizing, transplanting, pruning, pest_control, disease_treatment
  final String timeOfDay; // morning, afternoon, evening
  final List<int> daysOfWeek; // 0-6 (0=воскресенье, 6=суббота)
  final bool repeatWeekly;
  final int? intervalDays; // интервал для напоминаний типа "каждые 5 дней"
  final int? intervalWeeks; // интервал для напоминаний типа "каждые 2 недели"  
  final int? intervalMonths; // интервал для напоминаний типа "каждые 3 месяца"
  final DateTime date;
  final String? note;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Новые поля для системы выполнения
  final bool isCompleted; // выполнено ли действие на сегодня
  final ReminderCompletion? completion; // данные о выполнении
  
  // Поля для обработки исключений
  final String? effectiveTime; // эффективное время в формате HH:mm (из исключений)
  final bool isModifiedForThisDate; // было ли напоминание изменено для этой даты
  final bool? isDeletedForDate; // удалено ли напоминание для конкретной даты
  
  // Новое поле для информации о лечении/обработке
  final Treatment? treatment;
  
  // Связанные данные
  final PlantInfo? plant;

  Reminder({
    this.id,
    required this.userId,
    required this.plantId,
    required this.type,
    required this.timeOfDay,
    required this.daysOfWeek,
    required this.repeatWeekly,
    this.intervalDays,
    this.intervalWeeks,
    this.intervalMonths,
    required this.date,
    this.note,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.isCompleted = false,
    this.completion,
    this.effectiveTime,
    this.isModifiedForThisDate = false,
    this.isDeletedForDate,
    this.treatment,
    this.plant,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    // Обработка пользователя (может быть строкой или объектом)
    String userId;
    if (json['user'] is String) {
      userId = json['user'];
    } else if (json['user'] is Map && json['user']['_id'] != null) {
      userId = json['user']['_id'];
    } else {
      userId = '';
    }
    
    // Обработка растения (может быть строкой или объектом)
    String plantId;
    PlantInfo? plantInfo;
    if (json['plant'] is String) {
      plantId = json['plant'];
    } else if (json['plant'] is Map) {
      plantId = json['plant']['_id'] ?? '';
      try {
        plantInfo = PlantInfo.fromJson(json['plant']);
      } catch (e) {
        print('⚠️ Ошибка парсинга PlantInfo в Reminder: $e');
        plantInfo = null;
      }
    } else {
      plantId = '';
    }
    
    // Обработка completion
    ReminderCompletion? completionData;
    if (json['completion'] != null) {
      try {
        completionData = ReminderCompletion.fromJson(json['completion']);
      } catch (e) {
        print('⚠️ Ошибка парсинга ReminderCompletion: $e');
      }
    }
    
    // Обработка treatment
    Treatment? treatmentData;
    if (json['treatment'] != null) {
      try {
        treatmentData = Treatment.fromJson(json['treatment']);
      } catch (e) {
        print('⚠️ Ошибка парсинга Treatment: $e');
      }
    }
    
    // Обработка эффективного времени (если есть исключения)
    DateTime effectiveDate;
    String? effectiveTime;
    bool isModifiedForThisDate = false;
    
    if (json['effectiveDate'] != null) {
      effectiveDate = DateTime.parse(json['effectiveDate']);
      effectiveTime = json['effectiveTime']; // время в формате HH:mm
      isModifiedForThisDate = json['isModifiedForThisDate'] ?? false;
      print('🎯 Используем эффективную дату из исключения: $effectiveDate');
      print('⏰ Эффективное время: $effectiveTime');
      print('✏️ Изменено для этой даты: $isModifiedForThisDate');
    } else {
      effectiveDate = DateTime.parse(json['date']);
      print('📅 Используем оригинальную дату: $effectiveDate');
    }
    
    return Reminder(
      id: json['_id'],
      userId: userId,
      plantId: plantId,
      type: json['type'],
      timeOfDay: json['timeOfDay'],
      daysOfWeek: List<int>.from(json['daysOfWeek'] ?? []),
      repeatWeekly: json['repeatWeekly'] ?? false,
      intervalDays: json['intervalDays'],
      intervalWeeks: json['intervalWeeks'],
      intervalMonths: json['intervalMonths'],
      date: effectiveDate, // Используем эффективную дату
      note: json['note'],
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      isCompleted: json['isCompleted'] ?? false,
      completion: completionData,
      effectiveTime: effectiveTime,
      isModifiedForThisDate: isModifiedForThisDate,
      isDeletedForDate: json['isDeletedForDate'],
      treatment: treatmentData,
      plant: plantInfo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      if (userId.isNotEmpty) 'user': userId,
      'plant': plantId,
      'type': type,
      'timeOfDay': timeOfDay,
      'daysOfWeek': daysOfWeek,
      'repeatWeekly': repeatWeekly,
      if (intervalDays != null) 'intervalDays': intervalDays,
      if (intervalWeeks != null) 'intervalWeeks': intervalWeeks,
      if (intervalMonths != null) 'intervalMonths': intervalMonths,
      'date': date.toIso8601String(),
      if (note != null) 'note': note,
      'isActive': isActive,
      if (treatment != null) 'treatment': treatment!.toJson(),
    };
  }

  Reminder copyWith({
    String? id,
    String? userId,
    String? plantId,
    String? type,
    String? timeOfDay,
    List<int>? daysOfWeek,
    bool? repeatWeekly,
    int? intervalDays,
    int? intervalWeeks,
    int? intervalMonths,
    DateTime? date,
    String? note,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isCompleted,
    ReminderCompletion? completion,
    String? effectiveTime,
    bool? isModifiedForThisDate,
    bool? isDeletedForDate,
    Treatment? treatment,
    PlantInfo? plant,
  }) {
    return Reminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      plantId: plantId ?? this.plantId,
      type: type ?? this.type,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      repeatWeekly: repeatWeekly ?? this.repeatWeekly,
      intervalDays: intervalDays ?? this.intervalDays,
      intervalWeeks: intervalWeeks ?? this.intervalWeeks,
      intervalMonths: intervalMonths ?? this.intervalMonths,
      date: date ?? this.date,
      note: note ?? this.note,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isCompleted: isCompleted ?? this.isCompleted,
      completion: completion ?? this.completion,
      effectiveTime: effectiveTime ?? this.effectiveTime,
      isModifiedForThisDate: isModifiedForThisDate ?? this.isModifiedForThisDate,
      isDeletedForDate: isDeletedForDate ?? this.isDeletedForDate,
      treatment: treatment ?? this.treatment,
      plant: plant ?? this.plant,
    );
  }
  
  // Метод для получения эффективного времени (учитывает исключения)
  DateTime getEffectiveDateTime() {
    print('🔍 getEffectiveDateTime: effectiveTime=$effectiveTime, isModifiedForThisDate=$isModifiedForThisDate');
    
    if (effectiveTime != null && isModifiedForThisDate) {
      // Парсим время из строки HH:mm
      final timeParts = effectiveTime!.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      print('🕐 Парсим эффективное время: $hour:$minute из $effectiveTime');
      
      // Возвращаем дату с эффективным временем
      final effectiveDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );
      
      print('🎯 Возвращаем эффективное время: $effectiveDateTime');
      return effectiveDateTime;
    }
    
    print('📅 Возвращаем оригинальное время: $date');
    // Возвращаем оригинальное время
    return date;
  }
  
  // Метод для получения отображаемого времени
  String getDisplayTime() {
    if (effectiveTime != null && isModifiedForThisDate) {
      return effectiveTime!;
    }
    
    // Форматируем оригинальное время
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// Константы для типов напоминаний
class ReminderTypes {
  static const String watering = 'watering';
  static const String spraying = 'spraying';
  static const String fertilizing = 'fertilizing';
  static const String transplanting = 'transplanting';
  static const String pruning = 'pruning';
  static const String pestControl = 'pest_control';
  static const String diseaseControl = 'disease_treatment';
  static const String rotation = 'rotation';           // ← НОВОЕ: Вращение
  static const String customTask = 'custom_task';      // ← НОВОЕ: Моя задача

  static const Map<String, String> typeNames = {
    watering: 'Полив',
    spraying: 'Орошение',
    fertilizing: 'Удобрение',
    transplanting: 'Пересадка',
    pruning: 'Обрезка',
    pestControl: 'Обработка от вредителей',
    diseaseControl: 'Обработка от болезней',
    rotation: 'Вращение',
    customTask: 'Моя задача',
  };

  static const Map<String, String> typeIcons = {
    watering: '💧',
    spraying: '🌿',
    fertilizing: '🌱',
    transplanting: '🪴',
    pruning: '✂️',
    pestControl: '🐛',
    diseaseControl: '🍄',
    rotation: '🔄',
    customTask: '📋',
  };
  
  static List<String> get allTypes => [
    watering, spraying, fertilizing, transplanting, pruning,
    pestControl, diseaseControl, rotation, customTask
  ];
}

// Константы для времени дня
class TimeOfDay {
  static const String morning = 'morning';
  static const String afternoon = 'afternoon';
  static const String evening = 'evening';

  static const Map<String, String> timeNames = {
    morning: 'Утром',
    afternoon: 'Днем',
    evening: 'Вечером',
  };

  static const Map<String, String> timeIcons = {
    morning: '🌅',
    afternoon: '☀️',
    evening: '🌙',
  };
}

// Класс для календарных данных
class CalendarReminders {
  final Map<String, List<Reminder>> reminders;
  final String month;
  final int total;

  CalendarReminders({
    required this.reminders,
    required this.month,
    required this.total,
  });

  factory CalendarReminders.fromJson(Map<String, dynamic> json) {
    final Map<String, List<Reminder>> remindersMap = {};
    
    if (json['reminders'] != null) {
      (json['reminders'] as Map<String, dynamic>).forEach((date, remindersList) {
        remindersMap[date] = (remindersList as List)
            .map((reminderJson) => Reminder.fromJson(reminderJson))
            .toList();
      });
    }

    return CalendarReminders(
      reminders: remindersMap,
      month: json['month'] ?? '',
      total: json['total'] ?? 0,
    );
  }
} 