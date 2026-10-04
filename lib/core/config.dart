/// Cấu hình MQTT + API AloT — mặc định chipId 790 (KHÔNG trùng 789 máy Ngưng Tụ)
class AppConfig {
  static const String apiBaseUrl = 'https://duynguyen.io.vn/api';
  static const String brokerUrl = 'wss://mqtt.duynguyen.io.vn/mqtt';
  static const String defaultChipId = '790';
  static const String deviceName = 'Thủy Canh IoT STEM';

  /// Chip đang gắn — người dùng nhập ở màn Connect.
  static String chipId = defaultChipId;

  static void setChipId(String id) {
    final cleaned = id.trim();
    chipId = cleaned.isEmpty ? defaultChipId : cleaned;
  }

  static String get topicOnline => 'tele/$chipId/status';
  static String get topicTemp => 'tele/${chipId}_temp/status';
  static String get topicHumi => 'tele/${chipId}_humi/status';
  static String get topicPh => 'tele/${chipId}_ph/status';
  static String get topicTds => 'tele/${chipId}_tds/status';
  static String get topicWater => 'tele/${chipId}_water/status';
  static String get topicDist => 'tele/${chipId}_dist/status';
  static String get topicWaterAlert => 'tele/${chipId}_water_alert/status';
  static String get topicLight => 'tele/${chipId}_light/status';
  static String get topicPump => 'tele/${chipId}_pump/status';
  static String get topicLamp => 'tele/${chipId}_lamp/status';
  static String get topicStatus => 'tele/${chipId}_status/status';
  static String get topicPower => 'tele/${chipId}_power/status';

  static String get cmndPower => 'cmnd/${chipId}_power/POWER';
  static String get cmndPump => 'cmnd/${chipId}_pump/POWER';
  static String get cmndLamp => 'cmnd/${chipId}_lamp/POWER';

  /// Ngưỡng khoảng cách khớp firmware (cm tới mặt nước)
  static const double distFullCm = 11;
  static const double distEmptyCm = 18;

  static List<String> get subscribeTopics => [
        topicOnline,
        topicTemp,
        topicHumi,
        topicPh,
        topicTds,
        topicWater,
        topicDist,
        topicWaterAlert,
        topicLight,
        topicPump,
        topicLamp,
        topicStatus,
        topicPower,
      ];
}
