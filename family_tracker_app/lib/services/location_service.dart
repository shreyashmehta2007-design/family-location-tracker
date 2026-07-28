import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/offline_queue.dart';

class LocationService {
  static const _cacheKey = 'cached_location';
  static const _stationaryDistance = 20.0;
  static const _stationaryDuration = Duration(seconds: 120);
  static StreamSubscription<Position>? _sub;
  static Position? _lastPosition;
  static bool _isTracking = false;
  static bool _manualBatterySaver = false;
  static bool _autoBatterySaver = false;
  static List<_PositionRecord> _recentPositions = [];
  static DateTime? _streamStartedAt;

  static Position? get lastPosition => _lastPosition;
  static bool get isTracking => _isTracking;
  static bool get batterySaverActive => _manualBatterySaver || _autoBatterySaver;

  static Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    if (permission == LocationPermission.whileInUse) {
      await Geolocator.requestPermission();
    }

    return true;
  }

  static void setBatterySaver(bool value) {
    _manualBatterySaver = value;
    if (_isTracking) {
      _sub?.cancel();
      _startStream();
    }
  }

  static Future<void> startTracking() async {
    if (_isTracking) return;

    final hasPermission = await requestPermissions();
    if (!hasPermission) return;

    _isTracking = true;
    _recentPositions = [];
    _streamStartedAt = DateTime.now();
    _startStream();
  }

  static void _startStream() {
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: batterySaverActive ? LocationAccuracy.low : LocationAccuracy.high,
        distanceFilter: batterySaverActive ? 50 : 10,
      ),
    ).listen((pos) {
      _lastPosition = pos;
      _cachePosition(pos.latitude, pos.longitude);
      _reportToServer(pos.latitude, pos.longitude, pos.accuracy);
      _checkAutoBatterySaver(pos);
    });
  }

  static void _checkAutoBatterySaver(Position pos) {
    _recentPositions.add(_PositionRecord(pos.latitude, pos.longitude, DateTime.now()));
    while (_recentPositions.length > 20) {
      _recentPositions.removeAt(0);
    }

    bool wasStationary = true;
    if (_recentPositions.length >= 3) {
      final oldest = _recentPositions.first;
      final newest = _recentPositions.last;
      final elapsed = newest.time.difference(oldest.time);
      final distance = _haversine(oldest.lat, oldest.lng, newest.lat, newest.lng);
      wasStationary = elapsed >= _stationaryDuration && distance < _stationaryDistance;
    }

    final shouldAutoSaver = wasStationary && (_streamStartedAt == null || DateTime.now().difference(_streamStartedAt!) >= _stationaryDuration);

    if (shouldAutoSaver != _autoBatterySaver) {
      _autoBatterySaver = shouldAutoSaver;
      if (!_manualBatterySaver) {
        _sub?.cancel();
        _startStream();
      }
    }
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final sinLat = math.sin(dLat / 2);
    final sinLon = math.sin(dLon / 2);
    final a = sinLat * sinLat + math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) * sinLon * sinLon;
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * math.pi / 180;

  static void stopTracking() {
    _sub?.cancel();
    _sub = null;
    _isTracking = false;
    _autoBatterySaver = false;
    _recentPositions = [];
    _streamStartedAt = null;
  }

  static Future<void> _cachePosition(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode({'lat': lat, 'lng': lng}));
  }

  static Future<Map<String, double>?> getCachedPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      return {'lat': data['lat'], 'lng': data['lng']};
    } catch (_) {
      return null;
    }
  }

  static Future<void> _reportToServer(double lat, double lng, double acc) async {
    try {
      await ApiService.reportLocation(lat, lng, acc);
      await OfflineQueue.syncQueue();
    } catch (_) {
      await OfflineQueue.addToQueue(lat, lng, acc);
    }
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
    _isTracking = false;
    _autoBatterySaver = false;
    _recentPositions = [];
    _streamStartedAt = null;
  }
}

class _PositionRecord {
  final double lat;
  final double lng;
  final DateTime time;
  _PositionRecord(this.lat, this.lng, this.time);
}
