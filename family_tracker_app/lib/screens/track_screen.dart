import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  bool _isTracking = false;
  bool _batterySaver = false;

  @override
  void initState() {
    super.initState();
  }

  void _toggle() async {
    if (_isTracking) {
      LocationService.stopTracking();
      setState(() => _isTracking = false);
    } else {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Please enable location services');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Location permission denied');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack('Location permission permanently denied');
        return;
      }
      await LocationService.startTracking();
      setState(() => _isTracking = true);
      _showSnack('Tracking active');
    }
  }

  void _showSnack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final pos = LocationService.lastPosition;
    return Scaffold(
      backgroundColor: const Color(0xFFf0f2f5),
      appBar: AppBar(
        title: const Text('Location Tracking'),
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Center(
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
              Text(
                _isTracking ? 'Tracking active' : 'Tap Start to begin tracking',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: _isTracking ? const Color(0xFF27ae60) : Colors.grey),
              ),
              const SizedBox(height: 32),
              if (pos != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                  child: Column(
                    children: [
                      _infoRow('Latitude', pos.latitude.toStringAsFixed(6)),
                      const SizedBox(height: 8),
                      _infoRow('Longitude', pos.longitude.toStringAsFixed(6)),
                      const SizedBox(height: 8),
                      _infoRow('Accuracy', '${pos.accuracy.toStringAsFixed(0)}m'),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Battery Saver'),
                  const SizedBox(width: 8),
                  Switch(
                    value: _batterySaver,
                    onChanged: (v) {
                      LocationService.setBatterySaver(v);
                      setState(() => _batterySaver = v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  onPressed: _toggle,
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
