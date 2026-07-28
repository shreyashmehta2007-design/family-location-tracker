class LocationData {
  final int userId;
  final String username;
  final String? nickname;
  final double latitude;
  final double longitude;
  final double accuracy;
  final String timestamp;
  final bool online;

  LocationData({
    required this.userId,
    required this.username,
    this.nickname,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    required this.online,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      userId: json['user_id'] ?? 0,
      username: json['username'] ?? '',
      nickname: json['nickname'],
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      accuracy: (json['accuracy'] ?? 0.0).toDouble(),
      timestamp: json['timestamp'] ?? '',
      online: json['online'] ?? false,
    );
  }

  String get displayName => nickname ?? username;
}