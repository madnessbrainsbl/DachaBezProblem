import 'dart:io';
import '../config/api_config.dart';

enum MessageAuthor { user, ai, operator, system }

enum MessageStatus { sending, sent, delivered, error }

enum ChatStatus { active, waitingOperator, withOperator, closed }

class ChatImage {
  final String? path;
  final String? url;
  final String? originalName;
  final int? size;
  final String? mimeType;

  ChatImage({
    this.path,
    this.url,
    this.originalName,
    this.size,
    this.mimeType,
  });

  factory ChatImage.fromJson(Map<String, dynamic> json) {
    return ChatImage(
      path: json['path'],
      url: json['url'],
      originalName: json['originalName'],
      size: json['size'],
      mimeType: json['mimeType'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'url': url,
      'originalName': originalName,
      'size': size,
      'mimeType': mimeType,
    };
  }
}

class PlantAnalysis {
  final String? name;
  final String? latinName;
  final String? description;
  final bool? isHealthy;
  final List<String>? tags;
  final String? difficultyLevel;
  final Map<String, dynamic>? careInfo;
  final Map<String, dynamic>? growingConditions;
  final Map<String, dynamic>? pestsAndDiseases;
  final Map<String, dynamic>? images;

  PlantAnalysis({
    this.name,
    this.latinName,
    this.description,
    this.isHealthy,
    this.tags,
    this.difficultyLevel,
    this.careInfo,
    this.growingConditions,
    this.pestsAndDiseases,
    this.images,
  });

  factory PlantAnalysis.fromJson(Map<String, dynamic> json) {
    final plantInfo = json['plant_info'] ?? json;
    
    return PlantAnalysis(
      name: plantInfo['name'],
      latinName: plantInfo['latin_name'],
      description: plantInfo['description'],
      isHealthy: plantInfo['is_healthy'],
      tags: plantInfo['tags'] != null ? List<String>.from(plantInfo['tags']) : null,
      difficultyLevel: plantInfo['difficulty_level'],
      careInfo: plantInfo['care_info'],
      growingConditions: plantInfo['growing_conditions'],
      pestsAndDiseases: plantInfo['pests_and_diseases'],
      images: plantInfo['images'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plant_info': {
        'name': name,
        'latin_name': latinName,
        'description': description,
        'is_healthy': isHealthy,
        'tags': tags,
        'difficulty_level': difficultyLevel,
        'care_info': careInfo,
        'growing_conditions': growingConditions,
        'pests_and_diseases': pestsAndDiseases,
        'images': images,
      }
    };
  }
}

class MessageMetadata {
  final int? responseTime;
  final bool? isSystemMessage;
  final String? replyTo;
  final String? operatorName;
  final String? operatorId;

  MessageMetadata({
    this.responseTime,
    this.isSystemMessage,
    this.replyTo,
    this.operatorName,
    this.operatorId,
  });

  factory MessageMetadata.fromJson(Map<String, dynamic> json) {
    return MessageMetadata(
      responseTime: json['responseTime'],
      isSystemMessage: json['isSystemMessage'],
      replyTo: json['replyTo'],
      operatorName: json['operatorName'],
      operatorId: json['operatorId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'responseTime': responseTime,
      'isSystemMessage': isSystemMessage,
      'replyTo': replyTo,
      'operatorName': operatorName,
      'operatorId': operatorId,
    };
  }
}

class ChatMessage {
  final String? id;
  final String? userId;
  final MessageAuthor author;
  final String text;
  final DateTime date;
  final ChatImage? image;
  final PlantAnalysis? aiAnalysis;
  final MessageMetadata? metadata;
  final MessageStatus status;
  final String? sessionId;

  // Локальные поля для UI
  final File? localImageFile;
  final String? tempId;

