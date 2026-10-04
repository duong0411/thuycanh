import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/hydro_provider.dart';
import 'theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HydroProvider>();
    final size = MediaQuery.sizeOf(context);
    final live = h.mqttConnected && h.hasTelemetry;
    final waterFrac = ((h.waterPct ?? 0) / 100).clamp(0.0, 1.0);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0C261A),
              HydroTheme.deep,
              Color(0xFF05140F),
              Color(0xFF0A1F28),
            ],
            stops: [0, 0.35, 0.75, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -size.width * 0.35,
              right: -size.width * 0.25,
              child: _orb(size.width * 0.9, HydroTheme.leaf.withValues(alpha: 0.14))
                  .animate(onPlay: (a) => a.repeat(reverse: true))
                  .scale(
                    begin: const Offset(0.92, 0.92),
                    end: const Offset(1.08, 1.08),
                    duration: 8.seconds,
                  ),
            ),
            Positioned(
              bottom: size.height * 0.12,
              left: -80,
              child: _orb(240, HydroTheme.water.withValues(alpha: 0.1))
                  .animate(onPlay: (a) => a.repeat(reverse: true))
                  .fade(begin: 0.35, end: 0.9, duration: 6.seconds),
            ),
            Positioned(
              top: size.height * 0.42,
              right: -40,
              child: _orb(140, HydroTheme.sun.withValues(alpha: 0.06)),
            ),
            SafeArea(
              child: RefreshIndicator(
                color: HydroTheme.leaf,
                backgroundColor: HydroTheme.panel,
                onRefresh: h.reconnect,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    // ── Hero: brand + một câu + trạng thái ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _TopBar(live: live, mqttOk: h.mqttConnected),
                            SizedBox(height: size.height * 0.045),
                            Text(
                              'THỦY CANH',
                              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                    fontSize: size.width > 390 ? 52 : 44,
                                  ),
                            )
                                .animate()
                                .fadeIn(duration: 500.ms)
                                .slideY(begin: 0.1, curve: Curves.easeOutCubic),
                            const SizedBox(height: 10),
                            Text(
                              'Nuôi cây sạch — theo dõi dinh dưỡng realtime',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: HydroTheme.water.withValues(alpha: 0.92),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ).animate().fadeIn(delay: 80.ms, duration: 400.ms),
                            const SizedBox(height: 18),
                            _HeroStatus(h: h, live: live),
                          ],
                        ),
                      ),
                    ),

                    // ── Visual mực nước (neo thị giác) ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                        child: _WaterHero(
                          fraction: waterFrac,
                          pctText: h.waterPct == null ? '--' : '${h.waterPct!.toStringAsFixed(0)}%',
                          distText: h.distCm == null
                              ? 'Chờ cảm biến siêu âm'
                              : 'Cách mặt nước ${h.distCm!.toStringAsFixed(1)} cm',
                          alert: h.waterAlert,
                        ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.06),
                      ),
                    ),

                    if (h.isWaterLow || h.isWaterFull)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                          child: _AlertStrip(h: h),
                        ),
                      ),

                    // ── Cảm biến môi trường ──
                    // Cards chỉ dùng khi cần nhóm số liệu đọc nhanh — không ở hero
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Môi trường trồng',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Các chỉ số từ ESP32 cập nhật qua MQTT',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.28,
                        ),
                        delegate: SliverChildListDelegate([
                          _MetricCell(
                            label: 'Nhiệt độ',
                            value: _n(h.temperature, 1),
                            unit: '°C',
                            icon: Icons.thermostat_rounded,
                            accent: HydroTheme.sun,
                          ),
                          _MetricCell(
                            label: 'Độ ẩm',
                            value: _n(h.humidity, 0),
                            unit: '%',
                            icon: Icons.water_drop_outlined,
                            accent: HydroTheme.water,
                          ),
                          _MetricCell(
                            label: 'pH dinh dưỡng',
                            value: _n(h.ph, 2),
                            unit: '',
                            icon: Icons.science_outlined,
                            accent: const Color(0xFF86EFAC),
                          ),
                          _MetricCell(
                            label: 'TDS',
                            value: _n(h.tds, 0),
                            unit: 'ppm',
                            icon: Icons.bubble_chart_outlined,
                            accent: HydroTheme.leaf,
                          ),
                          _MetricCell(
                            label: 'Ánh sáng',
                            value: _n(h.lightPct, 0),
                            unit: '%',
                            icon: Icons.wb_sunny_outlined,
                            accent: HydroTheme.sun,
                          ),
                          _MetricCell(
                            label: 'Bơm / Đèn',
                            value: '${h.pumpOn ? 'ON' : 'OFF'} · ${h.lampOn ? 'ON' : 'OFF'}',
                            unit: '',
                            icon: Icons.tune_rounded,
                            accent: HydroTheme.water,
                            compactValue: true,
                          ),
                        ]),
                      ),
                    ),

                    // ── Điều khiển (tương tác → dùng tile) ──
                    // Cards allowed for switches
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Điều khiển',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Giữ lâu Bơm hoặc Đèn để về chế độ AUTO',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                            ),
                            const SizedBox(height: 14),
                            _ControlTile(
                              title: 'Hệ thống',
                              subtitle: h.powerOn ? 'Đang vận hành' : 'Đã tạm dừng',
                              value: h.powerOn,
                              color: HydroTheme.leaf,
                              icon: Icons.power_settings_new_rounded,
                              onChanged: (_) => h.togglePower(),
                            ),
                            const SizedBox(height: 10),
                            _ControlTile(
                              title: 'Bơm tuần hoàn',
                              subtitle: h.isWaterLow
                                  ? 'Bảo vệ khô — hãy đổ nước ngoài'
                                  : h.pumpOn
                                      ? 'Đang chạy theo mực nước'
                                      : 'Đang nghỉ',
                              value: h.pumpOn,
                              color: HydroTheme.water,
                              icon: Icons.waves_rounded,
                              onChanged: (_) => h.togglePump(),
                              onLongPress: h.setPumpAuto,
                            ),
                            const SizedBox(height: 10),
                            _ControlTile(
                              title: 'Đèn trồng',
                              subtitle: h.lampOn
                                  ? 'Đang sáng (AUTO theo LDR khi không ép tay)'
                                  : 'Đang tắt — chờ trời tối',
                              value: h.lampOn,
                              color: HydroTheme.sun,
                              icon: Icons.lightbulb_outline_rounded,
                              onChanged: (_) => h.toggleLamp(),
                              onLongPress: h.setLampAuto,
                            ),
                            const SizedBox(height: 20),
                            _FooterStatus(h: h, live: live),
                          ],
                        ),
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

  String _n(double? v, int d) {
    if (v == null) return '--';
    return v.toStringAsFixed(d);
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.live, required this.mqttOk});
  final bool live;
  final bool mqttOk;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.eco_rounded,
          size: 18,
          color: HydroTheme.leaf.withValues(alpha: 0.9),
        ),
        const SizedBox(width: 8),
        Text(
          'STEM IoT',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 12,
                letterSpacing: 1.2,
                color: HydroTheme.muted,
              ),
        ),
        const Spacer(),
        Icon(
          mqttOk ? Icons.wifi_rounded : Icons.wifi_off_rounded,
          size: 16,
          color: mqttOk ? HydroTheme.leaf : HydroTheme.muted.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 6),
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: live ? HydroTheme.leaf : HydroTheme.sun,
            shape: BoxShape.circle,
            boxShadow: live
                ? [BoxShadow(color: HydroTheme.leaf.withValues(alpha: 0.5), blurRadius: 8)]
                : null,
          ),
        )
            .animate(onPlay: (a) => a.repeat(reverse: true))
            .fade(begin: 0.45, end: 1, duration: 1200.ms),
        const SizedBox(width: 6),
        Text(
          live ? 'Live' : 'Kết nối',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: HydroTheme.soft.withValues(alpha: 0.75),
              ),
        ),
      ],
    );
  }
}

