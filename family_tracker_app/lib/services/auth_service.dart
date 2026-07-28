import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _tokenKey = 'session_token';
  static String? _sessionToken;

  static Future<void> saveToken(String token) async {
    _sessionToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    if (_sessionToken != null) return _sessionToken;
    final prefs = await SharedPreferences.getInstance();
    _sessionToken = prefs.getString(_tokenKey);
    return _sessionToken;
  }

  static Future<void> clearToken() async {
    _sessionToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}