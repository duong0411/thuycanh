import 'config.dart';

enum HydroWaterState { ok, full, low }

/// Một cảnh báo đẩy lên thanh thông báo của điện thoại.
class HydroAlert {
  const HydroAlert({
    required this.id,
    required this.title,
    required this.body,
  });

  final String id;
  final String title;
  final String body;

  int get notificationId {
    switch (id) {
      case 'water_full':
        return 4101;
      case 'water_low':
        return 4102;
      case 'ph':
        return 4103;
      default:
        return 4199;
    }
  }
}

/// Đọc telemetry MQTT (không đụng firmware) và quyết định lúc nào phải báo.
class AlertEngine {
  double? ph;
  double? distCm;
  String status = '';
  HydroWaterState waterFromTopic = HydroWaterState.ok;

  bool sawPh = false;
  bool sawDist = false;
  bool sawWater = false;
  bool sawStatus = false;

  /// Lần nối mạng / vừa bật dịch vụ: báo mọi cảnh báo đang tồn tại, không chỉ cảnh báo mới.
  bool pendingReconnect = true;

  final Set<String> previousIds = {};

  void reset() {
    ph = null;
    distCm = null;
    status = '';
    waterFromTopic = HydroWaterState.ok;
    sawPh = false;
    sawDist = false;
    sawWater = false;
    sawStatus = false;
    pendingReconnect = true;
    previousIds.clear();
  }

  bool _isOurChip(String topic) {
    final id = AppConfig.chipId;
    return topic == 'tele/$id/status' || topic.startsWith('tele/${id}_');
  }

  /// Trả về true khi gói tin thuộc máy đang theo dõi và có thể đổi cảnh báo.
  bool ingest(String topic, dynamic raw) {
    if (!_isOurChip(topic)) return false;
    final value = _unwrap(raw);

    if (topic == AppConfig.topicPh) {
      ph = _asDouble(value);
      sawPh = ph != null;
    } else if (topic == AppConfig.topicDist) {
      distCm = _asDouble(value);
      sawDist = distCm != null;
    } else if (topic == AppConfig.topicWaterAlert) {
      waterFromTopic = _parseWater(value);
      sawWater = true;
    } else if (topic == AppConfig.topicStatus) {
      status = value?.toString() ?? status;
      sawStatus = true;
    } else {
      return false;
    }
    return true;
  }

  HydroWaterState get water {
    if (sawWater) return waterFromTopic;
    if (sawDist && distCm != null) {
      if (distCm! >= AppConfig.distEmptyCm) return HydroWaterState.low;
      if (distCm! <= AppConfig.distFullCm) return HydroWaterState.full;
      return HydroWaterState.ok;
    }
    if (sawStatus) return _waterFromStatus(status);
    return HydroWaterState.ok;
  }

  bool get phBad {
    if (sawPh && ph != null) {
      return ph! < AppConfig.phLow || ph! > AppConfig.phHigh;
    }
    if (sawStatus && status.toUpperCase().contains('PH')) return true;
    return false;
  }

  List<HydroAlert> activeAlerts() {
    final alerts = <HydroAlert>[];
    final chip = AppConfig.chipId;
    final distText = distCm != null
        ? '${distCm!.toStringAsFixed(1)} cm'
        : 'ngưỡng ${AppConfig.distFullCm.toInt()} cm';

    switch (water) {
      case HydroWaterState.full:
        alerts.add(
          HydroAlert(
            id: 'water_full',
            title: 'Cảnh báo: mực nước đầy',
            body: 'Máy $chip — bể đã đầy (cách mặt nước $distText). '
                'Bơm tuần hoàn đang chạy tự động.',
          ),
        );
      case HydroWaterState.low:
        alerts.add(
          HydroAlert(
            id: 'water_low',
            title: 'Cảnh báo: mực nước thấp',
            body: 'Máy $chip — mực nước thấp (cách mặt nước $distText). '
                'Hãy bơm nước từ bên ngoài vào bể.',
          ),
        );
      case HydroWaterState.ok:
        break;
    }

    if (phBad) {
      final phText = ph != null ? ph!.toStringAsFixed(2) : 'ngoài khoảng';
      alerts.add(
        HydroAlert(
          id: 'ph',
          title: 'Cảnh báo: pH lệch',
          body: 'Máy $chip — pH đang là $phText, ngoài khoảng an toàn '
              '${AppConfig.phLow}–${AppConfig.phHigh}.',
        ),
      );
    }
    return alerts;
  }

  Set<String> get activeIds => activeAlerts().map((a) => a.id).toSet();

  /// [reconnect] = true khi vừa có mạng / vừa nối lại MQTT: báo lại cảnh báo đang có.
  List<HydroAlert> consume({required bool reconnect}) {
    final active = activeAlerts();
    final ids = active.map((a) => a.id).toSet();
    final due = reconnect
        ? active
        : active.where((a) => !previousIds.contains(a.id)).toList();
    previousIds
      ..clear()
      ..addAll(ids);
    return due;
  }

  String get statusLine {
    final parts = <String>[];
    if (water == HydroWaterState.full) parts.add('Mực nước đầy');
    if (water == HydroWaterState.low) parts.add('Mực nước thấp');
    if (phBad) {
      final phText = ph != null ? ' ${ph!.toStringAsFixed(2)}' : '';
      parts.add('pH$phText lệch');
    }
    if (parts.isEmpty) {
      if (!sawPh && !sawDist && !sawWater && !sawStatus) {
        return 'Đang chờ dữ liệu máy ${AppConfig.chipId}';
      }
      return 'Máy ${AppConfig.chipId} ổn định';
    }
    return 'Máy ${AppConfig.chipId}: ${parts.join(' · ')}';
  }

  static dynamic _unwrap(dynamic raw) {
    if (raw is Map && raw.containsKey('value')) return raw['value'];
    return raw;
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.'));
  }

  static HydroWaterState _parseWater(dynamic v) {
    final s = v.toString().trim().toUpperCase();
    if (s == 'LOW' || s == 'EMPTY' || s == 'THAP') return HydroWaterState.low;
    if (s == 'FULL' || s == 'DAY') return HydroWaterState.full;
    return HydroWaterState.ok;
  }

  static HydroWaterState _waterFromStatus(String s) {
    final u = s.toUpperCase();
    if (u.contains('NUOC THAP') || u.contains('BOM NGOAI')) {
      return HydroWaterState.low;
    }
    if (u.contains('NUOC DAY')) return HydroWaterState.full;
    return HydroWaterState.ok;
  }
}
