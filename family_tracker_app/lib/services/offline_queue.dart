import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class OfflineQueue {
  static const _key = 'offline_queue';

  static Future<void> addToQueue(double lat, double lng, double acc) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final queue = raw != null ? jsonDecode(raw) as List : [];
    queue.add({'latitude': lat, 'longitude': lng, 'accuracy': acc});
    await prefs.setString(_key, jsonEncode(queue));
  }

  static Future<void> syncQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final queue = jsonDecode(raw) as List;
    if (queue.isEmpty) return;
    final remaining = <Map<String, dynamic>>[];
    for (final item in queue) {
      try {
        await ApiService.reportLocation(
          item['latitude'], item['longitude'], item['accuracy'],
        );
      } catch (_) {
        remaining.add(item as Map<String, dynamic>);
      }
    }
    await prefs.setString(_key, remaining.isNotEmpty ? jsonEncode(remaining) : '[]');
  }

  static Future<bool> hasPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return false;
    final queue = jsonDecode(raw) as List;
    return queue.isNotEmpty;
  }
}
