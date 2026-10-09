import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'alert_engine.dart';
import 'hydro_notifications.dart';

/// Khi app đang mở mà dịch vụ nền chưa chạy, vẫn báo từ tiến trình chính.
class AlertDispatcher {
  AlertDispatcher._();

  static final AlertEngine engine = AlertEngine();
  static Timer? _quiet;
  static DateTime? _checked;
  static bool _serviceOwns = false;

  static void reset() {
    _quiet?.cancel();
    _quiet = null;
    engine.reset();
  }

  static void markReconnect() {
    engine.pendingReconnect = true;
  }

  static void onUiMessage(String topic, dynamic value) {
    if (!engine.ingest(topic, value)) return;
    _quiet?.cancel();
    _quiet = Timer(const Duration(milliseconds: 800), () {
      unawaited(_flush());
    });
  }

  static Future<void> _flush() async {
    if (await _serviceOwnsAlerts()) return;
    final reconnect = engine.pendingReconnect;
    engine.pendingReconnect = false;
    final due = engine.consume(reconnect: reconnect);
    await HydroNotifications.showAlerts(due, fromReconnect: reconnect);
    await HydroNotifications.dismissInactive(engine.activeIds);
  }

  static Future<bool> _serviceOwnsAlerts() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    final now = DateTime.now();
    if (_checked != null && now.difference(_checked!) < const Duration(seconds: 4)) {
      return _serviceOwns;
    }
    try {
      _serviceOwns = await FlutterBackgroundService().isRunning();
    } catch (_) {
      _serviceOwns = false;
    }
    _checked = now;
    return _serviceOwns;
  }
}
