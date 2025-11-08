import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/plant_info.dart';

class PlantResultUtils {
  // Метод для парсинга температуры из различных форматов
  static double? parseTemperature(dynamic tempValue) {
    if (tempValue == null) return null;
    
    if (tempValue is num) {
      return tempValue.toDouble();
    }
    
    if (tempValue is String) {
      final temp = tempValue.toString();
      print('Парсинг температуры: "$temp"');
      
      // Для диапазонов типа "+20…+25°C" или "20-25" берем первое число
      final rangeMatch = RegExp(r'[+]?(\d+)[°…\-—~]').firstMatch(temp);
      if (rangeMatch != null) {
        final firstNumber = double.tryParse(rangeMatch.group(1)!);
        print('Найден диапазон, используем первое число: $firstNumber');
        return firstNumber;
      }
      
      // Для обычных чисел с символами "+15°C"
      final simpleMatch = RegExp(r'[+]?(\d+(?:\.\d+)?)').firstMatch(temp);
      if (simpleMatch != null) {
        final number = double.tryParse(simpleMatch.group(1)!);
        print('Найдено простое число: $number');
        return number;
      }
      
      print('Не удалось распарсить температуру: "$temp"');
    }
    
    return null;
  }

  // Новый метод для парсинга числовых температур
  static double? parseTemperatureNumber(dynamic value) {
    if (value == null) return null;
    
    if (value is num) {
      return value.toDouble();
    }
    
    if (value is String) {
      // Убираем символы градусов и другие символы
      final cleanValue = value.replaceAll(RegExp(r'[°C]'), '').trim();
      return double.tryParse(cleanValue);
    }
    
    return null;
  }

  // Метод для вычисления позиции слайдера
  static double calculateSliderPosition(double temperature) {
    const sliderWidth = 200.0;
    const fullRange = 71.0; // от -17 до 54 = 71 градусов
    final normalizedTemp = (temperature + 17) / fullRange;
    final position = normalizedTemp * sliderWidth;
    
    // Ограничиваем позицию слайдера
    return position.clamp(0.0, sliderWidth - 70);
  }

  // Одиночная проверка доступности изображения
  static Future<bool> checkImageAvailabilityOnce(String imageUrl) async {
    try {
      print('🔍 ===== ОДИНОЧНАЯ ПРОВЕРКА ИЗОБРАЖЕНИЯ =====');
      print('🔗 Проверяем доступность: $imageUrl');
      
      final response = await http.head(Uri.parse(imageUrl)).timeout(const Duration(seconds: 10));
      final isAvailable = response.statusCode == 200;
      
      print('📊 Статус код: ${response.statusCode}');
      print('📏 Content-Length: ${response.headers['content-length'] ?? "не указан"}');
      print('🎨 Content-Type: ${response.headers['content-type'] ?? "не указан"}');
      print('🕒 Date: ${response.headers['date'] ?? "не указан"}');
      print('🔧 Server: ${response.headers['server'] ?? "не указан"}');
      
      if (isAvailable) {
        print('✅ Изображение ДОСТУПНО - можно загружать');
      } else {
        print('⚠️ Изображение НЕДОСТУПНО (${response.statusCode})');
      }
      
      print('🔍 ===== КОНЕЦ ОДИНОЧНОЙ ПРОВЕРКИ =====');
      return isAvailable;
    } catch (e) {
      print('❌ ОШИБКА при проверке изображения: $e');
      print('🔍 ===== КОНЕЦ ОДИНОЧНОЙ ПРОВЕРКИ (ОШИБКА) =====');
      return false;
    }
  }

