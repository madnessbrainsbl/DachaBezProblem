import 'dart:async';

// Типы событий
enum PlantEventType {
  collectionUpdated,
  reminderCompleted,
  reminderDeleted,
  reminderCreated,
  reminderUpdated,
}

// Данные события
class PlantEventData {
  final PlantEventType type;
  final String? plantId;
  final String? reminderId;
  final Map<String, dynamic>? additionalData;

  PlantEventData({
    required this.type,
    this.plantId,
    this.reminderId,
    this.additionalData,
  });
}

// Расширенный EventBus для уведомлений о растениях и напоминаниях
class PlantEvents {
  static final PlantEvents _instance = PlantEvents._internal();
  factory PlantEvents() => _instance;
  PlantEvents._internal();

  final StreamController<PlantEventData> _controller = StreamController<PlantEventData>.broadcast();

  // Поток для подписки на события
  Stream<PlantEventData> get stream => _controller.stream;

  // Уведомление об изменении коллекции
  void notifyUpdate() {
    print('🔄 PlantEvents: Уведомляем об обновлении коллекции');
    _controller.add(PlantEventData(type: PlantEventType.collectionUpdated));
  }

  // Уведомление о выполнении напоминания
  void notifyReminderCompleted(String reminderId, {String? plantId}) {
    print('✅ PlantEvents: Напоминание $reminderId выполнено');
    _controller.add(PlantEventData(
      type: PlantEventType.reminderCompleted,
      reminderId: reminderId,
      plantId: plantId,
    ));
  }

  // Уведомление об удалении напоминания
  void notifyReminderDeleted(String reminderId, {String? plantId}) {
    print('🗑️ PlantEvents: Напоминание $reminderId удалено');
    _controller.add(PlantEventData(
      type: PlantEventType.reminderDeleted,
      reminderId: reminderId,
      plantId: plantId,
    ));
  }

  // Уведомление о создании напоминания
  void notifyReminderCreated(String reminderId, {String? plantId}) {
    print('➕ PlantEvents: Напоминание $reminderId создано');
    _controller.add(PlantEventData(
      type: PlantEventType.reminderCreated,
      reminderId: reminderId,
      plantId: plantId,
    ));
  }

  // Уведомление об обновлении напоминания
  void notifyReminderUpdated(String reminderId, {String? plantId}) {
    print('📝 PlantEvents: Напоминание $reminderId обновлено');
    _controller.add(PlantEventData(
      type: PlantEventType.reminderUpdated,
      reminderId: reminderId,
      plantId: plantId,
    ));
  }

  void dispose() {
    _controller.close();
  }
} 