class UserProfile {
  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final String? city;
  final String? authMethod;
  final String? oauthProvider;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final bool isProfileComplete;
  final DateTime? lastLogin;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.city,
    this.authMethod,
    this.oauthProvider,
    required this.isEmailVerified,
    required this.isPhoneVerified,
    required this.isProfileComplete,
    this.lastLogin,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      city: json['city']?.toString(),
      authMethod: json['authMethod']?.toString(),
      oauthProvider: json['oauthProvider']?.toString(),
      isEmailVerified: json['isEmailVerified'] ?? false,
      isPhoneVerified: json['isPhoneVerified'] ?? false,
      isProfileComplete: json['isProfileComplete'] ?? false,
      lastLogin: json['lastLogin'] != null 
          ? DateTime.tryParse(json['lastLogin'].toString()) 
          : null,
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt'].toString()) 
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.tryParse(json['updatedAt'].toString()) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'city': city,
      'authMethod': authMethod,
      'oauthProvider': oauthProvider,
      'isEmailVerified': isEmailVerified,
      'isPhoneVerified': isPhoneVerified,
      'isProfileComplete': isProfileComplete,
      'lastLogin': lastLogin?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Вспомогательные геттеры
  String get displayName => name ?? 'Пользователь';
  String get displayCity => city ?? 'Не указан';
  String get displayEmail => email ?? 'Не указан';

  @override
  String toString() {
    return 'UserProfile(id: $id, name: $name, email: $email, city: $city)';
  }
} 