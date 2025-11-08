import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../logger.dart';
import '../../models/useful_info_model.dart';

class UsefulInfoService {
  static const String baseUrl = 'http://89.110.92.227:3002/api';
  
  /// Получить данные полезной информации
  Future<UsefulInfoModel> getUsefulInfo() async {
    try {
      AppLogger.api('Запрос полезной информации');
      
      // Получаем токен авторизации
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        throw Exception('Токен авторизации не найден');
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/useful-info'),
        headers: {
          'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 20));
      
      AppLogger.api('Ответ полезной информации: ${response.statusCode}');
      
      final jsonResponse = json.decode(response.body);
      
      if (response.statusCode == 200) {
        if (jsonResponse['success'] == true) {
          return UsefulInfoModel.fromJson(jsonResponse);
        } else {
          throw Exception(jsonResponse['message'] ?? 'Не удалось получить полезную информацию');
        }
      } else {
        throw Exception(jsonResponse['message'] ?? 'Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('Ошибка при получении полезной информации: $e');
      // Возвращаем пустую модель в случае ошибки
      return UsefulInfoModel(
        success: false, 
        message: e.toString(),
        data: UsefulInfoData(
          title: 'Полезная информация',
          mainItems: [],
          sideItems: [],
        ),
      );
    }
  }
} 