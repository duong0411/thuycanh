import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'alert_engine.dart';
import 'hydro_notifications.dart';

/// Báo cảnh báo từ tiến trình UI khi app đang mở.
class AlertDispatcher {
  AlertDispatcher._();

  static final AlertEngine engine = AlertEngine();
  static Timer? _quiet;

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

  /// Khi dịch vụ nền đang chạy, chỉ tiến trình đó bắn thông báo.
  static Future<bool> _serviceOwnsAlerts() async {
    if (kIsWeb) return false;
    try {
      return await FlutterForegroundTask.isRunningService;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _flush() async {
    try {
      if (await _serviceOwnsAlerts()) return;
      final reconnect = engine.pendingReconnect;
      engine.pendingReconnect = false;
      final due = engine.consume(reconnect: reconnect);
      await HydroNotifications.showAlerts(due, fromReconnect: reconnect);
      await HydroNotifications.dismissInactive(engine.activeIds);
    } catch (e) {
      if (kDebugMode) print('AlertDispatcher._flush: $e');
    }
  }
}
