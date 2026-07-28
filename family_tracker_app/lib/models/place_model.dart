class PlaceModel {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusMeters;

  PlaceModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      radiusMeters: json['radius_meters'] ?? 100,
    );
  }
}