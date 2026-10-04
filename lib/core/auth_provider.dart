import 'dart:math';

import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'models/user_model.dart';
import 'node_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();
  final NodeService _nodes = NodeService();

  UserModel? user;
  bool booting = true;
  bool busy = false;
  String? error;
  String? nodeId;
  String? nodeName;

  bool get isLoggedIn => user != null;

  Future<void> bootstrap() async {
    booting = true;
    notifyListeners();
    try {
      user = await _auth.loadSavedUser();
      if (user != null) {
        await _ensureDevice();
      }
    } catch (e) {
      error = e.toString();
    }
    booting = false;
    notifyListeners();
  }

  Future<void> _ensureDevice() async {
    final node = await _nodes.ensureHydroNode();
    nodeId = node?['_id']?.toString() ?? node?['id']?.toString();
    nodeName = node?['name']?.toString() ?? 'Thủy Canh IoT STEM';
  }

  Future<bool> login(String email, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      user = await _auth.login(email.trim(), password);
      await _ensureDevice();
      busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      busy = false;
      notifyListeners();
      return false;
    }
  }

  /// Đăng ký — không lấy SĐT từ UI; sinh số ngẫu nhiên để lọt validation AloT.
  Future<bool> register(String name, String email, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final phone = _randomPhoneForBackend();
      user = await _auth.register(name.trim(), email.trim(), phone, password);
      await _ensureDevice();
      busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      busy = false;
      notifyListeners();
      return false;
    }
  }

  /// SĐT kỹ thuật ẩn (10 số VN) — không hiện trên UI.
  String _randomPhoneForBackend() {
    final r = Random.secure();
    const prefixes = ['03', '05', '07', '08', '09'];
    final prefix = prefixes[r.nextInt(prefixes.length)];
    final rest = List.generate(8, (_) => r.nextInt(10)).join();
    // thêm entropy thời gian nếu trùng hiếm gặp
    final mix = (DateTime.now().microsecondsSinceEpoch % 10).toString();
    final digits = '$prefix$rest';
    return (digits.substring(0, 9) + mix).substring(0, 10);
  }

  Future<void> logout() async {
    await _auth.logout();
    user = null;
    nodeId = null;
    nodeName = null;
    notifyListeners();
  }

  DateTime? _lastSync;

  Future<void> syncTelemetry(Map<String, dynamic> state) async {
    if (nodeId == null) return;
    final now = DateTime.now();
    if (_lastSync != null && now.difference(_lastSync!) < const Duration(seconds: 20)) {
      return;
    }
    _lastSync = now;
    await _nodes.updateState(nodeId!, state);
  }
}
