import 'package:flutter/material.dart';
import 'home_styles.dart';
import '../services/api/scan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/plant_detail_page.dart';
import '../widgets/treatment_recommendations_widget.dart';
import '../services/api/treatment_service.dart';

class DiseaseAlertComponent extends StatefulWidget {
  const DiseaseAlertComponent({Key? key}) : super(key: key);

  @override
  State<DiseaseAlertComponent> createState() => _DiseaseAlertComponentState();
}

class _DiseaseAlertComponentState extends State<DiseaseAlertComponent> {
  List<dynamic> _sickPlants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSickPlants();
  }

  Future<void> _loadSickPlants() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final plantService = ScanService();
      final plants = await plantService.getUserPlantCollection(token);
      
      // Фильтруем только больные растения
      final sickPlants = plants.where((plant) => 
        plant['is_healthy'] == false
      ).toList();

      setState(() {
        _sickPlants = sickPlants;
        _isLoading = false;
      });

      print('🏠 Загружены больные растения: ${_sickPlants.length}');
    } catch (e) {
      print('❌ Ошибка загрузки больных растений: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showTreatmentDialog(dynamic plant) {
    final rootContext = context; // сохраняем внешний контекст для навигации после закрытия диалога
    final plantName = plant['name']?.toString() ?? 'Растение';
    final pestsAndDiseases = plant['pests_and_diseases'] as Map? ?? {};
    final careInfo = plant['care_info'] as Map? ?? {};
    
    // Извлекаем информацию о болезнях и лечении
    final commonDiseases = pestsAndDiseases['common_diseases'] as List? ?? [];
    final pestControl = careInfo['pest_control'] as Map? ?? {};
    final diseaseControl = careInfo['disease_treatment'] as Map? ?? {};
    
    final screenWidth = MediaQuery.of(context).size.width;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: screenWidth * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Заголовок
              Container(
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: HomeStyles.redAlert,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Лечение: $plantName',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: screenWidth * 0.045,
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: screenWidth * 0.06,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Содержимое
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Обнаруженные болезни
                      if (commonDiseases.isNotEmpty) ...[
                        Text(
                          '🦠 Обнаруженные болезни:',
                          style: TextStyle(
                            color: HomeStyles.redAlert,
                            fontSize: screenWidth * 0.04,
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: screenWidth * 0.02),
                        ...commonDiseases.map((disease) => _buildDiseaseCard(disease, screenWidth)),
                        SizedBox(height: screenWidth * 0.04),
                      ],
                      
                      // Рекомендации по лечению от вредителей
                      if (pestControl.isNotEmpty) ...[
                        _buildTreatmentCard(
                          'Обработка от вредителей', 
                          pestControl, 
                          screenWidth,
                          Icons.bug_report,
                          Colors.orange,
                        ),
                        SizedBox(height: screenWidth * 0.03),
                      ],
                      
                      // Рекомендации по лечению болезней
                      if (diseaseControl.isNotEmpty) ...[
                        _buildTreatmentCard(
                          'Лечение болезней', 
                          diseaseControl, 
                          screenWidth,
                          Icons.local_hospital,
                          Colors.red,
                        ),
                        SizedBox(height: screenWidth * 0.03),
                      ],
                      
                      // Рекомендации препаратов ИИ
                      _buildAITreatmentRecommendations(plant, screenWidth),
                      
                      // Если нет детальной информации
                      if (commonDiseases.isEmpty && pestControl.isEmpty && diseaseControl.isEmpty) ...[
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.warning_amber,
                                size: 48,
                                color: Colors.orange,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Растение требует внимания',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade800,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Детальная информация о болезнях и лечении отсутствует. Рекомендуется обратиться к специалисту.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Кнопка перехода к подробной информации о растении
              Padding(
                padding: EdgeInsets.fromLTRB(screenWidth * 0.04, 8, screenWidth * 0.04, screenWidth * 0.04),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      // Закрываем диалог
                      Navigator.of(rootContext).pop();
                      // Переходим на экран растения
                      Navigator.of(rootContext).push(
                        MaterialPageRoute(
                          builder: (_) => PlantDetailPage(plant: plant as Map<String, dynamic>),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF19C85F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Подробнее о растении'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDiseaseCard(Map disease, double screenWidth) {
    final name = disease['name']?.toString() ?? 'Неизвестная болезнь';
    final description = disease['description']?.toString() ?? '';
    final treatment = disease['treatment']?.toString() ?? '';
    final prevention = disease['prevention']?.toString() ?? '';
    
    return Container(
      margin: EdgeInsets.only(bottom: screenWidth * 0.03),
      padding: EdgeInsets.all(screenWidth * 0.03),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🦠 $name',
            style: TextStyle(
              color: Colors.red.shade800,
              fontSize: screenWidth * 0.035,
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w600,
            ),
          ),
          if (description.isNotEmpty && description != 'data_not_available') ...[
            SizedBox(height: screenWidth * 0.02),
            Text(
              description,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: screenWidth * 0.03,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w400,
                height: 1.3,
              ),
            ),
          ],
          if (treatment.isNotEmpty && treatment != 'data_not_available') ...[
            SizedBox(height: screenWidth * 0.02),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '💊 Лечение: $treatment',
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontSize: screenWidth * 0.03,
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          if (prevention.isNotEmpty && prevention != 'data_not_available') ...[
            SizedBox(height: screenWidth * 0.02),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '🛡️ Профилактика: $prevention',
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontSize: screenWidth * 0.03,
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildTreatmentCard(String title, Map treatment, double screenWidth, IconData icon, Color color) {
    final description = treatment['description']?.toString() ?? '';
    final automation = treatment['automation'] as Map? ?? {};
    final prevention = treatment['prevention'] as Map? ?? {};
    
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.03),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: screenWidth * 0.04,
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          if (description.isNotEmpty) ...[
            SizedBox(height: screenWidth * 0.02),
            Text(
              description,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: screenWidth * 0.03,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w400,
                height: 1.3,
              ),
            ),
          ],
          
          if (automation.isNotEmpty) ...[
            SizedBox(height: screenWidth * 0.02),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📋 Рекомендации:',
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: screenWidth * 0.03,
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  ...automation.entries.map((entry) {
                    if (entry.value == null || entry.value.toString().isEmpty) return SizedBox.shrink();
                    return Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        '• ${_formatAutomationKey(entry.key)}: ${_translateAutomationValue(entry.key, entry.value)}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: screenWidth * 0.025,
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  String _formatAutomationKey(String key) {
    switch (key) {
      case 'interval_days': return 'Интервал (дни)';
      case 'interval_months': return 'Интервал (месяцы)';
      case 'time_of_day': return 'Время дня';
      case 'method': return 'Метод';
      case 'preparation_type': return 'Препарат';
      case 'concentration': return 'Концентрация';
      case 'safety_level': return 'Уровень безопасности';
      case 'treatment_duration': return 'Длительность лечения (дни)';
      default: return key;
    }
  }

  String _translateAutomationValue(String key, dynamic value) {
    // Перевод отдельных enum-значений, приходящих из API
    const Map<String, String> translations = {
      // Время суток
      'morning': 'утро',
      'afternoon': 'день',
      'evening': 'вечер',
      'night': 'ночь',
      // Методы обработки
      'spray': 'опрыскивание',
      'watering': 'полив',
      'soaking': 'замачивание',
      'dusting': 'опудривание',
      // Уровень безопасности
      'low': 'низкий',
      'medium': 'средний',
      'high': 'высокий',
    };

    if (value == null) return '—';
    final String strVal = value.toString();
    final lower = strVal.toLowerCase();
    return translations[lower] ?? strVal;
  }

  @override
  Widget build(BuildContext context) {
    // Не показываем компонент если нет больных растений или идет загрузка
    if (_isLoading || _sickPlants.isEmpty) {
      return SizedBox.shrink();
    }

    // Показываем первое больное растение (можно расширить для показа всех)
    final firstSickPlant = _sickPlants.first;
    final plantName = firstSickPlant['name']?.toString() ?? 'Растение';
    
    // Определяем тип болезни для отображения
    String diseaseText = 'болезнь';
    final pestsAndDiseases = firstSickPlant['pests_and_diseases'] as Map? ?? {};
    final commonDiseases = pestsAndDiseases['common_diseases'] as List? ?? [];
    
    if (commonDiseases.isNotEmpty) {
      final firstDisease = commonDiseases.first;
      if (firstDisease is Map && firstDisease['name'] != null) {
        diseaseText = firstDisease['name'].toString().toLowerCase();
      }
    }

    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, top: 40, bottom: 15),
      height: 48,
      child: GestureDetector(
        onTap: () => _showTreatmentDialog(firstSickPlant),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: Color(0x1931873F),
                blurRadius: 15,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                // Иконка жука
                Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: HomeStyles.redAlert,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(6.0),
                  child: Image.asset(
                    'assets/images/home/szhuk.png',
                    width: 16,
                    height: 16,
                    fit: BoxFit.contain,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(width: 10),

                // Текст
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                      children: [
                        TextSpan(text: 'На вашем растении '),
                        TextSpan(
                          text: plantName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(text: ' обнаружена $diseaseText'),
                        if (_sickPlants.length > 1) ...[
                          TextSpan(text: ' и ещё ${_sickPlants.length - 1}'),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Кнопка "Лечить"
                Container(
                  height: 30,
                  width: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFF0074A6),
                        Color(0xFF19C85F),
                      ],
                    ),
                  ),
                  child: TextButton(
                    onPressed: () => _showTreatmentDialog(firstSickPlant),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: Text(
                      'Лечить',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
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

  /// Построение виджета с рекомендациями препаратов ИИ
  Widget _buildAITreatmentRecommendations(dynamic plant, double screenWidth) {
    // Проверяем здоровье растения - показываем рекомендации только для больных растений
    bool isHealthy = true;
    if (plant is Map) {
      isHealthy = plant['is_healthy'] ?? true;
    } else {
      try {
        isHealthy = plant.isHealthy ?? true;
      } catch (e) {
        isHealthy = true; // По умолчанию считаем здоровым
      }
    }
    
    if (isHealthy) {
      return SizedBox.shrink(); // Не показываем блок для здоровых растений
    }
    
    final treatmentService = TreatmentService();
    final diseases = treatmentService.extractDiseaseNames(plant);
    
    // Показываем блок только для больных растений
    return Column(
      children: [
        SizedBox(height: screenWidth * 0.03),
        TreatmentRecommendationsWidget(
          diseases: diseases,
          maxRecommendations: 4, // Увеличиваем до 4 рекомендаций как везде
          customTitle: '💊 Препараты для лечения',
          padding: EdgeInsets.zero, // Убираем лишний отступ
        ),
      ],
    );
  }
}
