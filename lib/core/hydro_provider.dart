import 'dart:async';

import 'package:flutter/foundation.dart';

import 'config.dart';
import 'mqtt_service.dart';

enum WaterAlertLevel { ok, full, low }

typedef TelemetrySync = Future<void> Function(Map<String, dynamic> state);

/// Provider riêng cho thủy canh — không dùng biến của máy Ngưng Tụ.
class HydroProvider extends ChangeNotifier {
  HydroProvider({MqttService? mqtt}) : _mqtt = mqtt ?? MqttService();

  final MqttService _mqtt;
  StreamSubscription? _sub;
  TelemetrySync? onTelemetry;

  bool connecting = false;
  bool online = false;
  bool powerOn = true;
  DateTime? lastUpdate;

  double? temperature;
  double? humidity;
  double? ph;
  double? tds;
  double? waterPct;
  double? distCm;
  double? lightPct;
  bool pumpOn = false;
  bool lampOn = false;
  WaterAlertLevel waterAlert = WaterAlertLevel.ok;
  String status = 'Chưa kết nối';

  bool get mqttConnected => _mqtt.isConnected;
  bool get hasTelemetry =>
      temperature != null ||
      humidity != null ||
      ph != null ||
      waterPct != null ||
      distCm != null;

  bool get isWaterLow => waterAlert == WaterAlertLevel.low;
  bool get isWaterFull => waterAlert == WaterAlertLevel.full;

  String get waterAlertTitle {
    switch (waterAlert) {
      case WaterAlertLevel.low:
        return 'Cảnh báo: mực nước thấp';
      case WaterAlertLevel.full:
        return 'Cảnh báo: mực nước đầy';
      case WaterAlertLevel.ok:
        return 'Mực nước ổn định';
    }
  }

  String get waterAlertBody {
    final d = distCm != null ? '${distCm!.toStringAsFixed(1)} cm' : '--';
    switch (waterAlert) {
      case WaterAlertLevel.low:
        return 'Cảm biến cách mặt nước $d (≥ ${AppConfig.distEmptyCm.toInt()} cm). '
            'Bơm tuần hoàn đã tắt — hãy bơm nước từ bên ngoài vào bể.';
      case WaterAlertLevel.full:
        return 'Cảm biến cách mặt nước $d (≤ ${AppConfig.distFullCm.toInt()} cm). '
            'Bể đã đầy — bơm tuần hoàn đang chạy tự động.';
      case WaterAlertLevel.ok:
        return 'Khoảng cách $d (ngưỡng đầy ${AppConfig.distFullCm.toInt()} cm / '
            'hết ${AppConfig.distEmptyCm.toInt()} cm).';
    }
  }

  String get friendlyStatus {
    if (!mqttConnected) return 'Đang kết nối MQTT...';
    if (!hasTelemetry) return 'Đã sẵn sàng — chờ dữ liệu cảm biến';
    if (isWaterLow) return waterAlertTitle;
    if (isWaterFull) return waterAlertTitle;
    final s = status.toUpperCase();
    if (s.contains('PH')) return 'Cảnh báo: pH ngoài khoảng 5.5–6.5';
    if (s.contains('TAT') || s.contains('TẮT') || !powerOn) {
      return 'Hệ thống đang tạm dừng từ app';
    }
    if (s == 'OK' || s.contains('SAN SANG') || s.contains('SẴN')) {
      return 'Hệ thống hoạt động tốt';
    }
    return status;
  }

  Future<void> start({bool force = false}) async {
    connecting = true;
    status = 'Đang kết nối thủy canh...';
    notifyListeners();

    _sub ??= _mqtt.messages.listen(_onMessage);

    final ok = await _mqtt.connect(force: force);
    connecting = false;
    if (!ok) {
      status = 'Chưa kết nối được — kéo xuống để thử lại';
      notifyListeners();
      return;
    }

    status = 'Đã sẵn sàng — đang chờ dữ liệu cảm biến';
    notifyListeners();
  }

