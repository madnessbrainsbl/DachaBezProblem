import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../logger.dart';
import '../../config/api_config.dart';
import 'api_exceptions.dart';

/// Модель препарата для лечения болезней растений
class TreatmentRecommendation {
  final String id;
  final String diseaseName;
  final String productName;
  final String? productImage;
  final String? diseaseDescription;
  final String? dosage;
  final String? purchaseLink;
  final DateTime createdAt;

  TreatmentRecommendation({
    required this.id,
    required this.diseaseName,
    required this.productName,
    this.productImage,
    this.diseaseDescription,
    this.dosage,
    this.purchaseLink,
    required this.createdAt,
  });

  factory TreatmentRecommendation.fromJson(Map<String, dynamic> json) {
    return TreatmentRecommendation(
      id: json['id'] ?? json['_id'] ?? '',
      diseaseName: json['disease_name'] ?? '',
      productName: json['product_name'] ?? '',
      productImage: json['product_image'],
      diseaseDescription: json['disease_description'],
      dosage: json['dosage'],
      purchaseLink: json['purchase_link'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'disease_name': diseaseName,
      'product_name': productName,
      'product_image': productImage,
      'disease_description': diseaseDescription,
      'dosage': dosage,
      'purchase_link': purchaseLink,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Сервис для работы с рекомендациями препаратов
class TreatmentService {
  static final TreatmentService _instance = TreatmentService._internal();
  factory TreatmentService() => _instance;
  TreatmentService._internal();

  static String get baseUrl => ApiConfig.baseUrl;

  /// Получение рекомендаций препаратов по болезням
  Future<List<TreatmentRecommendation>> getRecommendations({
    required List<String> diseases,
    int limit = 5,
  }) async {
    try {
      print('🌐 === НАЧАЛО API ЗАПРОСА РЕКОМЕНДАЦИЙ ===');
      AppLogger.api('Запрос рекомендаций препаратов для болезней: ${diseases.join(", ")}');
      print('🌐 Болезни: ${diseases.join(", ")}');
      print('🌐 Лимит: $limit');
      
      if (diseases.isEmpty) {
        print('🌐 Список болезней пуст, возвращаем пустой список');
        AppLogger.api('Список болезней пуст, возвращаем пустой список');
        return [];
      }

      // Формируем параметры запроса
      final queryParams = <String, String>{
        'diseases': diseases.join(','),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$baseUrl/treatments/recommendations').replace(
        queryParameters: queryParams,
      );

      print('🌐 Base URL: $baseUrl');
      print('🌐 Полный URL: $uri');
      AppLogger.api('URL запроса: $uri');

      // Отправляем GET запрос (публичный endpoint, не требует авторизации)
      print('🌐 Отправляем GET запрос...');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 20));

      print('🌐 Получен ответ со статусом: ${response.statusCode}');
      AppLogger.api('Получен ответ: ${response.statusCode}');
      print('🌐 Размер тела ответа: ${response.body.length} символов');
      print('🌐 Полное тело ответа: ${response.body}');
      AppLogger.api('Тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        print('🌐 Статус 200 - разбираем JSON...');
        final jsonResponse = json.decode(response.body);
        print('🌐 JSON разобран успешно');
        print('🌐 Success: ${jsonResponse['success']}');
        print('🌐 Data: ${jsonResponse['data'] != null}');
        
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final List<dynamic> treatmentsData = jsonResponse['data'] as List;
          print('🌐 Найдено ${treatmentsData.length} записей в data');
          
          final recommendations = treatmentsData
              .map((data) => TreatmentRecommendation.fromJson(data))
              .toList();

          print('🌐 Успешно создано ${recommendations.length} объектов TreatmentRecommendation');
          
          // Если рекомендаций больше чем лимит, рандомизируем выбор
          List<TreatmentRecommendation> finalRecommendations;
          if (recommendations.length > limit) {
            print('🌐 Рекомендаций ${recommendations.length} больше лимита $limit, применяем рандомизацию');
            
            // Перемешиваем список и берем первые limit элементов
            final shuffled = List<TreatmentRecommendation>.from(recommendations);
            shuffled.shuffle(Random());
            finalRecommendations = shuffled.take(limit).toList();
            
            print('🌐 После рандомизации выбрано ${finalRecommendations.length} рекомендаций');
          } else {
            finalRecommendations = recommendations;
            print('🌐 Рекомендаций ${recommendations.length} не превышает лимит $limit, рандомизация не нужна');
          }

          AppLogger.api('Успешно получено ${finalRecommendations.length} рекомендаций');
          print('🌐 === КОНЕЦ API ЗАПРОСА (УСПЕХ) ===');
          return finalRecommendations;
        } else {
          final errorMessage = jsonResponse['message'] ?? 'Не удалось получить рекомендации';
          print('🌐 Ошибка в ответе API: $errorMessage');
          AppLogger.error('Ошибка API: $errorMessage');
          print('🌐 === КОНЕЦ API ЗАПРОСА (ОШИБКА API) ===');
          return [];
        }
      } else {
        print('🌐 Статус НЕ 200: ${response.statusCode}');
        try {
          final jsonResponse = json.decode(response.body);
          final errorMessage = jsonResponse['message'] ?? 'Неизвестная ошибка';
          print('🌐 Сообщение об ошибке: $errorMessage');
          AppLogger.error('Ошибка сервера: $errorMessage (${response.statusCode})');
          print('🌐 === КОНЕЦ API ЗАПРОСА (ОШИБКА СТАТУСА) ===');
          return [];
        } catch (e) {
          print('🌐 Ошибка при разборе JSON ошибки: $e');
          AppLogger.error('Ошибка при разборе ответа сервера: $e');
          print('🌐 === КОНЕЦ API ЗАПРОСА (ОШИБКА ПАРСИНГА) ===');
          return [];
        }
      }
    } catch (e) {
      print('🌐 ИСКЛЮЧЕНИЕ при API запросе: $e');
      AppLogger.error('Ошибка при получении рекомендаций препаратов', e);
      
      if (e.toString().contains('TimeoutException')) {
        print('🌐 Тип ошибки: TimeoutException');
        AppLogger.error('Тайм-аут запроса рекомендаций');
      } else if (e.toString().contains('SocketException')) {
        print('🌐 Тип ошибки: SocketException');
        AppLogger.error('Проблемы с подключением к интернету');
      }
      
      print('🌐 === КОНЕЦ API ЗАПРОСА (ИСКЛЮЧЕНИЕ) ===');
      return [];
    }
  }

  /// Получение списка всех доступных болезней
  Future<List<String>> getAvailableDiseases() async {
    try {
      AppLogger.api('Запрос списка доступных болезней');

      final uri = Uri.parse('$baseUrl/treatments/diseases');
      AppLogger.api('URL запроса: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      AppLogger.api('Получен ответ: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final List<dynamic> diseasesData = jsonResponse['data'] as List;
          final diseases = diseasesData.cast<String>();

          AppLogger.api('Успешно получено ${diseases.length} болезней');
          return diseases;
        } else {
          AppLogger.error('Ошибка API: ${jsonResponse['message']}');
          return [];
        }
      } else {
        AppLogger.error('Ошибка сервера: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      AppLogger.error('Ошибка при получении списка болезней', e);
      return [];
    }
  }

  /// Получение списка всех доступных препаратов
  Future<List<String>> getAvailableProducts() async {
    try {
      AppLogger.api('Запрос списка доступных препаратов');

      final uri = Uri.parse('$baseUrl/treatments/products');
      AppLogger.api('URL запроса: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      AppLogger.api('Получен ответ: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final List<dynamic> productsData = jsonResponse['data'] as List;
          final products = productsData.cast<String>();

          AppLogger.api('Успешно получено ${products.length} препаратов');
          return products;
        } else {
          AppLogger.error('Ошибка API: ${jsonResponse['message']}');
          return [];
        }
      } else {
        AppLogger.error('Ошибка сервера: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      AppLogger.error('Ошибка при получении списка препаратов', e);
      return [];
    }
  }

  /// Извлечение названий болезней и вредителей из данных растения
  List<String> extractDiseaseNames(dynamic plantData) {
    print('🧬 === ИЗВЛЕЧЕНИЕ БОЛЕЗНЕЙ И ВРЕДИТЕЛЕЙ ИЗ РАСТЕНИЯ ===');
    print('🧬 Тип данных: ${plantData?.runtimeType}');
    
    final diseases = <String>[];
    
    try {
      // Проверяем различные возможные структуры данных
      if (plantData != null) {
        print('🧬 Данные растения НЕ null');
        
        // Случай 1: Данные в сыром формате Map (проверяем ПЕРВЫМ!)
        if (plantData is Map) {
          print('🧬 Данные в формате Map');
          print('🧬 Ключи plantData: ${plantData.keys.toList()}');
          
          final pestsAndDiseases = plantData['pests_and_diseases'] as Map?;
          if (pestsAndDiseases != null) {
            print('🧬 Найдено pests_and_diseases в Map');
            print('🧬 Ключи pests_and_diseases: ${pestsAndDiseases.keys.toList()}');
            
            final commonDiseases = pestsAndDiseases['common_diseases'] as List?;
            if (commonDiseases != null) {
              print('🧬 common_diseases найдено: ${commonDiseases.length} элементов');
              for (final disease in commonDiseases) {
                if (disease is Map && disease['name'] != null) {
                  print('🧬 Добавляем болезнь: ${disease['name']}');
                  diseases.add(disease['name'].toString());
                } else if (disease is String) {
                  print('🧬 Добавляем болезнь (строка): $disease');
                  diseases.add(disease);
                }
              }
            }
            
            // Извлекаем общих вредителей (так как препараты могут быть и от вредителей)
            final commonPests = pestsAndDiseases['common_pests'] as List?;
            if (commonPests != null) {
              print('🧬 common_pests найдено: ${commonPests.length} элементов');
              for (final pest in commonPests) {
                if (pest is Map && pest['name'] != null) {
                  print('🧬 Добавляем вредителя: ${pest['name']}');
                  diseases.add(pest['name'].toString());
                } else if (pest is String) {
                  print('🧬 Добавляем вредителя (строка): $pest');
                  diseases.add(pest);
                }
              }
            }
          } else {
            print('🧬 ❌ pests_and_diseases НЕ найдено в Map');
          }
          
          // Также проверяем care_info
          final careInfo = plantData['care_info'] as Map?;
          if (careInfo != null) {
            print('🧬 Найдено care_info, ключи: ${careInfo.keys.toList()}');
            final diseaseControl = careInfo['disease_treatment'] as Map?;
            if (diseaseControl != null) {
              print('🧬 disease_treatment найдено в care_info');
              print('🧬 Содержимое disease_treatment: $diseaseControl');
              diseaseControl.forEach((key, value) {
                if (value is Map && value['disease'] != null) {
                  print('🧬 Добавляем болезнь из disease_treatment: ${value['disease']}');
                  diseases.add(value['disease'].toString());
                }
              });
            } else {
              print('🧬 ❌ disease_treatment НЕ найдено в care_info');
            }
          } else {
            print('🧬 ❌ care_info НЕ найдено в Map');
          }
          
          // ДОПОЛНИТЕЛЬНО: извлекаем болезни из описания и тегов (для "Моей дачи")
          print('🧬 === ДОПОЛНИТЕЛЬНОЕ ИЗВЛЕЧЕНИЕ ДЛЯ "МОЕЙ ДАЧИ" ===');
          
          // Из описания
          final description = plantData['description']?.toString() ?? '';
          if (description.isNotEmpty) {
            print('🧬 Анализируем описание: ${description.substring(0, description.length > 100 ? 100 : description.length)}...');
            final commonDiseaseNames = ['антракноз', 'септориоз', 'мучнистая роса', 'ржавчина', 'пятнистость', 'гниль'];
            for (final diseaseName in commonDiseaseNames) {
              if (description.toLowerCase().contains(diseaseName.toLowerCase())) {
                final capitalizedName = diseaseName[0].toUpperCase() + diseaseName.substring(1);
                if (!diseases.contains(capitalizedName)) {
                  print('🧬 Найдена болезнь в описании: $capitalizedName');
                  diseases.add(capitalizedName);
                }
              }
            }
          }
          
          // Из тегов
          final tags = plantData['tags'] as List?;
          if (tags != null) {
            print('🧬 Анализируем теги: $tags');
            for (final tag in tags) {
              final tagStr = tag.toString().toLowerCase();
              if (tagStr.contains('антракноз')) diseases.add('Антракноз');
              if (tagStr.contains('септориоз')) diseases.add('Септориоз');
              if (tagStr.contains('мучнистая роса')) diseases.add('Мучнистая роса');
              if (tagStr.contains('ржавчина')) diseases.add('Ржавчина');
              if (tagStr.contains('пятнистость')) diseases.add('Пятнистость');
              if (tagStr.contains('гниль')) diseases.add('Гниль');
            }
          }
          
          print('🧬 === КОНЕЦ ДОПОЛНИТЕЛЬНОГО ИЗВЛЕЧЕНИЯ ===');
        }
        // Случай 2: Данные в формате PlantInfo (проверяем ВТОРЫМ!)
        else {
          try {
            if (plantData.pestsAndDiseases != null) {
              print('🧬 Найдено поле pestsAndDiseases в PlantInfo');
              final pestsAndDiseases = plantData.pestsAndDiseases;
              print('🧬 pestsAndDiseases ключи: ${pestsAndDiseases.keys.toList()}');
              
              // Извлекаем общие болезни
              final commonDiseases = pestsAndDiseases['common_diseases'] as List?;
              if (commonDiseases != null) {
                print('🧬 common_diseases найдено: ${commonDiseases.length} элементов');
                for (final disease in commonDiseases) {
                  if (disease is Map && disease['name'] != null) {
                    print('🧬 Добавляем болезнь: ${disease['name']}');
                    diseases.add(disease['name'].toString());
                  } else if (disease is String) {
                    print('🧬 Добавляем болезнь (строка): $disease');
                    diseases.add(disease);
                  }
                }
              }
              
              // Извлекаем общих вредителей (так как препараты могут быть и от вредителей)
              final commonPests = pestsAndDiseases['common_pests'] as List?;
              if (commonPests != null) {
                print('🧬 common_pests найдено: ${commonPests.length} элементов');
                for (final pest in commonPests) {
                  if (pest is Map && pest['name'] != null) {
                    print('🧬 Добавляем вредителя: ${pest['name']}');
                    diseases.add(pest['name'].toString());
                  } else if (pest is String) {
                    print('🧬 Добавляем вредителя (строка): $pest');
                    diseases.add(pest);
                  }
                }
              }
              
              // Извлекаем болезни из disease_treatment
              final diseaseControl = pestsAndDiseases['disease_treatment'] as Map?;
              if (diseaseControl != null) {
                print('🧬 disease_treatment найдено');
                diseaseControl.forEach((key, value) {
                  if (value is Map && value['disease'] != null) {
                    diseases.add(value['disease'].toString());
                  }
                });
              }
            }
          } catch (e) {
            print('🧬 ❌ Не PlantInfo объект: $e');
          }
        }
      } else {
        print('🧬 ❌ Данные растения NULL');
      }
      
      print('🧬 Итого найдено болезней и вредителей: ${diseases.length}');
      print('🧬 Список болезней и вредителей: ${diseases.join(", ")}');
      print('🧬 === КОНЕЦ ИЗВЛЕЧЕНИЯ БОЛЕЗНЕЙ И ВРЕДИТЕЛЕЙ ===');
      
      AppLogger.api('Извлечено болезней и вредителей из данных растения: ${diseases.join(", ")}');
    } catch (e) {
      print('🧬 ❌ Ошибка: $e');
      AppLogger.error('Ошибка извлечения названий болезней и вредителей', e);
    }
    
    return diseases.toSet().toList(); // Убираем дубликаты
  }
}
