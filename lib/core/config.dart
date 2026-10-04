/// Cấu hình MQTT + API AloT — chipId 790 (KHÔNG trùng 789 máy Ngưng Tụ)
class AppConfig {
  static const String apiBaseUrl = 'https://duynguyen.io.vn/api';
  static const String brokerUrl = 'wss://mqtt.duynguyen.io.vn/mqtt';
  static const String chipId = '790';
  static const String deviceName = 'Thủy Canh IoT STEM';


  static const String topicOnline = 'tele/$chipId/status';
  static const String topicTemp = 'tele/${chipId}_temp/status';
  static const String topicHumi = 'tele/${chipId}_humi/status';
  static const String topicPh = 'tele/${chipId}_ph/status';
  static const String topicTds = 'tele/${chipId}_tds/status';
  static const String topicWater = 'tele/${chipId}_water/status';
  static const String topicDist = 'tele/${chipId}_dist/status';
  static const String topicWaterAlert = 'tele/${chipId}_water_alert/status';
  static const String topicLight = 'tele/${chipId}_light/status';
  static const String topicPump = 'tele/${chipId}_pump/status';
  static const String topicLamp = 'tele/${chipId}_lamp/status';
  static const String topicStatus = 'tele/${chipId}_status/status';
  static const String topicPower = 'tele/${chipId}_power/status';

  static const String cmndPower = 'cmnd/${chipId}_power/POWER';
  static const String cmndPump = 'cmnd/${chipId}_pump/POWER';
  static const String cmndLamp = 'cmnd/${chipId}_lamp/POWER';

  /// Ngưỡng khoảng cách khớp firmware (cm tới mặt nước)
  static const double distFullCm = 11;
  static const double distEmptyCm = 18;

  static const List<String> subscribeTopics = [
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
