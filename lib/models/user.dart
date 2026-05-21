class User {
  final String id;
  final String? profileId;
  final String email;
  final String name;
  final String? profileImageUrl;
  final String preferredLanguage;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime createdAt;

  User({
    required this.id,
    this.profileId,
    required this.email,
    required this.name,
    this.profileImageUrl,
    required this.preferredLanguage,
    required this.isOnline,
    this.lastSeen,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'],
      profileId: json['profileId'] ?? json['profile_id'],
      email: json['email'],
      name: json['name'],
      profileImageUrl: json['profileImageUrl'] ?? json['profile_image_url'],
      preferredLanguage:
          json['preferredLanguage'] ?? json['preferred_language'] ?? 'en',
      isOnline: json['isOnline'] ?? json['is_online'] ?? false,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'])
          : (json['last_seen'] != null
              ? DateTime.parse(json['last_seen'])
              : null),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profileId': profileId,
      'email': email,
      'name': name,
      'profileImageUrl': profileImageUrl,
      'preferredLanguage': preferredLanguage,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? profileId,
    String? email,
    String? name,
    String? profileImageUrl,
    String? preferredLanguage,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      email: email ?? this.email,
      name: name ?? this.name,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
