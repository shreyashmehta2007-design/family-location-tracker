import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../services/auth_service.dart';

class ApiService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Cookie': 'session=$token',
    };
  }

  static Future<http.Response> _request(
    String method, String path, {Map<String, dynamic>? body}
  ) async {
    final uri = Uri.parse('${Config.baseUrl}$path');
    final headers = await _headers();
    http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
      case 'POST':
        response = await http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
      case 'PUT':
        response = await http.put(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
      default:
        throw Exception('Invalid method');
    }
    return response;
  }

  static Future<Map<String, dynamic>> login(String username, String password) async {
    final resp = await http.post(
      Uri.parse('${Config.baseUrl}/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (resp.statusCode == 200) {
      final cookie = resp.headers['set-cookie'];
      if (cookie != null) {
        final match = RegExp(r'session=([^;]+)').firstMatch(cookie);
        if (match != null) await AuthService.saveToken(match.group(1)!);
      }
      return {'status': 'ok'};
    }
    return {'error': 'Invalid credentials'};
  }

  static Future<Map<String, dynamic>> register(String username, String password) async {
    final resp = await http.post(
      Uri.parse('${Config.baseUrl}/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (resp.statusCode == 200) return {'status': 'ok'};
    final data = jsonDecode(resp.body);
    return {'error': data['error'] ?? 'Registration failed'};
  }

  static Future<Map<String, dynamic>> createFamily(String name) async {
    final resp = await _request('POST', '/api/family/create', body: {'name': name});
    return jsonDecode(resp.body);
  }

  static Future<Map<String, dynamic>> joinFamily(String code) async {
    final resp = await _request('POST', '/api/family/join', body: {'invite_code': code});
    return jsonDecode(resp.body);
  }

  static Future<List<dynamic>> getFamilyMembers() async {
    final resp = await _request('GET', '/api/family/members');
    final data = jsonDecode(resp.body);
    return data['members'];
  }

  static Future<List<dynamic>> getPlaces() async {
    final resp = await _request('GET', '/api/places');
    final data = jsonDecode(resp.body);
    return data['places'];
  }

  static Future<Map<String, dynamic>> addPlace(String name, double lat, double lng, int radius) async {
    final resp = await _request('POST', '/api/places', body: {
      'name': name, 'latitude': lat, 'longitude': lng, 'radius_meters': radius,
    });
    return jsonDecode(resp.body);
  }

  static Future<void> deletePlace(int id) async {
    await _request('DELETE', '/api/places/$id');
  }

  static Future<void> reportLocation(double lat, double lng, double acc) async {
    await _request('POST', '/api/location', body: {
      'latitude': lat, 'longitude': lng, 'accuracy': acc,
    });
  }

  static Future<List<dynamic>> getFamilyLocations() async {
    final resp = await _request('GET', '/api/locations');
    final data = jsonDecode(resp.body);
    return data['locations'];
  }

  static Future<List<dynamic>> getEvents() async {
    final resp = await _request('GET', '/api/events');
    final data = jsonDecode(resp.body);
    return data['events'];
  }

  static Future<Map<String, dynamic>> leaveFamily() async {
    final resp = await _request('POST', '/api/family/leave');
    return jsonDecode(resp.body);
  }

  static Future<Map<String, dynamic>> checkFamily() async {
    try {
      final resp = await _request('GET', '/api/family/members');
      final data = jsonDecode(resp.body);
      return {'inFamily': data['members'].isNotEmpty, 'members': data['members']};
    } catch (_) {
      return {'inFamily': false, 'members': []};
    }
  }

  static Future<List<dynamic>> getLocationHistory({int? hours}) async {
    String path = '/api/location/history';
    if (hours != null) path += '?hours=$hours';
    final resp = await _request('GET', path);
    return jsonDecode(resp.body) as List;
  }

  static Future<void> sendSos(double lat, double lng) async {
    await _request('POST', '/api/sos', body: {'latitude': lat, 'longitude': lng});
  }
}
