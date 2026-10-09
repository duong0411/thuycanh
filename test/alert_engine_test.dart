import 'package:flutter_test/flutter_test.dart';
import 'package:thuycanh_app/core/alert_engine.dart';
import 'package:thuycanh_app/core/config.dart';

void main() {
  setUp(() => AppConfig.setChipId('790'));

  test('mực nước đầy và pH lệch tạo đúng cảnh báo', () {
    final engine = AlertEngine()..pendingReconnect = false;
    expect(engine.ingest('tele/790_water_alert/status', 'FULL'), isTrue);
    expect(engine.ingest('tele/790_dist/status', 9.4), isTrue);
    expect(engine.ingest('tele/790_ph/status', 7.2), isTrue);

    final due = engine.consume(reconnect: true);
    expect(due.map((a) => a.id), ['water_full', 'ph']);
    expect(due.first.body, contains('9.4 cm'));
    expect(due.last.body, contains('7.20'));

    expect(engine.consume(reconnect: false), isEmpty);
  });

  test('pH trong 5.5–6.5 không báo, ra ngoài thì báo một lần', () {
    final engine = AlertEngine()..pendingReconnect = false;
    engine.ingest('tele/790_ph/status', 6.0);
    expect(engine.consume(reconnect: false), isEmpty);

    engine.ingest('tele/790_ph/status', 5.49);
    final low = engine.consume(reconnect: false);
    expect(low.map((a) => a.id), ['ph']);

    engine.ingest('tele/790_ph/status', 6.51);
    expect(engine.consume(reconnect: false).map((a) => a.id), isEmpty);
  });

  test('mất mạng rồi có lại thì báo lại cảnh báo đang tồn tại', () {
    final engine = AlertEngine()..pendingReconnect = false;
    engine.ingest('tele/790_dist/status', 19);
    expect(engine.consume(reconnect: false).single.id, 'water_low');

    engine.pendingReconnect = true;
    final again = engine.consume(reconnect: engine.pendingReconnect);
    expect(again.single.id, 'water_low');
  });

  test('bỏ qua topic máy khác và ưu tiên topic mực nước hơn khoảng cách', () {
    final engine = AlertEngine()..pendingReconnect = false;
    expect(engine.ingest('tele/789_water_alert/status', 'FULL'), isFalse);
    engine.ingest('tele/790_dist/status', 8);
    engine.ingest('tele/790_water_alert/status', 'OK');
    expect(engine.consume(reconnect: true), isEmpty);
  });

  test('status NUOC DAY vẫn thành cảnh báo đầy khi chưa có topic alert', () {
    final engine = AlertEngine();
    engine.ingest('tele/790_status/status', 'CANH BAO: NUOC DAY');
    expect(engine.consume(reconnect: true).single.id, 'water_full');
  });
}
