import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alert_engine.dart';
import 'config.dart';
import 'hydro_notifications.dart';
import 'mqtt_service.dart';

const _monitorFlag = 'thuycanh_monitor';

/// Giữ MQTT sống sau khi người dùng tắt app, để điện thoại vẫn đổ chuông cảnh báo.
class BackgroundMonitor {
  BackgroundMonitor._();

  static bool _configured = false;

  static bool get _isMobile {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static Future<void> configure() async {
    if (_configured || !_isMobile) return;
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: hydroMonitorOnStart,
        autoStart: false,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: HydroNotifications.monitorChannel.id,
        initialNotificationTitle: 'Thủy Canh IoT',
        initialNotificationContent: 'Đang giám sát mực nước và pH',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: const [AndroidForegroundType.connectedDevice],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: hydroMonitorOnStart,
        onBackground: hydroIosBackground,
      ),
    );
    _configured = true;
  }

  static Future<void> sync({required bool enabled}) async {
    if (!_isMobile) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_monitorFlag, enabled);
    if (!_configured) await configure();

    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    if (!enabled) {
      if (running) service.invoke('stop');
      return;
    }

    try {
      await HydroNotifications.requestPermissions();
    } catch (_) {}
    if (running) {
      service.invoke('setChip', {'chipId': AppConfig.chipId});
    } else {
      await service.startService();
    }
  }
}

@pragma('vm:entry-point')
Future<bool> hydroIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void hydroMonitorOnStart(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  unawaited(_hydroMonitorMain(service));
}

Future<void> _hydroMonitorMain(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
  }

  final prefs = await SharedPreferences.getInstance();
  final enabled = prefs.getBool(_monitorFlag) ?? false;
  final chip = prefs.getString('thuycanh_chip_id')?.trim() ?? '';
  if (!enabled || chip.isEmpty) {
    await service.stopSelf();
    return;
  }

  AppConfig.setChipId(chip);
  await HydroNotifications.init();

  final engine = AlertEngine();
  final mqtt = MqttService(clientPrefix: 'thuycanh_bg', publishPresence: false);
  Timer? quiet;
  Timer? retry;
  var closed = false;
  var lastLine = '';

  Future<void> publishStatus(String line) async {
    if (line == lastLine) return;
    lastLine = line;
    if (service is AndroidServiceInstance) {
      await service.setForegroundNotificationInfo(
        title: 'Thủy Canh IoT',
        content: line,
      );
    }
  }

  Future<void> evaluate() async {
    if (closed) return;
    final reconnect = engine.pendingReconnect;
    engine.pendingReconnect = false;
    final due = engine.consume(reconnect: reconnect);
    await HydroNotifications.showAlerts(due, fromReconnect: reconnect);
    await HydroNotifications.dismissInactive(engine.activeIds);
    await publishStatus(engine.statusLine);
  }

  void arm() {
    quiet?.cancel();
    quiet = Timer(const Duration(milliseconds: 800), () {
      unawaited(evaluate());
    });
  }

  Future<void> ensureConnected() async {
    if (closed) return;
    final ok = await mqtt.connect();
    if (!ok && !closed) {
      retry?.cancel();
      retry = Timer(const Duration(seconds: 8), () {
        unawaited(ensureConnected());
      });
      await publishStatus('Chưa có mạng — sẽ báo khi kết nối lại');
    }
  }

  mqtt.onConnectedHook = () {
    engine.pendingReconnect = true;
    retry?.cancel();
    arm();
  };

  mqtt.messages.listen((data) {
    if (closed) return;
    final topic = data['topic'] as String? ?? '';
    if (!engine.ingest(topic, data['value'])) return;
    arm();
  });

  final connSub = Connectivity().onConnectivityChanged.listen((results) {
    if (closed) return;
    final online = results.any((r) => r != ConnectivityResult.none);
    if (!online) {
      unawaited(publishStatus('Mất mạng — sẽ báo khi có mạng và còn cảnh báo'));
      return;
    }
    engine.pendingReconnect = true;
    if (!mqtt.isConnected) {
      unawaited(ensureConnected());
    } else {
      arm();
    }
  });

  service.on('stop').listen((_) async {
    closed = true;
    quiet?.cancel();
    retry?.cancel();
    await connSub.cancel();
    await mqtt.dispose();
    await service.stopSelf();
  });

  service.on('setChip').listen((event) async {
    final id = event?['chipId']?.toString().trim() ?? '';
    if (id.isEmpty || closed) return;
    AppConfig.setChipId(id);
    engine.reset();
    await mqtt.connect(force: true);
  });

  await publishStatus('Đang giám sát máy $chip');
  await ensureConnected();
}
