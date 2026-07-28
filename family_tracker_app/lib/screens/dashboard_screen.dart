import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
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
  Timer? _timer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _loadData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final locs = await ApiService.getFamilyLocations();
      final plcs = await ApiService.getPlaces();
      final evts = await ApiService.getEvents();
      if (!mounted) return;
      setState(() {
        _locations = locs.map((l) => LocationData.fromJson(l)).toList();
        _places = plcs.map((p) => PlaceModel.fromJson(p)).toList();
        _events = evts.map((e) => EventModel.fromJson(e)).toList();
        _loading = false;
      });
      if (_locations.isNotEmpty) {
        final avgLat = _locations.map((l) => l.latitude).reduce((a, b) => a + b) / _locations.length;
        final avgLng = _locations.map((l) => l.longitude).reduce((a, b) => a + b) / _locations.length;
        _mapCtrl.move(LatLng(avgLat, avgLng), 13);
      }
    } catch (_) {}
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
        ],
      ),
      body: _loading
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
                        TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'),
                        if (_locations.isNotEmpty)
                          MarkerLayer(
                            markers: _locations.map((loc) => Marker(
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
                                      color: loc.online ? const Color(0xFF27ae60) : Colors.grey,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)],
                                    ),
                                    child: Text(loc.displayName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            )).toList(),
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