import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../models/place_model.dart';

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  final _nameCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController(text: '100');
  final _mapCtrl = MapController();
  List<PlaceModel> _places = [];
  LatLng? _selectedPos;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    final data = await ApiService.getPlaces();
    if (!mounted) return;
    setState(() => _places = data.map((p) => PlaceModel.fromJson(p)).toList());
  }

  Future<void> _addPlace() async {
    if (_nameCtrl.text.trim().isEmpty || _selectedPos == null) return;
    final radius = int.tryParse(_radiusCtrl.text) ?? 100;
    await ApiService.addPlace(_nameCtrl.text.trim(), _selectedPos!.latitude, _selectedPos!.longitude, radius);
    _nameCtrl.clear();
    setState(() => _selectedPos = null);
    _loadPlaces();
  }

  Future<void> _deletePlace(int id) async {
    await ApiService.deletePlace(id);
    _loadPlaces();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf0f2f5),
      appBar: AppBar(
        title: const Text('Geofenced Places'),
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter: const LatLng(20, 78),
                  initialZoom: 5,
                  onTap: (tapPos, latlng) => setState(() => _selectedPos = latlng),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                    userAgentPackageName: 'com.familytracker.app',
                    subdomains: const ['a', 'b', 'c'],
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
                  if (_selectedPos != null)
                    MarkerLayer(
                      markers: [Marker(point: _selectedPos!, child: const Icon(Icons.location_on, color: Colors.blue, size: 40))],
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(hintText: 'Place name', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _radiusCtrl,
                            decoration: const InputDecoration(hintText: 'Radius', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12), suffixText: 'm'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _selectedPos == null || _nameCtrl.text.trim().isEmpty ? null : _addPlace,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4a4ae0), foregroundColor: Colors.white),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    if (_selectedPos != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Selected: ${_selectedPos!.latitude.toStringAsFixed(4)}, ${_selectedPos!.longitude.toStringAsFixed(4)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _places.isEmpty
                ? const Center(child: Text('No places added yet', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _places.length,
                    itemBuilder: (_, i) {
                      final p = _places[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: Color(0xFF4a4ae0), child: Icon(Icons.place, color: Colors.white)),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)} • ${p.radiusMeters}m radius'),
                          trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deletePlace(p.id)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}