import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api/treatment_service.dart';
import '../services/logger.dart';

/// Виджет для отображения рекомендаций препаратов
class TreatmentRecommendationsWidget extends StatefulWidget {
  final List<String> diseases;
  final int maxRecommendations;
  final EdgeInsets? padding;
  final bool showTitle;
  final String? customTitle;

  const TreatmentRecommendationsWidget({
    Key? key,
    required this.diseases,
    this.maxRecommendations = 3,
    this.padding,
    this.showTitle = true,
    this.customTitle,
  }) : super(key: key);

  @override
  State<TreatmentRecommendationsWidget> createState() =>
      _TreatmentRecommendationsWidgetState();
}

class _TreatmentRecommendationsWidgetState
    extends State<TreatmentRecommendationsWidget> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<TreatmentRecommendation> _recommendations = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print('🎯 === ИНИЦИАЛИЗАЦИЯ TreatmentRecommendationsWidget ===');
    print('🎯 Получены болезни: ${widget.diseases}');
    print('🎯 Количество болезней: ${widget.diseases.length}');
    print('🎯 Максимум рекомендаций: ${widget.maxRecommendations}');
    print('🎯 Показывать заголовок: ${widget.showTitle}');
    print('🎯 Вызываем _loadRecommendations()...');
    _loadRecommendations();
  }

  @override
  void didUpdateWidget(TreatmentRecommendationsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Перезагружаем рекомендации если изменился список болезней
    if (oldWidget.diseases != widget.diseases) {
      _loadRecommendations();
    }
  }

  Future<void> _loadRecommendations() async {
    print('🔄 === НАЧАЛО _loadRecommendations ===');
    print('🔄 Болезни для поиска: ${widget.diseases}');
    print('🔄 Количество болезней: ${widget.diseases.length}');
    
    if (widget.diseases.isEmpty) {
      print('🔄 Список болезней пуст - показываем fallback UI');
      setState(() {
        _recommendations = [];
        _isLoading = false;
        _errorMessage = null;
      });
      return; // Показываем fallback UI в build методе
    }

    print('🔄 Устанавливаем состояние загрузки...');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔄 Создаем TreatmentService...');
      final treatmentService = TreatmentService();
      print('🔄 Вызываем getRecommendations с болезнями: ${widget.diseases}');
      final recommendations = await treatmentService.getRecommendations(
        diseases: widget.diseases,
        limit: widget.maxRecommendations,
      );

      print('🔄 Получены рекомендации: ${recommendations.length} штук');
      for (int i = 0; i < recommendations.length; i++) {
        print('🔄 Рекомендация $i: ${recommendations[i].productName}');
      }

      if (mounted) {
        print('🔄 Обновляем состояние виджета...');
        setState(() {
          _recommendations = recommendations;
          _isLoading = false;
        });
        print('🔄 Состояние обновлено. Загрузка: $_isLoading, Рекомендаций: ${_recommendations.length}');
      } else {
        print('🔄 ПРЕДУПРЕЖДЕНИЕ: Виджет уже размонтирован, не обновляем состояние');
      }
    } catch (e) {
      print('🔄 ОШИБКА при загрузке рекомендаций: $e');
      AppLogger.error('Ошибка загрузки рекомендаций', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Не удалось загрузить рекомендации';
        });
        print('🔄 Установлено сообщение об ошибке: $_errorMessage');
      }
    }
    print('🔄 === КОНЕЦ _loadRecommendations ===');
  }

  Future<void> _launchUrl(String? urlString) async {
    if (urlString == null || urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ссылка на покупку недоступна')),
      );
      return;
    }

    try {
      final url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Не удалось открыть ссылку';
      }
    } catch (e) {
      AppLogger.error('Ошибка открытия ссылки', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: widget.padding ?? EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          if (widget.showTitle) ...[
            Row(
              children: [
                Icon(
                  Icons.local_pharmacy,
                  color: Colors.green,
                  size: 24,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.customTitle ?? 'Рекомендуемые препараты',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontFamily: 'Gilroy',
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
          ],

          // Загрузка
          if (_isLoading) ...[
            Container(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.green),
                    SizedBox(height: 8),
                    Text(
                      'Поиск препаратов...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]

          // Ошибка
          else if (_errorMessage != null) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.orange.shade800),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadRecommendations,
                    child: Text('Повторить'),
                  ),
                ],
              ),
            ),
          ]

          // Список рекомендаций (PageView)
          else if (_recommendations.isNotEmpty) ...[
            SizedBox(
              height: 360,
              child: PageView.builder(
                itemCount: _recommendations.length,
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildRecommendationCard(
                      _recommendations[index],
                      screenWidth,
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 12),
            if (_recommendations.length > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_recommendations.length, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index ? Colors.green : Colors.grey.shade300,
                    ),
                  );
                }),
              ),
          ]

          // Нет рекомендаций
          else ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Препараты для лечения',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    widget.diseases.isNotEmpty 
                        ? 'Для лечения обнаруженных болезней (${widget.diseases.join(", ")}) рекомендуем:'
                        : 'Для лечения обнаруженных болезней рекомендуем:',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Консультацию со специалистом\n• Фунгицидные препараты широкого спектра\n• Бордосская жидкость для профилактики',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Обратитесь в ближайший садовый центр за подходящими препаратами',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(
    TreatmentRecommendation recommendation,
    double screenWidth,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок препарата
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                // Изображение препарата
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: recommendation.productImage?.isNotEmpty == true
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            recommendation.productImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.local_pharmacy,
                                color: Colors.green,
                                size: 24,
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.local_pharmacy,
                          color: Colors.green,
                          size: 24,
                        ),
                ),
                SizedBox(width: 12),
                
                // Название препарата
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recommendation.productName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          fontFamily: 'Gilroy',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (recommendation.diseaseName.isNotEmpty) ...[
                        SizedBox(height: 2),
                        Text(
                          'От: ${recommendation.diseaseName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Детали препарата
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Описание болезни
                if (recommendation.diseaseDescription?.isNotEmpty == true) ...[
                  Text(
                    recommendation.diseaseDescription!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                ],

                // Дозировка
                if (recommendation.dosage?.isNotEmpty == true) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.science,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            recommendation.dosage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                ],

                // Кнопка покупки
                if (recommendation.purchaseLink?.isNotEmpty == true) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _launchUrl(recommendation.purchaseLink),
                      icon: Icon(Icons.shopping_cart, size: 18),
                      label: Text(
                        'Купить препарат',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Если нет ссылки на покупку
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Ссылка на покупку недоступна',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