  // Проактивная проверка доступности изображений
  static void checkImageAvailability(String? mainImageUrl, String? avatarImageUrl) async {
    print('🔍 ===== НАЧАЛО ПРОВЕРКИ ДОСТУПНОСТИ ИЗОБРАЖЕНИЙ =====');
    
    if (mainImageUrl != null && mainImageUrl.isNotEmpty) {
      print('📸 Проверяем ГЛАВНОЕ изображение: $mainImageUrl');
      try {
        final response = await http.head(Uri.parse(mainImageUrl)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          print('✅ Главное изображение ДОСТУПНО (${response.statusCode})');
          print('📏 Content-Length: ${response.headers['content-length'] ?? "не указан"}');
          print('🎨 Content-Type: ${response.headers['content-type'] ?? "не указан"}');
        } else {
          print('⚠️ Главное изображение НЕДОСТУПНО, код: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Ошибка проверки главного изображения: $e');
      }
    } else {
      print('⚠️ Главное изображение не установлено для проверки');
    }
    
    if (avatarImageUrl != null && avatarImageUrl.isNotEmpty) {
      print('👤 Проверяем АВАТАР изображение: $avatarImageUrl');
      try {
        final response = await http.head(Uri.parse(avatarImageUrl)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          print('✅ Аватар изображение ДОСТУПНО (${response.statusCode})');
          print('📏 Content-Length: ${response.headers['content-length'] ?? "не указан"}');
          print('🎨 Content-Type: ${response.headers['content-type'] ?? "не указан"}');
        } else {
          print('⚠️ Аватар изображение НЕДОСТУПНО, код: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Ошибка проверки аватар изображения: $e');
      }
    } else {
      print('⚠️ Аватар изображение не установлено для проверки');
    }
    
    print('🔍 ===== КОНЕЦ ПРОВЕРКИ ДОСТУПНОСТИ ИЗОБРАЖЕНИЙ =====');
  }

  // Получение рекомендаций по поливу
  static String getWateringRecommendations(dynamic plantData) {
    if (plantData != null && plantData is PlantInfo) {
      if (plantData.careInfo.containsKey('watering') && 
          plantData.careInfo['watering'] is Map) {
        
        final wateringData = plantData.careInfo['watering'] as Map;
        // 1) Предпочитаем текстовое описание (чтобы совпадало с краткой карточкой)
        final description = wateringData['description']?.toString();
        if (description != null && description.isNotEmpty && description != 'data_not_available') {
          return description;
        }

        // 2) Затем отдельные рекомендации, если они есть
        final recs = wateringData['recommendations']?.toString();
        if (recs != null && recs.isNotEmpty && recs != 'data_not_available') {
          return recs;
        }

        // 3) Fallback: составляем краткую рекомендацию из automation
        if (wateringData.containsKey('automation') && wateringData['automation'] is Map) {
          final automation = wateringData['automation'] as Map;
          final interval = automation['interval_days']?.toString();
          final amount = automation['amount']?.toString();
          if (interval != null && interval.isNotEmpty) {
            var text = 'Поливать каждые $interval дней';
            if (amount != null && amount.isNotEmpty) {
              text += ', $amount';
            }
            return text;
          }
        }
      }
    }
    
    // Универсальные рекомендации по умолчанию
    return 'Поливайте растение когда верхний слой почвы подсохнет. Используйте мягкую воду комнатной температуры. В зимний период сократите полив. Избегайте переливания - это может привести к загниванию корней.';
  }

  // НОВОЕ: Получение подробной информации о температуре
  static String getTemperatureDetails(dynamic plantData) {
    if (plantData != null && plantData is PlantInfo) {
      if (plantData.growingConditions.containsKey('temperature') && 
          plantData.growingConditions['temperature'] is Map) {
        final tempData = plantData.growingConditions['temperature'] as Map<String, dynamic>;
        
        List<String> details = [];
        
        // Добавляем оптимальную температуру
        double? minTemp = parseTemperatureNumber(tempData['optimal_min']);
        double? maxTemp = parseTemperatureNumber(tempData['optimal_max']);
        
        if (minTemp != null && maxTemp != null) {
          details.add('Оптимальная температура: ${minTemp.toInt()}°C – ${maxTemp.toInt()}°C');
        }
        
        // Добавляем рекомендации по температуре
        if (tempData.containsKey('recommendations') && 
            tempData['recommendations'] != null &&
            tempData['recommendations'].toString().isNotEmpty) {
          details.add(tempData['recommendations'].toString());
        }
        
        // Добавляем информацию о зимнем периоде
        if (tempData.containsKey('winter_temperature') && 
            tempData['winter_temperature'] != null) {
          final winterTemp = tempData['winter_temperature'].toString();
          if (winterTemp.isNotEmpty) {
            details.add('Зимняя температура: $winterTemp');
          }
        }
        
        if (details.isNotEmpty) {
          return details.join('\n\n');
        }
      }
    }
    
    // Общие рекомендации по температуре
    return 'Большинство комнатных растений предпочитают температуру 18-24°C днем и 16-20°C ночью. Избегайте резких перепадов температур и сквозняков. В зимний период многие растения предпочитают более прохладные условия.';
  }

  // Перевод типов проблем
  static String translateProblemType(String type) {
    switch (type) {
      case 'yellow_leaves':
        return 'Желтые листья';
      case 'brown_leaf_tips':
        return 'Коричневые кончики листьев';
      case 'dropping_leaves':
        return 'Опадание листьев';
      case 'slow_growth':
        return 'Медленный рост';
      case 'wilting':
        return 'Увядание';
      default:
        return type;
    }
  }
} 