  ChatMessage({
    this.id,
    this.userId,
    required this.author,
    required this.text,
    required this.date,
    this.image,
    this.aiAnalysis,
    this.metadata,
    this.status = MessageStatus.sent,
    this.sessionId,
    this.localImageFile,
    this.tempId,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    MessageAuthor author;
    switch (json['author']?.toString().toLowerCase()) {
      case 'ai':
        author = MessageAuthor.ai;
        break;
      case 'operator':
        author = MessageAuthor.operator;
        break;
      case 'system':
        author = MessageAuthor.system;
        break;
      default:
        author = MessageAuthor.user;
    }

    // Правильно извлекаем userId из объекта user или строки
    String? userId;
    final userField = json['user'];
    if (userField is Map<String, dynamic>) {
      // Если user - объект, извлекаем _id
      userId = userField['_id'];
    } else if (userField is String) {
      // Если user - строка, используем как есть
      userId = userField;
    }

    return ChatMessage(
      id: json['_id'] ?? json['id'],
      userId: userId,
      author: author,
      text: json['text'] ?? '',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      image: json['image'] != null ? ChatImage.fromJson(json['image']) : null,
      aiAnalysis: json['aiAnalysis'] != null ? PlantAnalysis.fromJson(json['aiAnalysis']) : null,
      metadata: json['metadata'] != null ? MessageMetadata.fromJson(json['metadata']) : null,
      status: MessageStatus.sent,
      sessionId: json['sessionId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'user': userId,
      'author': author.name,
      'text': text,
      'date': date.toIso8601String(),
      'image': image?.toJson(),
      'aiAnalysis': aiAnalysis?.toJson(),
      'metadata': metadata?.toJson(),
      'sessionId': sessionId,
    };
  }

  // Создание локального сообщения пользователя
  factory ChatMessage.createUserMessage({
    required String text,
    File? imageFile,
    String? tempId,
  }) {
    return ChatMessage(
      tempId: tempId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      author: MessageAuthor.user,
      text: text,
      date: DateTime.now(),
      localImageFile: imageFile,
      status: MessageStatus.sending,
    );
  }

  // Создание системного сообщения
  factory ChatMessage.createSystemMessage({
    required String text,
    String? sessionId,
  }) {
    return ChatMessage(
      author: MessageAuthor.system,
      text: text,
      date: DateTime.now(),
      status: MessageStatus.sent,
      sessionId: sessionId,
      metadata: MessageMetadata(isSystemMessage: true),
    );
  }

  // Копирование с изменениями
  ChatMessage copyWith({
    String? id,
    String? userId,
    MessageAuthor? author,
    String? text,
    DateTime? date,
    ChatImage? image,
    PlantAnalysis? aiAnalysis,
    MessageMetadata? metadata,
    MessageStatus? status,
    String? sessionId,
    File? localImageFile,
    String? tempId,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      author: author ?? this.author,
      text: text ?? this.text,
      date: date ?? this.date,
      image: image ?? this.image,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      metadata: metadata ?? this.metadata,
      status: status ?? this.status,
      sessionId: sessionId ?? this.sessionId,
      localImageFile: localImageFile ?? this.localImageFile,
      tempId: tempId ?? this.tempId,
    );
  }

  // Проверки
  bool get isFromUser => author == MessageAuthor.user;
  bool get isFromAI => author == MessageAuthor.ai;
  bool get isFromOperator => author == MessageAuthor.operator;
  bool get isSystemMessage => author == MessageAuthor.system || metadata?.isSystemMessage == true;
  bool get hasImage => image != null || localImageFile != null;
  bool get hasPlantAnalysis => aiAnalysis != null;
  bool get isSending => status == MessageStatus.sending;
  bool get hasError => status == MessageStatus.error;

  // Получение URL изображения
  String? get imageUrl {
    if (image?.url != null) {
      return image!.url!.startsWith('http') 
          ? image!.url 
          : 'http://89.110.92.227:3002${image!.url}';
    }
    return null;
  }

  // Получение локального пути изображения
  String? get localImagePath => localImageFile?.path;
}

class ChatSession {
  final String? id;
  final String? userId;
  final ChatStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? operatorId;
  final String? operatorName;
  final List<ChatMessage> messages;
  final Map<String, dynamic>? metadata;

  ChatSession({
    this.id,
    this.userId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.operatorId,
    this.operatorName,
    required this.messages,
    this.metadata,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    ChatStatus status;
    switch (json['status']?.toString().toLowerCase()) {
      case 'waiting_operator':
        status = ChatStatus.waitingOperator;
        break;
      case 'with_operator':
        status = ChatStatus.withOperator;
        break;
      case 'closed':
        status = ChatStatus.closed;
        break;
      default:
        status = ChatStatus.active;
    }

    final messagesList = json['messages'] as List? ?? [];
    final messages = messagesList
        .map((msg) => ChatMessage.fromJson(msg))
        .toList();

    return ChatSession(
      id: json['_id'] ?? json['id'],
      userId: json['userId'],
      status: status,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      operatorId: json['operatorId'],
      operatorName: json['operatorName'],
      messages: messages,
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'operatorId': operatorId,
      'operatorName': operatorName,
      'messages': messages.map((msg) => msg.toJson()).toList(),
      'metadata': metadata,
    };
  }

  // Копирование с изменениями
  ChatSession copyWith({
    String? id,
    String? userId,
    ChatStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? operatorId,
    String? operatorName,
    List<ChatMessage>? messages,
    Map<String, dynamic>? metadata,
  }) {
    return ChatSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      operatorId: operatorId ?? this.operatorId,
      operatorName: operatorName ?? this.operatorName,
      messages: messages ?? this.messages,
      metadata: metadata ?? this.metadata,
    );
  }

  // Проверки
  bool get isActive => status == ChatStatus.active;
  bool get isWaitingOperator => status == ChatStatus.waitingOperator;
  bool get isWithOperator => status == ChatStatus.withOperator;
  bool get isClosed => status == ChatStatus.closed;
  bool get hasOperator => operatorId != null && operatorName != null;

  // Получение статуса для отображения
  String get statusDisplayText {
    switch (status) {
      case ChatStatus.active:
        return 'Чат с ИИ';
      case ChatStatus.waitingOperator:
        return 'Ожидание оператора';
      case ChatStatus.withOperator:
        return hasOperator ? 'Чат с оператором $operatorName' : 'Чат с оператором';
      case ChatStatus.closed:
        return 'Чат завершён';
    }
  }
} 