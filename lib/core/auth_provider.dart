import 'dart:math';

import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'config.dart';
import 'models/user_model.dart';
import 'node_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();
  final NodeService _nodes = NodeService();

  UserModel? user;
  UserModel? _pendingUser;
  bool booting = true;
  bool busy = false;
  String? error;
  String? nodeId;
  String? nodeName;
  String? successBanner;

  bool get isLoggedIn => user != null;

  String? consumeSuccessBanner() {
    final msg = successBanner;
    successBanner = null;
    return msg;
  }

  Future<void> bootstrap() async {
    booting = true;
    notifyListeners();
    try {
      final savedChip = await _auth.loadSavedChipId();
      if (savedChip != null && savedChip.isNotEmpty) {
        AppConfig.setChipId(savedChip);
      }
      user = await _auth.loadSavedUser();
      if (user != null && AppConfig.chipId.isNotEmpty) {
        await _ensureDevice(AppConfig.chipId);
      }
    } catch (e) {
      error = e.toString();
    }
    booting = false;
    notifyListeners();
  }

  Future<void> _ensureDevice(String chipId) async {
    final node = await _nodes.ensureHydroNode(chipId: chipId);
    nodeId = node?['_id']?.toString() ?? node?['id']?.toString();
    nodeName = node?['name']?.toString() ?? AppConfig.deviceName;
  }

  Future<bool> login(String email, String password) async {
    busy = true;
    error = null;
    _pendingUser = null;
    notifyListeners();
    try {
      _pendingUser = await _auth.login(email.trim(), password);
      busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      if (error == null || error!.trim().isEmpty) {
        error = 'Đăng nhập chưa thành công';
      }
      busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    busy = true;
    error = null;
    _pendingUser = null;
    notifyListeners();
    try {
      final phone = _randomPhoneForBackend();
      _pendingUser = await _auth.register(name.trim(), email.trim(), phone, password);
      busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      if (error == null || error!.trim().isEmpty) {
        error = 'Đăng ký chưa thành công';
      }
      busy = false;
      notifyListeners();
      return false;
    }
  }

  void confirmPendingSession({required String successMessage}) {
    if (_pendingUser == null) return;
    user = _pendingUser;
    _pendingUser = null;
    successBanner = successMessage;
    notifyListeners();
  }

  Future<bool> resetPassword(String email, String newPassword) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final msg = await _auth.resetPassword(email, newPassword);
      successBanner = msg.isNotEmpty ? msg : 'Đặt lại mật khẩu thành công';
      busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      if (error == null || error!.trim().isEmpty) {
        error = 'Không đặt lại được mật khẩu';
      }
      busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> bindChip(String chipId) async {
    AppConfig.setChipId(chipId);
    await _auth.saveChipId(AppConfig.chipId);
    await _ensureDevice(AppConfig.chipId);
    notifyListeners();
  }

  Future<void> clearBoundChip() async {
    await _auth.clearChipId();
    nodeId = null;
    nodeName = null;
    notifyListeners();
  }

  String _randomPhoneForBackend() {
    final r = Random.secure();
    const prefixes = ['03', '05', '07', '08', '09'];
    final prefix = prefixes[r.nextInt(prefixes.length)];
    final rest = List.generate(8, (_) => r.nextInt(10)).join();
    final mix = (DateTime.now().microsecondsSinceEpoch % 10).toString();
    final digits = '$prefix$rest';
    return (digits.substring(0, 9) + mix).substring(0, 10);
  }

  Future<void> logout() async {
    await _auth.logout();
    user = null;
    _pendingUser = null;
    nodeId = null;
    nodeName = null;
    successBanner = null;
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
