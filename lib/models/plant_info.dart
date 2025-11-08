import 'package:flutter/foundation.dart';

class PlantInfo {
  final String name;
  final String latinName;
  final bool isHealthy;
  final String description;
  final List<String> tags;
  final String difficultyLevel;
  
  // Новые поля для расширенной структуры
  final Map<String, dynamic> toxicity;
  final Map<String, dynamic> careInfo;
  final Map<String, dynamic> growingConditions;
  final Map<String, dynamic> pestsAndDiseases;
  final Map<String, dynamic> seasonalCare;
  final Map<String, dynamic> additionalInfo;
  final Map<String, String> images;
  final String scanId;

  PlantInfo({
    required this.name,
    this.latinName = '',
    this.isHealthy = true,
    this.description = '',
    required this.tags,
    this.difficultyLevel = 'medium',
    required this.toxicity,
    required this.careInfo,
    required this.growingConditions,
    required this.pestsAndDiseases,
    required this.seasonalCare,
    required this.additionalInfo,
    required this.images,
    this.scanId = '',
  }) {
    // Проверяем, что все коллекции не null
    assert(tags != null, 'tags не может быть null');
    assert(toxicity != null, 'toxicity не может быть null');
    assert(careInfo != null, 'careInfo не может быть null');
    assert(growingConditions != null, 'growingConditions не может быть null');
    assert(pestsAndDiseases != null, 'pestsAndDiseases не может быть null');
    assert(seasonalCare != null, 'seasonalCare не может быть null');
    assert(additionalInfo != null, 'additionalInfo не может быть null');
    assert(images != null, 'images не может быть null');
  }

