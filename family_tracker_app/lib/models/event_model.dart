class EventModel {
  final int id;
  final String message;
  final String eventType;
  final String createdAt;

  EventModel({required this.id, required this.message, required this.eventType, required this.createdAt});

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] ?? 0,
      message: json['message'] ?? '',
      eventType: json['event_type'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  bool get isEnter => eventType == 'enter';
  String get time => createdAt.length >= 19 ? createdAt.substring(11, 19) : createdAt;
}