// Класс для хранения данных о растении и вредителях
class PlantCalculationData {
  final int stage;
  final String plantNameRu;
  final int dangerCount;
  final List<String> dangerNameList;

  PlantCalculationData({
    required this.stage,
    required this.plantNameRu,
    required this.dangerCount,
    required this.dangerNameList,
  });
} 