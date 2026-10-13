import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alert_engine.dart';
import 'config.dart';
import 'hydro_notifications.dart';
import 'mqtt_service.dart';

/// Giữ kết nối MQTT khi app không mở và bắn thông báo hệ thống.
class BackgroundMonitor {
  BackgroundMonitor._();

  static bool get _mobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static void configure() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'hydro_fg_watch',
        channelName: 'Giám sát thủy canh',
        channelDescription: 'Giữ kết nối để báo mực nước và pH khi không mở app',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        onlyAlertOnce: true,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(15000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
  }

  static Future<void> sync({required bool enabled}) async {
    if (!_mobile) return;
    try {
      if (!enabled) {
        if (await FlutterForegroundTask.isRunningService) {
          await FlutterForegroundTask.stopService();
        }
        return;
      }

      await HydroNotifications.requestPermissions();
      await FlutterForegroundTask.requestNotificationPermission();

      if (await FlutterForegroundTask.isRunningService) {
        FlutterForegroundTask.sendDataToTask(AppConfig.chipId);
        return;
      }

      final result = await FlutterForegroundTask.startService(
        serviceId: 790,
        serviceTypes: const [
          ForegroundServiceTypes.remoteMessaging,
        ],
        notificationTitle: 'Thủy canh đang giám sát',
        notificationText: 'Sẽ báo khi mực nước đầy, cạn hoặc pH lệch',
        callback: hydroBackgroundCallback,
      );
      if (result is ServiceRequestFailure && kDebugMode) {
        debugPrint('BackgroundMonitor start: ${result.error}');
      }

      final ignoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (!ignoring) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('BackgroundMonitor.sync: $e\n$st');
    }
  }
}

@pragma('vm:entry-point')
void hydroBackgroundCallback() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(HydroBackgroundHandler());
}

class HydroBackgroundHandler extends TaskHandler {
  final AlertEngine _engine = AlertEngine();
  MqttService? _mqtt;
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _quiet;
  bool _busy = false;
  String _chip = AppConfig.defaultChipId;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _openMqtt(force: true);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    final mqtt = _mqtt;
    if (mqtt == null || !mqtt.isConnected) {
      unawaited(_openMqtt(force: false));
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _quiet?.cancel();
    await _sub?.cancel();
    _sub = null;
    await _mqtt?.dispose();
    _mqtt = null;
  }

  @override
  void onReceiveData(Object data) {
    final next = data.toString().trim();
    if (next.isEmpty || next == _chip) return;
    _chip = next;
    unawaited(_openMqtt(force: true));
  }

  Future<void> _openMqtt({required bool force}) async {
    if (_busy) return;
    if (!force && _mqtt != null && _mqtt!.isConnected) return;
    _busy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final saved = prefs.getString('thuycanh_chip_id');
      _chip = (saved == null || saved.trim().isEmpty) ? _chip : saved.trim();
      AppConfig.setChipId(_chip);

      await _sub?.cancel();
      await _mqtt?.dispose();
      _engine.reset();

      final mqtt = MqttService(
        clientPrefix: 'thuycanh_bg',
        publishPresence: false,
      );
      mqtt.onConnectedHook = () => _engine.pendingReconnect = true;
      _sub = mqtt.messages.listen((msg) {
        final topic = msg['topic'];
        if (topic is! String) return;
        if (!_engine.ingest(topic, msg['value'])) return;
        _quiet?.cancel();
        _quiet = Timer(const Duration(milliseconds: 800), () {
          unawaited(_flushAlerts());
        });
      });
      _mqtt = mqtt;
      final ok = await mqtt.connect();
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Thủy canh đang giám sát',
        notificationText: ok
            ? 'Máy $_chip — sẽ báo khi mực nước hoặc pH lệch'
            : 'Chưa nối được máy $_chip, đang thử lại',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('HydroBackgroundHandler: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _flushAlerts() async {
    try {
      final reconnect = _engine.pendingReconnect;
      _engine.pendingReconnect = false;
      final due = _engine.consume(reconnect: reconnect);
      await HydroNotifications.showAlerts(due, fromReconnect: reconnect);
      await HydroNotifications.dismissInactive(_engine.activeIds);
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Thủy canh đang giám sát',
        notificationText: _engine.statusLine,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('HydroBackgroundHandler flush: $e');
    }
  }
}
