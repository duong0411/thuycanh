import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/hydro_provider.dart';
import 'theme.dart';

/// Giao diện theo mockup STEM: danh sách realtime + thanh trạng thái
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HydroProvider>();
    final size = MediaQuery.sizeOf(context);
    final live = h.mqttConnected && h.hasTelemetry;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A2418), HydroTheme.deep, Color(0xFF06140E)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -size.width * 0.28,
              right: -size.width * 0.18,
              child: _orb(size.width * 0.75, HydroTheme.leaf.withValues(alpha: 0.16))
                  .animate(onPlay: (a) => a.repeat(reverse: true))
                  .scale(
                    begin: const Offset(0.95, 0.95),
                    end: const Offset(1.06, 1.06),
                    duration: 6.seconds,
                  ),
            ),
            Positioned(
              bottom: 40,
              left: -50,
              child: _orb(200, HydroTheme.water.withValues(alpha: 0.09))
                  .animate(onPlay: (a) => a.repeat(reverse: true))
                  .fade(begin: 0.4, end: 1, duration: 5.seconds),
            ),
            SafeArea(
              child: RefreshIndicator(
                color: HydroTheme.leaf,
                onRefresh: h.reconnect,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.wifi_rounded,
                          size: 18,
                          color: h.mqttConnected
                              ? HydroTheme.leaf
                              : HydroTheme.soft.withValues(alpha: 0.35),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          live ? 'MQTT realtime' : 'Đang kết nối MQTT...',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                                color: HydroTheme.soft.withValues(alpha: 0.7),
                              ),
                        ),
                        const Spacer(),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: live ? HydroTheme.leaf : HydroTheme.sun,
                            shape: BoxShape.circle,
                          ),
                        )
                            .animate(onPlay: (a) => a.repeat(reverse: true))
                            .fade(begin: 0.4, end: 1, duration: 1100.ms),
                      ],
                    ),
                    SizedBox(height: size.height * 0.03),
                    Text(
                      'Thủy canh IoT',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontSize: size.width > 400 ? 42 : 36,
                            height: 1.0,
                            letterSpacing: -1.2,
                          ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),
                    const SizedBox(height: 8),
                    Text(
                      'Theo dõi hệ thống thủy canh STEM qua MQTT',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: HydroTheme.water.withValues(alpha: 0.88),
                            fontSize: 15,
                          ),
                    ),
                    const SizedBox(height: 20),
                    if (h.isWaterLow || h.isWaterFull) ...[
                      _WaterAlertCard(h: h),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      'Thông số realtime',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 10),
                    _SensorTile(
                      icon: Icons.thermostat_rounded,
                      label: 'Nhiệt độ',
                      value: _fmt(h.temperature, '°C'),
                      color: HydroTheme.sun,
                    ),
                    _SensorTile(
                      icon: Icons.water_drop_rounded,
                      label: 'Độ ẩm',
                      value: _fmt(h.humidity, '%', d: 0),
                      color: HydroTheme.water,
                    ),
                    _SensorTile(
                      icon: Icons.science_rounded,
                      label: 'pH',
                      value: _fmt(h.ph, '', d: 2),
                      color: const Color(0xFF86EFAC),
                    ),
                    _SensorTile(
                      icon: Icons.bubble_chart_rounded,
                      label: 'TDS',
                      value: _fmt(h.tds, 'ppm', d: 0),
                      color: HydroTheme.leaf,
                    ),
                    _SensorTile(
                      icon: Icons.waves_rounded,
                      label: 'Mực nước',
                      value: _waterValue(h),
                      color: h.isWaterLow
                          ? const Color(0xFFF97316)
                          : h.isWaterFull
                              ? HydroTheme.leaf
                              : HydroTheme.water,
                      subtitle: h.distCm != null
                          ? 'Khoảng cách ${h.distCm!.toStringAsFixed(1)} cm'
                          : null,
                    ),
                    _SensorTile(
                      icon: Icons.wb_sunny_rounded,
                      label: 'Ánh sáng',
                      value: _fmt(h.lightPct, '%', d: 0),
                      color: HydroTheme.sun,
                    ),
                    _SensorTile(
                      icon: Icons.water_rounded,
                      label: 'Bơm tuần hoàn',
                      value: h.pumpOn ? 'ON' : 'OFF',
                      color: h.pumpOn ? HydroTheme.leaf : HydroTheme.soft,
                    ),
                    _SensorTile(
                      icon: Icons.lightbulb_rounded,
                      label: 'Đèn trồng',
                      value: h.lampOn ? 'ON' : 'OFF',
                      color: h.lampOn ? HydroTheme.sun : HydroTheme.soft,
                    ),
                    const SizedBox(height: 16),
                    _SystemStatusBar(h: h, live: live),
                    const SizedBox(height: 22),
                    Text(
                      'Điều khiển',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 10),
                    _ControlTile(
                      title: 'Hệ thống',
                      subtitle: h.powerOn ? 'Đang bật' : 'Đã tắt',
                      value: h.powerOn,
                      color: HydroTheme.leaf,
                      onChanged: (_) => h.togglePower(),
                    ),
                    const SizedBox(height: 10),
                    _ControlTile(
                      title: 'Bơm tuần hoàn',
                      subtitle: h.isWaterLow
                          ? 'Tắt bảo vệ — cần đổ nước ngoài'
                          : h.pumpOn
                              ? 'Đang chạy (AUTO theo mực nước)'
                              : 'Bơm đang nghỉ',
                      value: h.pumpOn,
                      color: HydroTheme.water,
                      onChanged: (_) => h.togglePump(),
                      onLongPress: h.setPumpAuto,
                    ),
                    const SizedBox(height: 10),
                    _ControlTile(
                      title: 'Đèn trồng',
                      subtitle: h.lampOn ? 'Đèn đang sáng' : 'Đèn đang tắt',
                      value: h.lampOn,
                      color: HydroTheme.sun,
                      onChanged: (_) => h.toggleLamp(),
                      onLongPress: h.setLampAuto,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Giữ nút Bơm / Đèn để trả về AUTO trên ESP32',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            color: HydroTheme.soft.withValues(alpha: 0.45),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double? v, String unit, {int d = 1}) {
    if (v == null) return '--';
    final n = v.toStringAsFixed(d);
    return unit.isEmpty ? n : '$n $unit';
  }

  String _waterValue(HydroProvider h) {
    if (h.waterPct == null) return '--';
    final pct = '${h.waterPct!.toStringAsFixed(0)} %';
    if (h.isWaterFull) return '$pct · ĐẦY';
    if (h.isWaterLow) return '$pct · THẤP';
    return pct;
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _SensorTile extends StatelessWidget {
  const _SensorTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: HydroTheme.panel.withValues(alpha: 0.55),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: HydroTheme.soft.withValues(alpha: 0.62),
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 11,
                            color: HydroTheme.soft.withValues(alpha: 0.45),
                          ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 280.ms).slideX(begin: 0.04);
  }
}

