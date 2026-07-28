import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../models/location_data.dart';
import '../models/place_model.dart';
import '../models/event_model.dart';
import 'places_screen.dart';
import 'track_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MapController _mapCtrl = MapController();
  List<LocationData> _locations = [];
  List<PlaceModel> _places = [];
  List<EventModel> _events = [];
  List<Map<String, dynamic>> _historyPoints = [];
  Timer? _timer;
  bool _loading = true;
  Position? _myPosition;
  bool _mapInitialized = false;
  String _myAddress = '';

  @override
  void initState() {
    super.initState();
    _initMyLocation();
    _loadData();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _loadData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initMyLocation() async {
    final cached = await LocationService.getCachedPosition();
    if (cached != null && mounted) {
      setState(() => _myPosition = Position(
        latitude: cached['lat']!, longitude: cached['lng']!,
        accuracy: 0, altitude: 0, heading: 0, speed: 0,
        speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0,
        timestamp: DateTime.now(),
      ));
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() => _myPosition = pos);
        _centerMap(pos.latitude, pos.longitude);
        _fetchAddress(pos.latitude, pos.longitude);
      }
    } catch (_) {}
  }

  Future<void> _fetchAddress(double lat, double lng) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng';
      final resp = await http.get(Uri.parse(url), headers: {'User-Agent': 'FamilyTracker/1.0'});
      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(resp.body);
        setState(() => _myAddress = data['display_name'] ?? '');
      }
    } catch (_) {}
  }

  void _centerMap(double lat, double lng) {
    if (!_mapInitialized) {
      _mapCtrl.move(LatLng(lat, lng), 15);
      _mapInitialized = true;
    }
  }

  Future<void> _loadData() async {
    try {
      final locs = await ApiService.getFamilyLocations();
      final plcs = await ApiService.getPlaces();
      final evts = await ApiService.getEvents();
      final history = await ApiService.getLocationHistory(hours: 1);
      if (!mounted) return;
      setState(() {
        _locations = locs.map((l) => LocationData.fromJson(l)).toList();
        _places = plcs.map((p) => PlaceModel.fromJson(p)).toList();
        _events = evts.map((e) => EventModel.fromJson(e)).toList();
        _historyPoints = history.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showSosConfirmation() async {
    if (_myPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not available')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Send SOS?'),
        content: const Text('This will alert all family members with your current location.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ApiService.sendSos(_myPosition!.latitude, _myPosition!.longitude);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS alert sent!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf0f2f5),
      appBar: AppBar(
        title: const Text('Family Tracker'),
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.map), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlacesScreen()))),
          IconButton(icon: const Icon(Icons.my_location), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackScreen()))),
          if (_myPosition != null)
            IconButton(icon: const Icon(Icons.gps_fixed), onPressed: () => _mapCtrl.move(LatLng(_myPosition!.latitude, _myPosition!.longitude), 15)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSosConfirmation,
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.warning),
        label: const Text('SOS'),
      ),
      body: _loading && _locations.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    child: FlutterMap(
                      mapController: _mapCtrl,
                      options: const MapOptions(initialCenter: LatLng(20, 78), initialZoom: 5),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                          userAgentPackageName: 'com.familytracker.app',
                          subdomains: const ['a', 'b', 'c'],
                        ),
                        if (_historyPoints.length > 1)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _historyPoints.map((p) => LatLng(p['latitude'], p['longitude'])).toList(),
                                color: Colors.blue.withValues(alpha: 0.5),
                                strokeWidth: 3,
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            if (_myPosition != null)
                              Marker(
                                point: LatLng(_myPosition!.latitude, _myPosition!.longitude),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.blue.shade900, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('You', style: TextStyle(color: Colors.white, fontSize: 11)),
                                    ),
                                    if (_myAddress.isNotEmpty)
                                      Container(
                                        constraints: const BoxConstraints(maxWidth: 180),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.blue.shade800, borderRadius: BorderRadius.circular(4)),
                                        child: Text(_myAddress, style: const TextStyle(color: Colors.white70, fontSize: 8), maxLines: 2, overflow: TextOverflow.ellipsis),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3498db),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 3),
                                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)],
                                      ),
                                      child: const Icon(Icons.person, color: Colors.white, size: 18),
                                    ),
                                  ],
                                ),
                              ),
                            ..._locations.map((loc) => Marker(
                              point: LatLng(loc.latitude, loc.longitude),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                                    child: Text(loc.displayName, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: loc.displayName.contains('SOS') ? Colors.red : (loc.online ? const Color(0xFF27ae60) : Colors.grey),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)],
                                    ),
                                    child: Text(loc.displayName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                        if (_myPosition != null)
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: LatLng(_myPosition!.latitude, _myPosition!.longitude),
                                radius: (_myPosition!.accuracy > 0 ? _myPosition!.accuracy : 50).toDouble(),
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderColor: Colors.blue,
                                borderStrokeWidth: 1,
                              ),
                            ],
                          ),
                        if (_places.isNotEmpty)
                          CircleLayer(
                            circles: _places.map((p) => CircleMarker(
                              point: LatLng(p.latitude, p.longitude),
                              radius: p.radiusMeters.toDouble(),
                              color: Colors.red.withValues(alpha: 0.1),
                              borderColor: Colors.red,
                              borderStrokeWidth: 2,
                            )).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.notifications, size: 20, color: Color(0xFF4a4ae0)),
                            const SizedBox(width: 8),
                            const Text('Recent Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text('${_events.length} alerts', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _events.isEmpty
                              ? const Center(child: Text('No alerts yet', style: TextStyle(color: Colors.grey)))
                              : ListView.builder(
                                  itemCount: _events.length > 10 ? 10 : _events.length,
                                  itemBuilder: (_, i) {
                                    final e = _events[i];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      child: ListTile(
                                        dense: true,
                                        leading: Icon(e.isEnter ? Icons.login : Icons.logout, color: e.isEnter ? Colors.green : Colors.red, size: 20),
                                        title: Text(e.message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                        trailing: Text(e.time, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
