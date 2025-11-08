import 'dart:convert';
import 'package:flutter/services.dart';

class RegionSuggestion {
  final String value; // Основное значение (например, "Москва")
  final String unrestrictedValue; // Полное значение (например, "г Москва")
  final bool isCity; // Флаг, указывающий, является ли это городом
  final String? details; // Дополнительная информация для отображения

  RegionSuggestion({
    required this.value,
    required this.unrestrictedValue,
    this.isCity = false,
    this.details,
  });

  @override
  String toString() => value;
}

class LocalRegionsService {
  // Кеш данных из JSON файла
  List<dynamic>? _regionsData;
  List<RegionSuggestion>? _regionsCache;

  // Флаг, что загрузка кеша уже инициирована
  bool _cacheLoadingStarted = false;

  // Метод для получения подсказок по введенному тексту
  Future<List<RegionSuggestion>> getSuggestions(String query) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      // Загружаем данные, если они еще не загружены
      if (!_cacheLoadingStarted) {
        _cacheLoadingStarted = true;
        await _loadRegionsData();
      }

      // Ищем подходящие регионы и города по запросу пользователя
      return _searchRegionsAndCities(query);
    } catch (e) {
      print('Исключение при получении подсказок: $e');
      return [];
    }
  }

  // Загрузка данных из JSON файла
  Future<void> _loadRegionsData() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/data/russia-regions.json');
      _regionsData = jsonDecode(jsonString);
      _prepareRegionsCache();
    } catch (e) {
      print('Ошибка при загрузке данных регионов: $e');
      _regionsData = [];
      _regionsCache = [];
    }
  }

  // Подготовка кеша регионов и городов
  void _prepareRegionsCache() {
    if (_regionsData == null || _regionsData!.isEmpty) {
      _regionsCache = [];
      return;
    }

    final List<RegionSuggestion> suggestions = [];

    for (final region in _regionsData!) {
      // Добавляем регион
      final String regionName = region['fullname'] ?? region['name'];
      final String regionType = region['typeShort'] ?? '';

      suggestions.add(
        RegionSuggestion(
          value: regionName,
          unrestrictedValue: regionName,
          isCity: false,
          details: null, // Для регионов не добавляем детали
        ),
      );

      // Добавляем столицу региона, если она есть
      if (region['capital'] != null) {
        final capital = region['capital'];
        final String cityName = capital['name'] ?? '';
        if (cityName.isNotEmpty) {
          suggestions.add(
            RegionSuggestion(
              value: cityName,
              unrestrictedValue: '$cityName, $regionName',
              isCity: true,
              details:
                  regionName, // Добавляем регион как дополнительную информацию
            ),
          );
        }
      }
    }

    _regionsCache = suggestions;
  }

  // Поиск регионов и городов по запросу
  List<RegionSuggestion> _searchRegionsAndCities(String query) {
    if (_regionsCache == null || _regionsCache!.isEmpty) {
      return [];
    }

    final lowercaseQuery = query.toLowerCase();

    // Транслитерация для поиска (простая реализация)
    final latinToRussian = {
      'a': 'а',
      'b': 'б',
      'v': 'в',
      'g': 'г',
      'd': 'д',
      'e': 'е',
      'yo': 'ё',
      'zh': 'ж',
      'z': 'з',
      'i': 'и',
      'j': 'й',
      'k': 'к',
      'l': 'л',
      'm': 'м',
      'n': 'н',
      'o': 'о',
      'p': 'п',
      'r': 'р',
      's': 'с',
      't': 'т',
      'u': 'у',
      'f': 'ф',
      'h': 'х',
      'ts': 'ц',
      'ch': 'ч',
      'sh': 'ш',
      'sch': 'щ',
      'y': 'ы',
      'e': 'э',
      'yu': 'ю',
      'ya': 'я'
    };

    // Проверяем, возможно ли, что запрос на латинице
    final isLatin = lowercaseQuery.contains(RegExp(r'[a-z]'));
    String russianQuery = lowercaseQuery;

    // Если запрос на латинице, пробуем транслитерацию
    if (isLatin) {
      latinToRussian.forEach((latin, russian) {
        russianQuery = russianQuery.replaceAll(latin, russian);
      });
    }

    // Поиск по кешу
    final matchingSuggestions = _regionsCache!.where((suggestion) {
      final lowerValue = suggestion.value.toLowerCase();

      // Проверяем, начинается ли название региона или города с запроса
      bool matchesQuery = lowerValue.startsWith(russianQuery);

      // Если город не соответствует запросу напрямую, проверяем детали
      if (!matchesQuery && isLatin) {
        // Проверяем латинское написание
        matchesQuery =
            _transliterateToLatin(lowerValue).startsWith(lowercaseQuery);
      }

      return matchesQuery;
    }).toList();

    // Ограничиваем количество результатов и сортируем
    final limitedResults = matchingSuggestions.take(15).toList()
      ..sort((a, b) {
        // Города выше регионов
        if (a.isCity && !b.isCity) return -1;
        if (!a.isCity && b.isCity) return 1;
        // Короткие названия выше длинных
        return a.value.length - b.value.length;
      });

    return limitedResults;
  }

  // Транслитерация с русского на латиницу
  String _transliterateToLatin(String text) {
    final Map<String, String> russianToLatin = {
      'а': 'a',
      'б': 'b',
      'в': 'v',
      'г': 'g',
      'д': 'd',
      'е': 'e',
      'ё': 'yo',
      'ж': 'zh',
      'з': 'z',
      'и': 'i',
      'й': 'j',
      'к': 'k',
      'л': 'l',
      'м': 'm',
      'н': 'n',
      'о': 'o',
      'п': 'p',
      'р': 'r',
      'с': 's',
      'т': 't',
      'у': 'u',
      'ф': 'f',
      'х': 'h',
      'ц': 'ts',
      'ч': 'ch',
      'ш': 'sh',
      'щ': 'sch',
      'ъ': '',
      'ы': 'y',
      'ь': '',
      'э': 'e',
      'ю': 'yu',
      'я': 'ya'
    };

    String result = '';
    for (int i = 0; i < text.length; i++) {
      final char = text[i].toLowerCase();
      result += russianToLatin[char] ?? char;
    }

    return result;
  }
}
