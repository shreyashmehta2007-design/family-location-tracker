import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FamilyTrackerApp());
}

class FamilyTrackerApp extends StatefulWidget {
  const FamilyTrackerApp({super.key});

  @override
  State<FamilyTrackerApp> createState() => _FamilyTrackerAppState();
}

class _FamilyTrackerAppState extends State<FamilyTrackerApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    ThemeService.isDark.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService.isDark.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() => _themeMode = ThemeService.isDark.value ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> _loadTheme() async {
    final dark = await ThemeService.isDarkMode();
    if (mounted) setState(() => _themeMode = dark ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4a4ae0),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFf0f2f5),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF4a4ae0),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await AuthService.getToken();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => token != null ? const HomeScreen() : const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.family_restroom, size: 80, color: Color(0xFF4a4ae0)),
            SizedBox(height: 16),
            Text('Family Tracker', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
