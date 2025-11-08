import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'plant_result_constants.dart';
import 'plant_result_utils.dart';
import '../models/plant_info.dart';
import 'set_reminder_screen.dart';

class PlantResultDialogs {
  // Метод для показа полного описания растения
  static void showFullDescriptionDialog(BuildContext context, String plantName, String description, bool isHealthy) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: screenWidth * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: plantResultWhite,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: plantResultShadowColor,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Заголовок
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: isHealthy ? plantResultGreenAccent : plantResultRedAccent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          plantName,
                          style: TextStyle(
                            color: plantResultWhite,
                            fontSize: screenWidth * 0.045,
                            fontFamily: plantResultFontFamily,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          Icons.close,
                          color: plantResultWhite,
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
                    child: Text(
                      description,
                      style: TextStyle(
                        color: plantResultDarkText,
                        fontSize: screenWidth * 0.035,
                        fontFamily: plantResultFontFamily,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Метод для показа калькулятора полива
  static void showWateringCalculatorDialog(BuildContext context, dynamic plantData, bool isHealthy) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: screenWidth * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: plantResultWhite,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: plantResultShadowColor,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Заголовок
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: isHealthy ? plantResultGreenAccent : plantResultRedAccent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Калькулятор полива',
                          style: TextStyle(
                            color: plantResultWhite,
                            fontSize: screenWidth * 0.045,
                            fontFamily: plantResultFontFamily,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          Icons.close,
                          color: plantResultWhite,
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
                        Text(
                          'Рекомендации по поливу:',
                          style: TextStyle(
                            color: plantResultDarkText,
                            fontSize: screenWidth * 0.04,
                            fontFamily: plantResultFontFamily,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: screenWidth * 0.03),
                        Text(
                          PlantResultUtils.getWateringRecommendations(plantData),
                          style: TextStyle(
                            color: plantResultDarkText,
                            fontSize: screenWidth * 0.035,
                            fontFamily: plantResultFontFamily,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: screenWidth * 0.04),
                        // Кнопка "Установить напоминание"
                        SizedBox(
                          width: double.infinity,
                          height: screenWidth * 0.12,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isHealthy ? plantResultGreenAccent : plantResultRedAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop(); // Закрываем диалог калькулятора
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SetReminderScreen(
                                    openFromWatering: true, // Это переход из калькулятора полива!
                                    fromScanHistory: true,  // Не после сканирования - возвращаемся назад
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              'Установить напоминание',
                              style: TextStyle(
                                color: plantResultWhite,
                                fontSize: screenWidth * 0.04,
                                fontFamily: plantResultFontFamily,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Метод для показа информации о вредителях и болезнях
  static void showPestsAndDiseasesDialog(BuildContext context, dynamic plantData, bool isHealthy) {
    print('🐛 === ПОКАЗ ИНФОРМАЦИИ О ВРЕДИТЕЛЯХ И БОЛЕЗНЯХ ===');
    
    List<Map<String, dynamic>> pests = [];
    List<Map<String, dynamic>> diseases = [];
    List<Map<String, dynamic>> detectedProblems = [];
    
    if (plantData != null && plantData is PlantInfo) {
      print('📊 pestsAndDiseases ключи: ${plantData.pestsAndDiseases.keys.join(", ")}');
      
      // Новая структура: common_pests с детальной информацией
      if (plantData.pestsAndDiseases.containsKey('common_pests') && 
          plantData.pestsAndDiseases['common_pests'] is List) {
        final pestsList = plantData.pestsAndDiseases['common_pests'] as List;
        for (var pest in pestsList) {
          if (pest is Map) {
            pests.add(Map<String, dynamic>.from(pest));
            print('🐛 Найден вредитель: ${pest['name']}');
          }
        }
      }
      
      // Новая структура: common_diseases с детальной информацией
      if (plantData.pestsAndDiseases.containsKey('common_diseases') && 
          plantData.pestsAndDiseases['common_diseases'] is List) {
        final diseasesList = plantData.pestsAndDiseases['common_diseases'] as List;
        for (var disease in diseasesList) {
          if (disease is Map) {
            diseases.add(Map<String, dynamic>.from(disease));
            print('🦠 Найдена болезнь: ${disease['name']}');
          }
        }
      }
      
      // Обнаруженные проблемы (detected = true)
      detectedProblems = plantData.getDetectedProblems();
      
      // Обратная совместимость: старая структура
      if (pests.isEmpty && plantData.pestsAndDiseases.containsKey('pests') && 
          plantData.pestsAndDiseases['pests'] is List) {
        final oldPests = plantData.pestsAndDiseases['pests'] as List;
        for (var pest in oldPests) {
          pests.add({
            'name': pest.toString(),
            'description': 'Информация отсутствует',
            'treatment': 'Обратитесь к специалисту',
            'prevention': 'Регулярный осмотр растения'
          });
        }
        print('🔄 Использована старая структура для вредителей');
      }
      
      if (diseases.isEmpty && plantData.pestsAndDiseases.containsKey('diseases') && 
          plantData.pestsAndDiseases['diseases'] is List) {
        final oldDiseases = plantData.pestsAndDiseases['diseases'] as List;
        for (var disease in oldDiseases) {
          diseases.add({
            'name': disease.toString(),
            'description': 'Информация отсутствует',
            'treatment': 'Обратитесь к специалисту',
            'prevention': 'Правильный уход'
          });
        }
        print('🔄 Использована старая структура для болезней');
      }
    }
    
    print('📊 Итого: ${pests.length} вредителей, ${diseases.length} болезней, ${detectedProblems.length} обнаруженных проблем');
    print('🐛 === КОНЕЦ АНАЛИЗА ВРЕДИТЕЛЕЙ И БОЛЕЗНЕЙ ===\n');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: screenWidth * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: plantResultWhite,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: plantResultShadowColor,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Заголовок
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: isHealthy ? plantResultGreenAccent : plantResultRedAccent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Вредители и болезни',
                          style: TextStyle(
                            color: plantResultWhite,
                            fontSize: screenWidth * 0.045,
                            fontFamily: plantResultFontFamily,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          Icons.close,
                          color: plantResultWhite,
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
                        // Обнаруженные проблемы (если есть)
                        if (detectedProblems.isNotEmpty) ...[
                          Text(
                            '🚨 Обнаруженные проблемы:',
                            style: TextStyle(
                              color: plantResultRedAccent,
                              fontSize: screenWidth * 0.04,
                              fontFamily: plantResultFontFamily,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: screenWidth * 0.02),
                          ...detectedProblems.map((problem) => _buildProblemCard(problem, screenWidth)),
                          SizedBox(height: screenWidth * 0.04),
                        ],
                        
                        // Блок вредителей
                        Text(
                          'Возможные вредители:',
                          style: TextStyle(
                            color: plantResultDarkText,
                            fontSize: screenWidth * 0.04,
                            fontFamily: plantResultFontFamily,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: screenWidth * 0.02),
                        if (pests.isEmpty)
                          Text(
                            'Вредители не обнаружены',
                            style: TextStyle(
                              color: plantResultGreenAccent,
                              fontSize: screenWidth * 0.035,
                              fontFamily: plantResultFontFamily,
                              fontWeight: FontWeight.w400,
                            ),
                          )
                        else
                          ...pests.map((pest) => _buildPestDiseaseCard(pest, screenWidth, true)),
                        
                        SizedBox(height: screenWidth * 0.04),
                        
                        // Блок болезней
                        Text(
                          'Возможные болезни:',
                          style: TextStyle(
                            color: plantResultDarkText,
                            fontSize: screenWidth * 0.04,
                            fontFamily: plantResultFontFamily,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: screenWidth * 0.02),
                        if (diseases.isEmpty)
                          Text(
                            'Болезни не обнаружены',
                            style: TextStyle(
                              color: plantResultGreenAccent,
                              fontSize: screenWidth * 0.035,
                              fontFamily: plantResultFontFamily,
                              fontWeight: FontWeight.w400,
                            ),
                          )
                        else
                          ...diseases.map((disease) => _buildPestDiseaseCard(disease, screenWidth, false)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Метод для построения карточки проблемы
  static Widget _buildProblemCard(Map<String, dynamic> problem, double screenWidth) {
    final type = problem['type'] ?? 'неизвестная проблема';
    final data = problem['data'] as Map<String, dynamic>? ?? {};
    final causes = data['causes'] as List? ?? [];
    final solutions = data['solutions'] as List? ?? [];
    
    return Container(
      margin: EdgeInsets.only(bottom: screenWidth * 0.02),
      padding: EdgeInsets.all(screenWidth * 0.03),
      decoration: BoxDecoration(
        color: plantResultRedAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: plantResultRedAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            PlantResultUtils.translateProblemType(type),
            style: TextStyle(
              color: plantResultRedAccent,
              fontSize: screenWidth * 0.035,
              fontFamily: plantResultFontFamily,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (causes.isNotEmpty) ...[
            SizedBox(height: screenWidth * 0.01),
            Text(
              'Причины: ${causes.join(", ")}',
              style: TextStyle(
                color: plantResultDarkText,
                fontSize: screenWidth * 0.03,
                fontFamily: plantResultFontFamily,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          if (solutions.isNotEmpty) ...[
            SizedBox(height: screenWidth * 0.01),
            Text(
              'Решения: ${solutions.join(", ")}',
              style: TextStyle(
                color: plantResultGreenAccent,
                fontSize: screenWidth * 0.03,
                fontFamily: plantResultFontFamily,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Метод для построения карточки вредителя/болезни
  static Widget _buildPestDiseaseCard(Map<String, dynamic> item, double screenWidth, bool isPest) {
    final name = item['name'] ?? 'Неизвестно';
    final description = item['description'] ?? '';
    final treatment = item['treatment'] ?? '';
    final prevention = item['prevention'] ?? '';
    
    return Container(
      margin: EdgeInsets.only(bottom: screenWidth * 0.03),
      padding: EdgeInsets.all(screenWidth * 0.03),
      decoration: BoxDecoration(
        color: plantResultWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${isPest ? "🐛" : "🦠"} $name',
            style: TextStyle(
              color: plantResultDarkText,
              fontSize: screenWidth * 0.035,
              fontFamily: plantResultFontFamily,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (description.isNotEmpty && description != 'data_not_available') ...[
            SizedBox(height: screenWidth * 0.01),
            Text(
              description,
              style: TextStyle(
                color: plantResultDarkText,
                fontSize: screenWidth * 0.03,
                fontFamily: plantResultFontFamily,
                fontWeight: FontWeight.w400,
                height: 1.3,
              ),
            ),
          ],
          if (treatment.isNotEmpty && treatment != 'data_not_available') ...[
            SizedBox(height: screenWidth * 0.01),
            Text(
              'Лечение: $treatment',
              style: TextStyle(
                color: plantResultRedAccent,
                fontSize: screenWidth * 0.03,
                fontFamily: plantResultFontFamily,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (prevention.isNotEmpty && prevention != 'data_not_available') ...[
            SizedBox(height: screenWidth * 0.01),
            Text(
              'Профилактика: $prevention',
              style: TextStyle(
                color: plantResultGreenAccent,
                fontSize: screenWidth * 0.03,
                fontFamily: plantResultFontFamily,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // НОВОЕ: Метод для показа подробной информации о здоровье растения
  static void showHealthDetailsDialog(BuildContext context, String title, String content, bool isHealthy) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: screenWidth * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: plantResultWhite,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: plantResultShadowColor,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Заголовок
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: isHealthy ? plantResultGreenAccent : plantResultRedAccent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: plantResultWhite,
                            fontSize: screenWidth * 0.045,
                            fontFamily: plantResultFontFamily,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          Icons.close,
                          color: plantResultWhite,
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
                    child: Text(
                      content,
                      style: TextStyle(
                        color: plantResultDarkText,
                        fontSize: screenWidth * 0.035,
                        fontFamily: plantResultFontFamily,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // НОВОЕ: Метод для показа подробной информации о поливе
  static void showWateringDetailsDialog(BuildContext context, String wateringInfo, bool isHealthy) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: screenWidth * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: plantResultWhite,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: plantResultShadowColor,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Заголовок
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: isHealthy ? plantResultGreenAccent : plantResultRedAccent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Подробно о поливе',
                          style: TextStyle(
                            color: plantResultWhite,
                            fontSize: screenWidth * 0.045,
                            fontFamily: plantResultFontFamily,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          Icons.close,
                          color: plantResultWhite,
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
                    child: Text(
                      wateringInfo,
                      style: TextStyle(
                        color: plantResultDarkText,
                        fontSize: screenWidth * 0.035,
                        fontFamily: plantResultFontFamily,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // НОВОЕ: Метод для показа подробной информации о температуре
  static void showTemperatureDetailsDialog(BuildContext context, String temperatureInfo, bool isHealthy) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: screenWidth * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: plantResultWhite,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: plantResultShadowColor,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Заголовок
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: isHealthy ? plantResultGreenAccent : plantResultRedAccent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Температурные условия',
                          style: TextStyle(
                            color: plantResultWhite,
                            fontSize: screenWidth * 0.045,
                            fontFamily: plantResultFontFamily,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          Icons.close,
                          color: plantResultWhite,
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
                    child: Text(
                      temperatureInfo,
                      style: TextStyle(
                        color: plantResultDarkText,
                        fontSize: screenWidth * 0.035,
                        fontFamily: plantResultFontFamily,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // НОВОЕ: Метод для показа подробной информации об освещении
  static void showLightingDetailsDialog(BuildContext context, String content, bool isHealthy) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: screenWidth * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: plantResultWhite,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: plantResultShadowColor,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Заголовок
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: isHealthy ? plantResultGreenAccent : plantResultRedAccent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Освещение',
                          style: TextStyle(
                            color: plantResultWhite,
                            fontSize: screenWidth * 0.045,
                            fontFamily: plantResultFontFamily,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          Icons.close,
                          color: plantResultWhite,
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
                    child: Text(
                      content,
                      style: TextStyle(
                        color: plantResultDarkText,
                        fontSize: screenWidth * 0.035,
                        fontFamily: plantResultFontFamily,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // НОВОЕ: Метод для показа подробной информации о влажности
  static void showHumidityDetailsDialog(BuildContext context, String content, bool isHealthy) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: screenWidth * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: plantResultWhite,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: plantResultShadowColor,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Заголовок
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: isHealthy ? plantResultGreenAccent : plantResultRedAccent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Влажность',
                          style: TextStyle(
                            color: plantResultWhite,
                            fontSize: screenWidth * 0.045,
                            fontFamily: plantResultFontFamily,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          Icons.close,
                          color: plantResultWhite,
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
                    child: Text(
                      content,
                      style: TextStyle(
                        color: plantResultDarkText,
                        fontSize: screenWidth * 0.035,
                        fontFamily: plantResultFontFamily,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // НОВОЕ: Метод для показа подробной информации об удобрениях
  static void showFertilizingDetailsDialog(BuildContext context, String content, bool isHealthy) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: screenWidth * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: plantResultWhite,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: plantResultShadowColor,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Заголовок
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: isHealthy ? plantResultGreenAccent : plantResultRedAccent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Удобрения',
                          style: TextStyle(
                            color: plantResultWhite,
                            fontSize: screenWidth * 0.045,
                            fontFamily: plantResultFontFamily,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          Icons.close,
                          color: plantResultWhite,
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
                    child: Text(
                      content,
                      style: TextStyle(
                        color: plantResultDarkText,
                        fontSize: screenWidth * 0.035,
                        fontFamily: plantResultFontFamily,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 