import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alert_engine.dart';

/// Thông báo cục bộ trên điện thoại. Không cần sửa ESP32 hay máy chủ đẩy tin.
class HydroNotifications {
  HydroNotifications._();

  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  static bool _ready = false;

  static const monitorChannel = AndroidNotificationChannel(
    'hydro_monitor',
    'Giám sát thủy canh',
    description: 'Giữ kết nối để báo mực nước và pH khi ứng dụng đang tắt',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );

  static const alertChannel = AndroidNotificationChannel(
    'hydro_alerts',
    'Cảnh báo thủy canh',
    description: 'Mực nước đầy, mực nước thấp và pH lệch',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static bool get _isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static Future<void> init() async {
    if (_ready || kIsWeb || !_isMobile) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_stat_hydro'),
      iOS: DarwinInitializationSettings(),
    );
    await plugin.initialize(settings);

    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(monitorChannel);
    await android?.createNotificationChannel(alertChannel);
    _ready = true;
  }

  static Future<void> requestPermissions() async {
    if (!_isMobile) return;
    await init();
    if (Platform.isAndroid) {
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      final prefs = await SharedPreferences.getInstance();
      const askedKey = 'hydro_battery_asked';
      final battery = await Permission.ignoreBatteryOptimizations.status;
      if (!battery.isGranted && prefs.getBool(askedKey) != true) {
        await prefs.setBool(askedKey, true);
        await Permission.ignoreBatteryOptimizations.request();
      }
    }
  }

  /// Chặn báo trùng khi app và dịch vụ nền cùng nhận một gói MQTT.
  static const _repeatGuard = Duration(seconds: 25);

  static Future<void> showAlerts(
    List<HydroAlert> alerts, {
    required bool fromReconnect,
  }) async {
    if (alerts.isEmpty || !_isMobile) return;
    await init();
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final alert in alerts) {
      final key = 'hydro_alert_ms_${alert.id}';
      final prev = prefs.getInt(key) ?? 0;
      final gap = now - prev;
      if (gap >= 0 && gap < _repeatGuard.inMilliseconds) continue;
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'hydro_alerts',
          'Cảnh báo thủy canh',
          channelDescription: 'Mực nước đầy, mực nước thấp và pH lệch',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          playSound: true,
          enableVibration: true,
          icon: '@drawable/ic_stat_hydro',
          ticker: alert.title,
          styleInformation: BigTextStyleInformation(alert.body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
          presentBadge: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );
      await plugin.show(
        alert.notificationId,
        alert.title,
        alert.body,
        details,
        payload: alert.id,
      );
      await prefs.setInt(key, now);
      if (kDebugMode) {
        print(
          'ALERT ${fromReconnect ? 'reconnect' : 'edge'} ${alert.id}: ${alert.title}',
        );
      }
    }
  }

  static Future<void> dismissInactive(Set<String> activeIds) async {
    if (!_isMobile || !_ready) return;
    const known = ['water_full', 'water_low', 'ph'];
    for (final id in known) {
      if (activeIds.contains(id)) continue;
      final nid = HydroAlert(id: id, title: '', body: '').notificationId;
      await plugin.cancel(nid);
    }
  }
}
