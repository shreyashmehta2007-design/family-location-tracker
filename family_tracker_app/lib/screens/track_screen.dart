import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  Position? _position;
  int _sentCount = 0;
  bool _isTracking = false;
  StreamSubscription<Position>? _sub;
  String _status = 'Tap Start to begin tracking';

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _setStatus('Please enable location services');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _setStatus('Location permission denied');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _setStatus('Location permission permanently denied');
      return;
    }
    setState(() => _isTracking = true);
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((pos) {
      setState(() => _position = pos);
      _sendLocation(pos.latitude, pos.longitude, pos.accuracy);
    });
    _setStatus('Tracking active');
  }

  void _stop() {
    _sub?.cancel();
    setState(() => _isTracking = false);
    _setStatus('Tracking stopped');
  }

  Future<void> _sendLocation(double lat, double lng, double acc) async {
    try {
      await ApiService.reportLocation(lat, lng, acc);
      setState(() => _sentCount++);
    } catch (_) {}
  }

  void _setStatus(String msg) => setState(() => _status = msg);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf0f2f5),
      appBar: AppBar(
        title: const Text('Location Tracking'),
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isTracking ? const Color(0xFF27ae60).withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                  border: Border.all(color: _isTracking ? const Color(0xFF27ae60) : Colors.grey, width: 3),
                ),
                child: Icon(_isTracking ? Icons.my_location : Icons.location_off, size: 50, color: _isTracking ? const Color(0xFF27ae60) : Colors.grey),
              ),
              const SizedBox(height: 24),
              Text(_status, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: _isTracking ? const Color(0xFF27ae60) : Colors.grey)),
              const SizedBox(height: 32),
              if (_position != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                  child: Column(
                    children: [
                      _infoRow('Latitude', _position!.latitude.toStringAsFixed(6)),
                      const SizedBox(height: 8),
                      _infoRow('Longitude', _position!.longitude.toStringAsFixed(6)),
                      const SizedBox(height: 8),
                      _infoRow('Accuracy', '${_position!.accuracy.toStringAsFixed(0)}m'),
                      const SizedBox(height: 8),
                      _infoRow('Updates Sent', '$_sentCount'),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isTracking ? _stop : _start,
                  icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                  label: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking', style: const TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTracking ? Colors.red : const Color(0xFF4a4ae0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace')),
      ],
    );
  }
}