  void _onMessage(Map<String, dynamic> data) {
    final topic = data['topic'] as String? ?? '';
    final value = data['value'];

    // Chỉ map topic chip 790 — không đụng topic 789 (máy Ngưng Tụ)
    if (_is(topic, AppConfig.topicOnline)) {
      online = value.toString().toLowerCase() == 'online';
      if (online) {
        status = hasTelemetry ? 'OK' : 'Đã sẵn sàng — chờ dữ liệu cảm biến';
      } else {
        status = 'Đang chờ tín hiệu từ ESP32...';
      }
    } else if (_is(topic, AppConfig.topicTemp)) {
      temperature = _asDouble(value);
    } else if (_is(topic, AppConfig.topicHumi)) {
      humidity = _asDouble(value);
    } else if (_is(topic, AppConfig.topicPh)) {
      ph = _asDouble(value);
    } else if (_is(topic, AppConfig.topicTds)) {
      tds = _asDouble(value);
    } else if (_is(topic, AppConfig.topicWater)) {
      waterPct = _asDouble(value);
    } else if (_is(topic, AppConfig.topicDist)) {
      distCm = _asDouble(value);
      _inferAlertFromDistance();
    } else if (_is(topic, AppConfig.topicWaterAlert)) {
      waterAlert = _parseWaterAlert(value);
    } else if (_is(topic, AppConfig.topicLight)) {
      lightPct = _asDouble(value);
    } else if (_is(topic, AppConfig.topicPump)) {
      pumpOn = _asOn(value);
    } else if (_is(topic, AppConfig.topicLamp)) {
      lampOn = _asOn(value);
    } else if (_is(topic, AppConfig.topicPower)) {
      powerOn = _asOn(value);
    } else if (_is(topic, AppConfig.topicStatus)) {
      status = value?.toString() ?? status;
      _inferAlertFromStatus(status);
    } else {
      return;
    }

    lastUpdate = DateTime.now();
    notifyListeners();

    if (hasTelemetry && onTelemetry != null) {
      onTelemetry!({
        'temperature': temperature,
        'humidity': humidity,
        'ph': ph,
        'tds': tds,
        'water': waterPct,
        'dist': distCm,
        'light': lightPct,
        'pump': pumpOn,
        'lamp': lampOn,
        'power': powerOn,
        'status': status,
        'waterAlert': waterAlert.name,
        'chipId': AppConfig.chipId,
      });
    }
  }

  void _inferAlertFromDistance() {
    final d = distCm;
    if (d == null) return;
    // Chỉ suy luận khi chưa nhận water_alert (giữ nếu đã có)
    if (d >= AppConfig.distEmptyCm) {
      waterAlert = WaterAlertLevel.low;
    } else if (d <= AppConfig.distFullCm) {
      waterAlert = WaterAlertLevel.full;
    } else if (waterAlert != WaterAlertLevel.ok) {
      // hysteresis nhẹ phía app
      if (d < AppConfig.distEmptyCm - 0.6 && d > AppConfig.distFullCm + 0.6) {
        waterAlert = WaterAlertLevel.ok;
      }
    }
  }

  void _inferAlertFromStatus(String s) {
    final u = s.toUpperCase();
    if (u.contains('NUOC THAP') || u.contains('BOM NGOAI')) {
      waterAlert = WaterAlertLevel.low;
    } else if (u.contains('NUOC DAY')) {
      waterAlert = WaterAlertLevel.full;
    }
  }

  WaterAlertLevel _parseWaterAlert(dynamic v) {
    final s = v.toString().trim().toUpperCase();
    if (s == 'LOW' || s == 'EMPTY' || s == 'THAP') return WaterAlertLevel.low;
    if (s == 'FULL' || s == 'DAY') return WaterAlertLevel.full;
    return WaterAlertLevel.ok;
  }

  bool _is(String topic, String expected) => topic == expected;

  void togglePower() {
    if (!_mqtt.isConnected) {
      status = 'Chưa kết nối — kéo xuống để thử lại';
      notifyListeners();
      return;
    }
    final next = !powerOn;
    powerOn = next;
    status = next ? 'Bat tu App' : 'Tat tu App';
    notifyListeners();
    _mqtt.setPower(next);
  }

  void togglePump() {
    if (!_mqtt.isConnected) return;
    final next = !pumpOn;
    pumpOn = next;
    notifyListeners();
    _mqtt.setPump(next ? 'ON' : 'OFF');
  }

  void toggleLamp() {
    if (!_mqtt.isConnected) return;
    final next = !lampOn;
    lampOn = next;
    notifyListeners();
    _mqtt.setLamp(next ? 'ON' : 'OFF');
  }

  void setPumpAuto() {
    if (!_mqtt.isConnected) return;
    _mqtt.setPump('AUTO');
  }

  void setLampAuto() {
    if (!_mqtt.isConnected) return;
    _mqtt.setLamp('AUTO');
  }

  Future<void> reconnect() => start(force: true);

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.'));
  }

  bool _asOn(dynamic v) {
    final s = v.toString().toUpperCase();
    return s == 'ON' || s == '1' || s == 'TRUE';
  }

  @override
  void dispose() {
    _sub?.cancel();
    _mqtt.dispose();
    super.dispose();
  }
}
