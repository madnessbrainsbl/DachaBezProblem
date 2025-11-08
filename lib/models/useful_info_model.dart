class UsefulInfoModel {
  final bool success;
  final UsefulInfoData? data;
  final String? message;

  UsefulInfoModel({
    required this.success,
    this.data,
    this.message,
  });

  factory UsefulInfoModel.fromJson(Map<String, dynamic> json) {
    return UsefulInfoModel(
      success: json['success'] ?? false,
      data: json['data'] != null ? UsefulInfoData.fromJson(json['data']) : null,
      message: json['message'],
    );
  }
}

class UsefulInfoData {
  final String title;
  final List<MainInfoItem> mainItems;
  final List<SideInfoItem> sideItems;

  UsefulInfoData({
    required this.title,
    required this.mainItems,
    required this.sideItems,
  });

  factory UsefulInfoData.fromJson(Map<String, dynamic> json) {
    return UsefulInfoData(
      title: json['title'] ?? 'Полезная информация',
      mainItems: (json['mainItems'] as List<dynamic>?)
          ?.map((item) => MainInfoItem.fromJson(item))
          .toList() ?? [],
      sideItems: (json['sideItems'] as List<dynamic>?)
          ?.map((item) => SideInfoItem.fromJson(item))
          .toList() ?? [],
    );
  }
}

class MainInfoItem {
  final String id;
  final String title;
  final String imageUrl;
  final String link;

  MainInfoItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.link,
  });

  factory MainInfoItem.fromJson(Map<String, dynamic> json) {
    return MainInfoItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      link: json['link'] ?? '',
    );
  }
}

class SideInfoItem {
  final String id;
  final String type;
  final String link;

  SideInfoItem({
    required this.id,
    required this.type,
    required this.link,
  });

  factory SideInfoItem.fromJson(Map<String, dynamic> json) {
    return SideInfoItem(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      link: json['link'] ?? '',
    );
  }
} 