  // Фабричный метод для безопасного создания объекта из JSON
  factory PlantInfo.fromJson(Map<String, dynamic> json) {
    // print('🌱 === СОЗДАНИЕ PlantInfo ИЗ JSON ===');
    // print('📄 Полученные данные: ${json.toString()}');
    
    // Умный поиск названия растения в разных местах JSON
    String name = 'Неизвестное растение';
    String latinName = '';
    
    // Ищем в разных местах структуры данных
    if (json.containsKey('plant_info') && json['plant_info'] is Map) {
      final plantInfo = json['plant_info'] as Map<String, dynamic>;
      name = plantInfo['name'] ?? name;
      latinName = plantInfo['latin_name'] ?? latinName;
      print('✅ Найден блок plant_info, извлечено название: $name');
    } else if (json.containsKey('result') && json['result'] is Map) {
      final result = json['result'] as Map<String, dynamic>;
      if (result.containsKey('plant_info') && result['plant_info'] is Map) {
        final plantInfo = result['plant_info'] as Map<String, dynamic>;
        name = plantInfo['name'] ?? name;
        latinName = plantInfo['latin_name'] ?? latinName;
        print('✅ Найден блок result.plant_info, извлечено название: $name');
      }
    }
    
    // Если не нашли в структурированных данных, ищем в корневых полях
    if (name == 'Неизвестное растение') {
      name = json['plant_name'] ?? json['name'] ?? name;
      // print('📝 Использую корневое поле plant_name/name: $name');
    }
    
    if (latinName.isEmpty) {
      latinName = json['latin_name'] ?? '';
    }
    
    // Извлекаем данные из новой структуры plant_info или корневых данных
    Map<String, dynamic> plantData = json;
    if (json.containsKey('plant_info') && json['plant_info'] is Map) {
      plantData = json['plant_info'] as Map<String, dynamic>;
    } else if (json.containsKey('result') && json['result'] is Map && 
               json['result']['plant_info'] is Map) {
      plantData = json['result']['plant_info'] as Map<String, dynamic>;
    }
    
    final isHealthy = plantData['is_healthy'] ?? json['is_healthy'] ?? true;
    final description = plantData['description'] ?? json['description'] ?? '';
    final difficultyLevel = plantData['difficulty_level'] ?? json['difficulty_level'] ?? 'medium';
    
    // print('📝 Базовая информация:');
    // print('   • Название: $name');
    // print('   • Латинское: $latinName');
    // print('   • Здоровое: $isHealthy');
    // print('   • Сложность: $difficultyLevel');
    
    final tags = _getListFromJson(plantData['tags']);
    final toxicity = _getMapFromJson(plantData['toxicity']);
    final careInfo = _getMapFromJson(plantData['care_info']);
    final growingConditions = _getMapFromJson(plantData['growing_conditions']);
    final pestsAndDiseases = _getMapFromJson(plantData['pests_and_diseases']);
    final seasonalCare = _getMapFromJson(plantData['seasonal_care']);
    final additionalInfo = _getMapFromJson(plantData['additional_info']);
    // Получаем изображения из разных возможных полей
    var images = _getImagesMapFromJson(plantData['images']);
    
    // Проверяем дополнительные поля изображений
    if (images.isEmpty) {
      // Ищем в прямом поле photo
      if (json.containsKey('photo') && json['photo'] != null && json['photo'].toString().isNotEmpty) {
        images['photo'] = json['photo'].toString();
        print('📸 Найдено изображение в поле photo: ${json['photo']}');
      }
      
      // Ищем в других возможных полях
      final imageFields = ['image', 'picture', 'avatar', 'main_image', 'user_image'];
      for (String field in imageFields) {
        if (json.containsKey(field) && json[field] != null && json[field].toString().isNotEmpty) {
          images[field] = json[field].toString();
          print('📸 Найдено изображение в поле $field: ${json[field]}');
        }
      }
    }
    
    final scanId = plantData['scan_id'] ?? json['_id'] ?? '';
    
    // print('📊 Структурированные данные:');
    // print('   • Теги: ${tags.length} элементов');
    // print('   • Токсичность: ${toxicity.keys.join(", ")}');
    // print('   • Уход: ${careInfo.keys.join(", ")}');
    // print('   • Условия: ${growingConditions.keys.join(", ")}');
    // print('   • Вредители/болезни: ${pestsAndDiseases.keys.join(", ")}');
    // print('   • Сезонный уход: ${seasonalCare.keys.join(", ")}');
    // print('   • Доп.инфо: ${additionalInfo.keys.join(", ")}');
    // print('   • Изображения: ${images.keys.join(", ")} (всего: ${images.length})');
    
    // print('✅ PlantInfo успешно создан');
    // print('🌱 === КОНЕЦ СОЗДАНИЯ PlantInfo ===\n');

    return PlantInfo(
      name: name,
      latinName: latinName,
      isHealthy: isHealthy,
      description: description,
      tags: tags,
      difficultyLevel: difficultyLevel,
      toxicity: toxicity,
      careInfo: careInfo,
      growingConditions: growingConditions,
      pestsAndDiseases: pestsAndDiseases,
      seasonalCare: seasonalCare,
      additionalInfo: additionalInfo,
      images: images,
      scanId: scanId,
    );
  }

  // Статические методы для безопасного получения данных
  static List<String> _getListFromJson(dynamic json) {
    if (json == null) return [];
    if (json is List) {
      return json.map((e) => e?.toString() ?? '').toList();
    }
    return [];
  }

  static Map<String, dynamic> _getMapFromJson(dynamic json) {
    if (json == null) return {};
    if (json is Map) {
      return Map<String, dynamic>.from(json);
    }
    return {};
  }

  static Map<String, String> _getImagesMapFromJson(dynamic json) {
    if (json == null) return {};
    if (json is Map) {
      final result = <String, String>{};
      json.forEach((key, value) {
        if (key is String && value != null) {
          result[key] = value.toString();
        }
      });
      return result;
    }
    return {};
  }

