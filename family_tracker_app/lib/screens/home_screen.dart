import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'family_setup_screen.dart';
import 'places_screen.dart';
import 'track_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _checking = true;
  bool _inFamily = false;
  String _familyCode = '';

  @override
  void initState() {
    super.initState();
    _checkFamily();
  }

  @override
  void dispose() {
    LocationService.stopTracking();
    super.dispose();
  }

  Future<void> _checkFamily() async {
    final data = await ApiService.checkFamily();
    if (!mounted) return;
    final inFamily = data['inFamily'] ?? false;
    setState(() {
      _inFamily = inFamily;
      _checking = false;
    });
    if (inFamily) {
      LocationService.startTracking();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (!_inFamily) {
      return Scaffold(
        backgroundColor: const Color(0xFFf0f2f5),
        appBar: AppBar(
          title: const Text('Family Tracker'),
          backgroundColor: const Color(0xFF1a1a2e),
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                LocationService.stopTracking();
                await AuthService.clearToken();
                if (!context.mounted) return;
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.family_restroom, size: 80, color: Color(0xFF4a4ae0)),
                const SizedBox(height: 16),
                const Text('Welcome!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('You are not in a family yet.\nCreate one or join with an invite code.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilySetupScreen()));
                      if (result == true) _checkFamily();
                    },
                    icon: const Icon(Icons.group_add),
                    label: const Text('Create or Join Family', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4a4ae0),
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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFf0f2f5),
        appBar: AppBar(
          title: const Text('Family Tracker'),
          backgroundColor: const Color(0xFF1a1a2e),
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: () async {
              LocationService.stopTracking();
              await AuthService.clearToken();
              if (!context.mounted) return;
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            }),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(icon: Icon(Icons.map), text: 'Dashboard'),
              Tab(icon: Icon(Icons.place), text: 'Places'),
              Tab(icon: Icon(Icons.my_location), text: 'Track'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            DashboardScreen(),
            PlacesScreen(),
            TrackScreen(),
          ],
        ),
      ),
    );
  }
}