class _HeroStatus extends StatelessWidget {
  const _HeroStatus({required this.h, required this.live});
  final HydroProvider h;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Text(
      h.friendlyStatus,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: HydroTheme.soft.withValues(alpha: 0.72),
          ),
    );
  }
}

class _WaterHero extends StatelessWidget {
  const _WaterHero({
    required this.fraction,
    required this.pctText,
    required this.distText,
    required this.alert,
  });

  final double fraction;
  final String pctText;
  final String distText;
  final WaterAlertLevel alert;

  @override
  Widget build(BuildContext context) {
    final Color accent;
    final String tag;
    switch (alert) {
      case WaterAlertLevel.low:
        accent = HydroTheme.warn;
        tag = 'THẤP';
      case WaterAlertLevel.full:
        accent = HydroTheme.water;
        tag = 'ĐẦY';
      case WaterAlertLevel.ok:
        accent = HydroTheme.leaf;
        tag = 'ỔN';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Mực nước',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              pctText,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 48,
                    color: accent,
                    height: 1,
                  ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                distText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 12,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Colors.white.withValues(alpha: 0.06)),
                FractionallySizedBox(
                  widthFactor: fraction <= 0 && pctText == '--' ? 0 : fraction.clamp(0.02, 1.0),
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0.7),
                          accent,
                        ],
                      ),
                    ),
                  ),
                )
                    .animate(onPlay: (a) => a.repeat(reverse: true))
                    .shimmer(duration: 2.8.seconds, color: Colors.white24),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Hết · 18cm', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11)),
            const Spacer(),
            Text('Đầy · 11cm', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

class _AlertStrip extends StatelessWidget {
  const _AlertStrip({required this.h});
  final HydroProvider h;

  @override
  Widget build(BuildContext context) {
    final color = h.isWaterLow ? HydroTheme.warn : HydroTheme.water;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            h.isWaterLow ? Icons.warning_amber_rounded : Icons.water_drop_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              h.waterAlertBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: HydroTheme.soft.withValues(alpha: 0.88),
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.accent,
    this.compactValue = false,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color accent;
  final bool compactValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: HydroTheme.panel.withValues(alpha: 0.55),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 20),
          const Spacer(),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: HydroTheme.muted,
                ),
          ),
          const SizedBox(height: 2),
          RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: compactValue ? 15 : 24,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: HydroTheme.soft,
                  ),
              children: [
                TextSpan(text: value),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: compactValue ? 12 : 14,
                      fontWeight: FontWeight.w600,
                      color: HydroTheme.muted,
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
    required this.icon,
    required this.onChanged,
    this.onLongPress,
  });

  final String title;
  final String subtitle;
  final bool value;
  final Color color;
  final IconData icon;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onLongPress: onLongPress,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: value ? 0.16 : 0.05),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
            border: Border.all(
              color: value ? color.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
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
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
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

class _FooterStatus extends StatelessWidget {
  const _FooterStatus({required this.h, required this.live});
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
      color = HydroTheme.warn;
      text = 'Cảnh báo: mực nước thấp';
    } else if (h.isWaterFull) {
      color = HydroTheme.water;
      text = 'Mực nước đầy — bơm đang chạy';
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
        borderRadius: BorderRadius.circular(18),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.32)),
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
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 14,
                    color: HydroTheme.soft.withValues(alpha: 0.95),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