class _SystemStatusBar extends StatelessWidget {
  const _SystemStatusBar({required this.h, required this.live});
  final HydroProvider h;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String text;
    if (!h.mqttConnected) {
      color = HydroTheme.sun;
      text = 'Đang kết nối máy thủy canh...';
    } else if (h.isWaterLow) {
      color = const Color(0xFFF97316);
      text = 'Cảnh báo: mực nước thấp — bơm nước từ ngoài vào';
    } else if (h.isWaterFull) {
      color = HydroTheme.water;
      text = 'Mực nước đầy — bơm tuần hoàn đang chạy';
    } else if (live && h.powerOn) {
      color = HydroTheme.leaf;
      text = 'Hệ thống hoạt động tốt';
    } else {
      color = HydroTheme.sun;
      text = h.friendlyStatus;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            live && !h.isWaterLow ? Icons.check_circle_rounded : Icons.info_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: HydroTheme.soft.withValues(alpha: 0.95),
                  ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 80.ms);
  }
}

class _WaterAlertCard extends StatelessWidget {
  const _WaterAlertCard({required this.h});
  final HydroProvider h;

  @override
  Widget build(BuildContext context) {
    final color = h.isWaterLow ? const Color(0xFFF97316) : HydroTheme.water;
    final icon = h.isWaterLow ? Icons.warning_amber_rounded : Icons.water_drop_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h.waterAlertTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 16,
                        color: color,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  h.waterAlertBody,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        height: 1.35,
                        color: HydroTheme.soft.withValues(alpha: 0.82),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlTile extends StatelessWidget {
  const _ControlTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.onChanged,
    this.onLongPress,
  });

  final String title;
  final String subtitle;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onLongPress: onLongPress,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  value ? Icons.power_rounded : Icons.power_off_rounded,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            color: HydroTheme.soft.withValues(alpha: 0.55),
                          ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                activeThumbColor: HydroTheme.deep,
                activeTrackColor: color,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
