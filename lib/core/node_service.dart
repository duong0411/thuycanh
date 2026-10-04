import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'config.dart';

class NodeService {
  String get baseUrl => AuthService.baseUrl;

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<List<Map<String, dynamic>>> getNodes() async {
    final token = await _token();
    if (token == null) return [];
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/nodes'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 12));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['data']['nodes']);
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> ensureHydroNode({String? chipId}) async {
    final token = await _token();
    if (token == null) return null;
    final id = (chipId ?? AppConfig.chipId).trim();
    if (id.isEmpty) return null;

    final nodes = await getNodes();
    final existing = nodes.where((n) => '${n['chipId']}' == id);
    if (existing.isNotEmpty) return existing.first;

    final res = await http
        .post(
          Uri.parse('$baseUrl/nodes'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'name': AppConfig.deviceName,
            'chipId': id,
            'templateType': 'kitchen_living',
            'state': {},
          }),
        )
        .timeout(const Duration(seconds: 12));

    final data = jsonDecode(res.body);
    if ((res.statusCode == 201 || res.statusCode == 200) && data['success'] == true) {
      return Map<String, dynamic>.from(data['data']['node']);
    }

    final again = await getNodes();
    final found = again.where((n) => '${n['chipId']}' == id);
    return found.isNotEmpty ? found.first : null;
  }

  Future<void> updateState(String nodeId, Map<String, dynamic> state) async {
    final token = await _token();
    if (token == null || nodeId.isEmpty) return;
    try {
      await http
          .put(
            Uri.parse('$baseUrl/nodes/$nodeId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'state': state}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }
}
