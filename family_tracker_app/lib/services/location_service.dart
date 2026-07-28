import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/offline_queue.dart';

class LocationService {
  static const _cacheKey = 'cached_location';
  static StreamSubscription<Position>? _sub;
  static Position? _lastPosition;
  static bool _isTracking = false;
  static bool _batterySaver = false;

  static Position? get lastPosition => _lastPosition;
  static bool get isTracking => _isTracking;

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
      final bgPermission = await Geolocator.requestPermission();
      if (bgPermission == LocationPermission.denied || bgPermission == LocationPermission.deniedForever) {
      }
    }

    return true;
  }

  static void setBatterySaver(bool value) {
    _batterySaver = value;
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
    _startStream();
  }

  static void _startStream() {
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: _batterySaver ? LocationAccuracy.low : LocationAccuracy.high,
        distanceFilter: _batterySaver ? 50 : 10,
      ),
    ).listen((pos) {
      _lastPosition = pos;
      _cachePosition(pos.latitude, pos.longitude);
      _reportToServer(pos.latitude, pos.longitude, pos.accuracy);
    });
  }

  static void stopTracking() {
    _sub?.cancel();
    _sub = null;
    _isTracking = false;
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
  }
}
