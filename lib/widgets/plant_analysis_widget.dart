import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class PlantAnalysisWidget extends StatelessWidget {
  final PlantAnalysis analysis;

  const PlantAnalysisWidget({
    Key? key,
    required this.analysis,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
        maxWidth: MediaQuery.of(context).size.width * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Заголовок
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF78B065), Color(0xFF388D79)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_florist,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    analysis.name ?? 'Анализ растения',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Gilroy',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Содержимое
          Flexible(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Основная информация
                    if (analysis.name != null) ...[
                      _buildInfoSection(
                        'Название растения',
                        analysis.name!,
                        icon: Icons.eco,
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (analysis.latinName != null) ...[
                      _buildInfoSection(
                        'Латинское название',
                        analysis.latinName!,
                        icon: Icons.science,
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (analysis.description != null) ...[
                      _buildInfoSection(
                        'Описание',
                        analysis.description!,
                        icon: Icons.description,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Статус здоровья
                    if (analysis.isHealthy != null) ...[
                      _buildHealthStatus(analysis.isHealthy!),
                      const SizedBox(height: 16),
                    ],

                    // Уровень сложности
                    if (analysis.difficultyLevel != null) ...[
                      _buildInfoSection(
                        'Сложность ухода',
                        _getDifficultyText(analysis.difficultyLevel!),
                        icon: Icons.trending_up,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Теги
                    if (analysis.tags != null && analysis.tags!.isNotEmpty) ...[
                      _buildTagsSection(analysis.tags!),
                      const SizedBox(height: 16),
                    ],

                    // Информация об уходе
                    if (analysis.careInfo != null) ...[
                      _buildCareInfoSection(analysis.careInfo!),
                      const SizedBox(height: 16),
                    ],

                    // Условия выращивания
                    if (analysis.growingConditions != null) ...[
                      _buildGrowingConditionsSection(analysis.growingConditions!),
                      const SizedBox(height: 16),
                    ],

                    // Вредители и болезни
                    if (analysis.pestsAndDiseases != null) ...[
                      _buildPestsAndDiseasesSection(analysis.pestsAndDiseases!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content, {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: const Color(0xFF63A36C),
                size: 20,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2024),
                fontFamily: 'Gilroy',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
            fontFamily: 'Gilroy',
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildHealthStatus(bool isHealthy) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHealthy ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHealthy ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isHealthy ? Icons.check_circle : Icons.warning,
            color: isHealthy ? Colors.green : Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isHealthy ? 'Растение здоровое' : 'Требует внимания',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isHealthy ? Colors.green.shade700 : Colors.orange.shade700,
                fontFamily: 'Gilroy',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection(List<String> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.label,
              color: Color(0xFF63A36C),
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Теги',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2024),
                fontFamily: 'Gilroy',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((tag) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF63A36C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF63A36C).withOpacity(0.3),
              ),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF63A36C),
                fontFamily: 'Gilroy',
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildCareInfoSection(Map<String, dynamic> careInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.spa,
              color: Color(0xFF63A36C),
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Уход за растением',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2024),
                fontFamily: 'Gilroy',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        if (careInfo['watering'] != null) ...[
          _buildCareItem(
            'Полив',
            careInfo['watering']['description'] ?? 'Информация о поливе',
            Icons.water_drop,
          ),
          const SizedBox(height: 8),
        ],
        
        if (careInfo['fertilizing'] != null) ...[
          _buildCareItem(
            'Удобрения',
            careInfo['fertilizing']['description'] ?? 'Информация об удобрениях',
            Icons.eco,
          ),
          const SizedBox(height: 8),
        ],
        
        if (careInfo['pruning'] != null) ...[
          _buildCareItem(
            'Обрезка',
            careInfo['pruning']['description'] ?? 'Информация об обрезке',
            Icons.content_cut,
          ),
        ],
      ],
    );
  }

  Widget _buildCareItem(String title, String description, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFF63A36C),
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2024),
                    fontFamily: 'Gilroy',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666666),
                    fontFamily: 'Gilroy',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowingConditionsSection(Map<String, dynamic> conditions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.wb_sunny,
              color: Color(0xFF63A36C),
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Условия выращивания',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2024),
                fontFamily: 'Gilroy',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        if (conditions['temperature'] != null) ...[
          _buildConditionItem(
            'Температура',
            _getTemperatureText(conditions['temperature']),
            Icons.thermostat,
          ),
          const SizedBox(height: 8),
        ],
        
        if (conditions['lighting'] != null) ...[
          _buildConditionItem(
            'Освещение',
            _getLightingText(conditions['lighting']),
            Icons.wb_sunny,
          ),
          const SizedBox(height: 8),
        ],
        
        if (conditions['humidity'] != null) ...[
          _buildConditionItem(
            'Влажность',
            '${conditions['humidity']}%',
            Icons.opacity,
          ),
        ],
      ],
    );
  }

  Widget _buildConditionItem(String title, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF63A36C),
          size: 18,
        ),
        const SizedBox(width: 12),
        Text(
          '$title: ',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2024),
            fontFamily: 'Gilroy',
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              fontFamily: 'Gilroy',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPestsAndDiseasesSection(Map<String, dynamic> pestsInfo) {
    final bool detected = pestsInfo['detected'] ?? false;
    final Map<String, dynamic>? commonProblems = pestsInfo['common_problems'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              detected ? Icons.bug_report : Icons.verified_user,
              color: detected ? Colors.orange : Colors.green,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Вредители и болезни',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2024),
                fontFamily: 'Gilroy',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: detected ? Colors.orange.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: detected ? Colors.orange : Colors.green,
              width: 1,
            ),
          ),
          child: Text(
            detected ? 'Обнаружены проблемы' : 'Проблем не обнаружено',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: detected ? Colors.orange.shade700 : Colors.green.shade700,
              fontFamily: 'Gilroy',
            ),
          ),
        ),
        
        if (commonProblems != null && commonProblems.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...commonProblems.entries.map((entry) {
            final problem = entry.value as Map<String, dynamic>;
            final causes = problem['causes'] as List<dynamic>? ?? [];
            final solutions = problem['solutions'] as List<dynamic>? ?? [];
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getProblemTitle(entry.key),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2024),
                      fontFamily: 'Gilroy',
                    ),
                  ),
                  if (causes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Причины: ${causes.join(', ')}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                        fontFamily: 'Gilroy',
                      ),
                    ),
                  ],
                  if (solutions.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Решения: ${solutions.join(', ')}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF63A36C),
                        fontFamily: 'Gilroy',
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ],
    );
  }

  String _getDifficultyText(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 'Легкий';
      case 'medium':
        return 'Средний';
      case 'hard':
        return 'Сложный';
      default:
        return difficulty;
    }
  }

  String _getTemperatureText(Map<String, dynamic> temp) {
    final min = temp['min'];
    final max = temp['max'];
    final optimalMin = temp['optimal_min'];
    final optimalMax = temp['optimal_max'];
    
    String result = '';
    if (min != null && max != null) {
      result += '$min-$max°C';
    }
    if (optimalMin != null && optimalMax != null) {
      result += ' (оптимально: $optimalMin-$optimalMax°C)';
    }
    return result.isNotEmpty ? result : 'Не указано';
  }

  String _getLightingText(Map<String, dynamic> lighting) {
    final type = lighting['type'];
    final hours = lighting['hours_per_day'];
    
    String typeText = '';
    switch (type?.toString().toLowerCase()) {
      case 'bright_direct':
        typeText = 'Яркое прямое освещение';
        break;
      case 'bright_indirect':
        typeText = 'Яркое рассеянное освещение';
        break;
      case 'medium':
        typeText = 'Умеренное освещение';
        break;
      case 'low':
        typeText = 'Слабое освещение';
        break;
      default:
        typeText = type?.toString() ?? 'Не указано';
    }
    
    if (hours != null) {
      typeText += ', $hours ч/день';
    }
    
    return typeText;
  }

  String _getProblemTitle(String key) {
    switch (key.toLowerCase()) {
      case 'yellow_leaves':
        return 'Желтые листья';
      case 'brown_spots':
        return 'Коричневые пятна';
      case 'wilting':
        return 'Увядание';
      case 'pest_infestation':
        return 'Вредители';
      default:
        return key.replaceAll('_', ' ');
    }
  }
} 