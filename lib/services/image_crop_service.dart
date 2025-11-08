import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageCropService {
  // Remove const frameSize

  /// Создает кроп изображения согласно рамке фокусировки камеры
  /// 
  /// [originalImagePath] - путь к оригинальному изображению
  /// [screenSize] - размер экрана для расчета координат
  /// [frameWidth] - ширина рамки
  /// [frameHeight] - высота рамки
  /// 
  /// Возвращает путь к созданному кропу
  static Future<String> createCropFromFrame({
    required String originalImagePath,
    required Size screenSize,
    required double frameWidth,
    required double frameHeight,
  }) async {
    try {
      print('🖼️ ==== НАЧАЛО СОЗДАНИЯ КРОПА ====');
      print('📱 Размер экрана: ${screenSize.width}x${screenSize.height}');
      print('📷 Исходное изображение: $originalImagePath');
      
      // Загружаем оригинальное изображение
      final File originalFile = File(originalImagePath);
      if (!await originalFile.exists()) {
        throw Exception('Файл изображения не найден: $originalImagePath');
      }
      
      final Uint8List imageBytes = await originalFile.readAsBytes();
      final img.Image? originalImage = img.decodeImage(imageBytes);
      
      if (originalImage == null) {
        throw Exception('Не удалось декодировать изображение');
      }
      
      print('🖼️ Размер оригинального изображения: ${originalImage.width}x${originalImage.height}');
      
      // Рассчитываем позицию рамки на экране
      final double centerX = screenSize.width / 2;
      final double centerY = screenSize.height / 2;
      final double frameLeft = centerX - frameWidth / 2;
      final double frameTop = centerY - frameHeight / 2;
      
      print('📐 Центр экрана: ($centerX, $centerY)');
      print('🎯 Рамка на экране: left=$frameLeft, top=$frameTop, width=$frameWidth, height=$frameHeight');
      
      // Рассчитываем масштаб изображения относительно экрана
      // Камера может иметь разное aspect ratio, поэтому нужно учесть это
      final double imageAspectRatio = originalImage.width / originalImage.height;
      final double screenAspectRatio = screenSize.width / screenSize.height;
      
      double scaleX, scaleY;
      double imageDisplayWidth, imageDisplayHeight;
      double offsetX = 0, offsetY = 0;
      
      if (imageAspectRatio > screenAspectRatio) {
        // Изображение шире экрана - масштабируем по высоте
        scaleY = originalImage.height / screenSize.height;
        scaleX = scaleY;
        imageDisplayWidth = originalImage.width / scaleX;
        imageDisplayHeight = screenSize.height;
        offsetX = (screenSize.width - imageDisplayWidth) / 2;
      } else {
        // Изображение выше экрана - масштабируем по ширине
        scaleX = originalImage.width / screenSize.width;
        scaleY = scaleX;
        imageDisplayWidth = screenSize.width;
        imageDisplayHeight = originalImage.height / scaleY;
        offsetY = (screenSize.height - imageDisplayHeight) / 2;
      }
      
      print('📏 Масштаб: scaleX=$scaleX, scaleY=$scaleY');
      print('📺 Отображаемый размер: ${imageDisplayWidth}x$imageDisplayHeight');
      print('📍 Смещение: offsetX=$offsetX, offsetY=$offsetY');
      
      // Конвертируем координаты рамки в координаты изображения
      final double cropLeft = (frameLeft - offsetX) * scaleX;
      final double cropTop = (frameTop - offsetY) * scaleY;
      final double cropWidth = frameWidth * scaleX;
      final double cropHeight = frameHeight * scaleY;
      
      print('✂️ Кроп в координатах изображения: left=$cropLeft, top=$cropTop, width=$cropWidth, height=$cropHeight');
      
      // Проверяем границы и корректируем если нужно
      final int finalCropLeft = (cropLeft).clamp(0, originalImage.width - 1).round();
      final int finalCropTop = (cropTop).clamp(0, originalImage.height - 1).round();
      final int finalCropWidth = (cropWidth).clamp(1, originalImage.width - finalCropLeft).round();
      final int finalCropHeight = (cropHeight).clamp(1, originalImage.height - finalCropTop).round();
      
      print('✅ Финальные координаты кропа: left=$finalCropLeft, top=$finalCropTop, width=$finalCropWidth, height=$finalCropHeight');
      
      // Создаем кроп
      final img.Image croppedImage = img.copyCrop(
        originalImage,
        x: finalCropLeft,
        y: finalCropTop,
        width: finalCropWidth,
        height: finalCropHeight,
      );
      
      print('🎯 Размер кропа: ${croppedImage.width}x${croppedImage.height}');
      
      // Сохраняем кроп во временной директории
      final Directory tempDir = await getTemporaryDirectory();
      final String cropFileName = 'crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String cropPath = path.join(tempDir.path, cropFileName);
      
      final File cropFile = File(cropPath);
      await cropFile.writeAsBytes(img.encodeJpg(croppedImage, quality: 90));
      
      print('💾 Кроп сохранен: $cropPath');
      print('🖼️ ==== КРОП СОЗДАН УСПЕШНО ====');
      
      return cropPath;
      
    } catch (e) {
      print('❌ Ошибка при создании кропа: $e');
      rethrow;
    }
  }
  
  /// Создает уменьшенную версию изображения для аватарки
  /// 
  /// [imagePath] - путь к изображению
  /// [size] - размер итоговой аватарки (квадрат)
  static Future<String> createThumbnail({
    required String imagePath,
    int size = 150,
  }) async {
    try {
      print('🔄 Создание миниатюры размером ${size}x$size из: $imagePath');
      
      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Файл изображения не найден: $imagePath');
      }
      
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? originalImage = img.decodeImage(imageBytes);
      
      if (originalImage == null) {
        throw Exception('Не удалось декодировать изображение');
      }
      
      // Изменяем размер с сохранением пропорций
      final img.Image resizedImage = img.copyResize(
        originalImage,
        width: size,
        height: size,
        interpolation: img.Interpolation.cubic,
      );
      
      // Сохраняем миниатюру
      final Directory tempDir = await getTemporaryDirectory();
      final String thumbnailFileName = 'thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String thumbnailPath = path.join(tempDir.path, thumbnailFileName);
      
      final File thumbnailFile = File(thumbnailPath);
      await thumbnailFile.writeAsBytes(img.encodeJpg(resizedImage, quality: 85));
      
      print('✅ Миниатюра создана: $thumbnailPath');
      return thumbnailPath;
      
    } catch (e) {
      print('❌ Ошибка при создании миниатюры: $e');
      rethrow;
    }
  }
}