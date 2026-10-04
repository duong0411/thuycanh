import 'package:flutter_test/flutter_test.dart';
import 'package:thuycanh_app/core/config.dart';
import 'package:thuycanh_app/core/hydro_provider.dart';

void main() {
  test('MQTT chipId and water thresholds for STEM hydro', () {
    AppConfig.setChipId('790');
    expect(AppConfig.chipId, '790');
    expect(AppConfig.distFullCm, 11);
    expect(AppConfig.distEmptyCm, 18);
    expect(AppConfig.subscribeTopics, contains(AppConfig.topicWaterAlert));
    expect(AppConfig.topicOnline, 'tele/790/status');
    expect(AppConfig.deviceName.toLowerCase(), contains('thủy canh'));
  });

  test('AppConfig topics follow selected chipId', () {
    AppConfig.setChipId('790');
    expect(AppConfig.topicTemp, 'tele/790_temp/status');
    AppConfig.setChipId('791');
    expect(AppConfig.topicTemp, 'tele/791_temp/status');
    AppConfig.setChipId(AppConfig.defaultChipId);
  });

  test('HydroProvider blocks dashboard until chip connected', () {
    final h = HydroProvider();
    expect(h.canEnterSystem, isFalse);
    expect(h.chipBound, isFalse);
    h.dispose();
  });
}
