import 'package:flutter_test/flutter_test.dart';
import 'package:thuycanh_app/core/config.dart';

void main() {
  test('MQTT chipId and water thresholds for STEM hydro', () {
    expect(AppConfig.chipId, '790');
    expect(AppConfig.distFullCm, 11);
    expect(AppConfig.distEmptyCm, 18);
    expect(AppConfig.subscribeTopics, contains(AppConfig.topicWaterAlert));
    expect(AppConfig.deviceName.toLowerCase(), contains('thủy canh'));
  });
}
