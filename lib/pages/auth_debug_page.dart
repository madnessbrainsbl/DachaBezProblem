import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_preferences_service.dart';
import '../services/api/api_client.dart';

/// Страница для диагностики состояния авторизации и токенов
/// Полезна для отладки проблем с авторизацией
class AuthDebugPage extends StatefulWidget {
  const AuthDebugPage({Key? key}) : super(key: key);

  @override
  State<AuthDebugPage> createState() => _AuthDebugPageState();
}

class _AuthDebugPageState extends State<AuthDebugPage> {
  Map<String, dynamic> _authState = {};
  Map<String, dynamic> _tokenInfo = {};
  Map<String, dynamic> _allPrefs = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDiagnosticData();
  }

  Future<void> _loadDiagnosticData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Получаем состояние авторизации
      final authState = await UserPreferencesService.getAuthState();
      
      // Получаем информацию о токене
      final tokenInfo = await ApiClient.getTokenInfo();
      
      // Получаем все SharedPreferences для анализа
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final allPrefs = <String, dynamic>{};
      
      for (String key in allKeys) {
        try {
          final value = prefs.get(key);
          if (key.contains('token')) {
            // Маскируем токены для безопасности
            allPrefs[key] = value is String && value.length > 10 
                ? '${value.substring(0, 10)}...***'
                : value;
          } else {
            allPrefs[key] = value;
          }
        } catch (e) {
          allPrefs[key] = 'Ошибка чтения: $e';
        }
      }

      setState(() {
        _authState = authState;
        _tokenInfo = tokenInfo;
        _allPrefs = allPrefs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _authState = {'error': e.toString()};
        _isLoading = false;
      });
    }
  }

  Future<void> _clearTokenOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('auth_token_timestamp');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Токен удален (состояние авторизации сохранено)')),
      );
      
      _loadDiagnosticData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _clearAllAuth() async {
    try {
      await UserPreferencesService.clearAuthState();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Все данные авторизации очищены')),
      );
      
      _loadDiagnosticData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Диагностика авторизации'),
        backgroundColor: Color(0xFF63A36C),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Состояние авторизации
                  _buildSection(
                    'Состояние авторизации',
                    _authState,
                    Colors.blue.shade50,
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Информация о токене
                  _buildSection(
                    'Информация о токене',
                    _tokenInfo,
                    Colors.green.shade50,
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Все SharedPreferences
                  _buildSection(
                    'Все SharedPreferences',
                    _allPrefs,
                    Colors.orange.shade50,
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Кнопки управления
                  _buildControlButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, Map<String, dynamic> data, Color backgroundColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: backgroundColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          if (data.isEmpty)
            Text('Данные отсутствуют', style: TextStyle(color: Colors.grey))
          else
            ...data.entries.map((entry) => Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${entry.key}:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${entry.value}',
                      style: TextStyle(
                        color: Colors.black54,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Управление',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        
        ElevatedButton(
          onPressed: _loadDiagnosticData,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: Text('🔄 Обновить данные'),
        ),
        
        SizedBox(height: 8),
        
        ElevatedButton(
          onPressed: _clearTokenOnly,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: Text('🗑️ Удалить только токен (тест проблемы)'),
        ),
        
        SizedBox(height: 8),
        
        ElevatedButton(
          onPressed: _clearAllAuth,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text('🧹 Очистить всю авторизацию'),
        ),
        
        SizedBox(height: 16),
        
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Примечание: Кнопка "Удалить только токен" симулирует проблему клиента - когда токен пропадает, но состояние isLoggedIn остается true.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
} 