  // Метод для создания копии с изменениями
  PlantInfo copyWith({
    String? name,
    String? latinName,
    bool? isHealthy,
    String? description,
    List<String>? tags,
    String? difficultyLevel,
    Map<String, dynamic>? toxicity,
    Map<String, dynamic>? careInfo,
    Map<String, dynamic>? growingConditions,
    Map<String, dynamic>? pestsAndDiseases,
    Map<String, dynamic>? seasonalCare,
    Map<String, dynamic>? additionalInfo,
    Map<String, String>? images,
    String? scanId,
  }) {
    return PlantInfo(
      name: name ?? this.name,
      latinName: latinName ?? this.latinName,
      isHealthy: isHealthy ?? this.isHealthy,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      toxicity: toxicity ?? this.toxicity,
      careInfo: careInfo ?? this.careInfo,
      growingConditions: growingConditions ?? this.growingConditions,
      pestsAndDiseases: pestsAndDiseases ?? this.pestsAndDiseases,
      seasonalCare: seasonalCare ?? this.seasonalCare,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      images: images ?? this.images,
      scanId: scanId ?? this.scanId,
    );
  }

  // Вспомогательные методы для получения automation данных
  Map<String, dynamic>? getWateringAutomation() {
    print('💧 Получение automation данных для полива');
    if (careInfo.containsKey('watering') && careInfo['watering'] is Map) {
      final watering = careInfo['watering'] as Map<String, dynamic>;
      if (watering.containsKey('automation') && watering['automation'] is Map) {
        final automation = watering['automation'] as Map<String, dynamic>;
        print('✅ Найдены automation данные для полива: $automation');
        return automation;
      }
    }
    print('❌ Automation данные для полива не найдены');
    return null;
  }

  Map<String, dynamic>? getFertilizingAutomation() {
    print('🌱 Получение automation данных для подкормки');
    if (careInfo.containsKey('fertilizing') && careInfo['fertilizing'] is Map) {
      final fertilizing = careInfo['fertilizing'] as Map<String, dynamic>;
      if (fertilizing.containsKey('automation') && fertilizing['automation'] is Map) {
        final automation = fertilizing['automation'] as Map<String, dynamic>;
        print('✅ Найдены automation данные для подкормки: $automation');
        return automation;
      }
    }
    print('❌ Automation данные для подкормки не найдены');
    return null;
  }

  Map<String, dynamic>? getSprayingAutomation() {
    print('💨 Получение automation данных для орошения');
    if (careInfo.containsKey('spraying') && careInfo['spraying'] is Map) {
      final spraying = careInfo['spraying'] as Map<String, dynamic>;
      if (spraying.containsKey('automation') && spraying['automation'] is Map) {
        final automation = spraying['automation'] as Map<String, dynamic>;
        print('✅ Найдены automation данные для орошения: $automation');
        return automation;
      }
    }
    print('❌ Automation данные для орошения не найдены');
    return null;
  }

  Map<String, dynamic>? getTemperatureData() {
    print('🌡️ Получение данных о температуре');
    if (growingConditions.containsKey('temperature') && growingConditions['temperature'] is Map) {
      final temperature = growingConditions['temperature'] as Map<String, dynamic>;
      print('✅ Найдены данные о температуре: $temperature');
      return temperature;
    }
    print('❌ Данные о температуре не найдены');
    return null;
  }

  List<Map<String, dynamic>> getDetectedProblems() {
    print('🔍 Поиск обнаруженных проблем растения');
    final problems = <Map<String, dynamic>>[];
    
    if (pestsAndDiseases.containsKey('common_problems') && pestsAndDiseases['common_problems'] is Map) {
      final commonProblems = pestsAndDiseases['common_problems'] as Map<String, dynamic>;
      
      commonProblems.forEach((problemType, problemData) {
        if (problemData is Map && problemData['detected'] == true) {
          problems.add({
            'type': problemType,
            'data': problemData,
          });
          print('🚨 Обнаружена проблема: $problemType');
        }
      });
    }
    
    print('📊 Всего обнаружено проблем: ${problems.length}');
    return problems;
  }
} 