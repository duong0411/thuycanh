import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/auth_provider.dart';
import '../core/config.dart';
import '../core/hydro_provider.dart';
import 'theme.dart';
import 'widgets/feedback.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HydroProvider>();
    final auth = context.watch<AuthProvider>();
    final size = MediaQuery.sizeOf(context);
    final live = h.mqttConnected && h.hasTelemetry;
    final waterFrac = ((h.waterPct ?? 0) / 100).clamp(0.0, 1.0);
    final greet = auth.user?.name.isNotEmpty == true
        ? auth.user!.name.split(' ').last
        : null;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: HydroTheme.screenGradient(),
        child: Stack(
          children: [
            Positioned(
              top: -size.width * 0.3,
              right: -size.width * 0.2,
              child: _orb(size.width * 0.85, HydroTheme.leaf.withValues(alpha: 0.12))
                  .animate(onPlay: (a) => a.repeat(reverse: true))
                  .scale(
                    begin: const Offset(0.94, 0.94),
                    end: const Offset(1.06, 1.06),
                    duration: 9.seconds,
                  ),
            ),
            Positioned(
              bottom: size.height * 0.08,
              left: -70,
              child: _orb(220, HydroTheme.water.withValues(alpha: 0.1))
                  .animate(onPlay: (a) => a.repeat(reverse: true))
                  .fade(begin: 0.4, end: 0.85, duration: 7.seconds),
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
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _TopBar(
                              live: live,
                              chipId: AppConfig.chipId,
                              onChangeDevice: () async {
                                context.read<HydroProvider>().disconnectChip();
                                await context.read<AuthProvider>().clearBoundChip();
                                if (context.mounted) {
                                  showAppSnack(context, message: 'Nhập tên chip khác để kết nối lại');
                                }
                              },
                              onLogout: () async {
                                final hydro = context.read<HydroProvider>();
                                final a = context.read<AuthProvider>();
                                hydro.disconnectChip();
                                await a.clearBoundChip();
                                await a.logout();
                              },
                            ),
                            SizedBox(height: size.height * 0.028),
                            Text(
                              'THỦY CANH',
                              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                    fontSize: size.width > 390 ? 50 : 42,
                                  ),
                            )
                                .animate()
                                .fadeIn(duration: 480.ms)
                                .slideY(begin: 0.08, curve: Curves.easeOutCubic),
                            const SizedBox(height: 8),
                            Text(
                              greet != null
                                  ? 'Xin chào $greet — IoT STEM realtime'
                                  : 'Giám sát cây trồng IoT STEM realtime',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: HydroTheme.water.withValues(alpha: 0.95),
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ).animate().fadeIn(delay: 70.ms, duration: 400.ms),
                            const SizedBox(height: 14),
                            Text(
                              h.friendlyStatus,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 13.5,
                                    color: HydroTheme.soft.withValues(alpha: 0.7),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Neo thị giác: mực nước
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 26, 24, 8),
                        child: _WaterStage(
                          fraction: waterFrac,
                          pctText: h.waterPct == null ? '--' : '${h.waterPct!.toStringAsFixed(0)}%',
                          distText: h.distCm == null
                              ? 'Chờ cảm biến siêu âm'
                              : 'Cách mặt nước ${h.distCm!.toStringAsFixed(1)} cm',
                          alert: h.waterAlert,
                        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),
                      ),
                    ),

                    if (h.isWaterLow || h.isWaterFull)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                          child: _AlertStrip(h: h),
                        ),
                      ),

                    // Môi trường — hàng số liệu sạch, không lưới card dày
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Môi trường trồng',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nhiệt độ · Độ ẩm · pH · Ánh sáng',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            _MetricRow(
                              items: [
                                _Metric(
                                  label: 'Nhiệt độ',
                                  value: _n(h.temperature, 1),
                                  unit: '°C',
                                  icon: Icons.thermostat_rounded,
                                  accent: HydroTheme.sun,
                                ),
                                _Metric(
                                  label: 'Độ ẩm',
                                  value: _n(h.humidity, 0),
                                  unit: '%',
                                  icon: Icons.water_drop_outlined,
                                  accent: HydroTheme.water,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _MetricRow(
                              items: [
                                _Metric(
                                  label: 'pH',
                                  value: _n(h.ph, 2),
                                  unit: '',
                                  icon: Icons.science_outlined,
                                  accent: const Color(0xFF7DDEA8),
                                ),
                                _Metric(
                                  label: 'Ánh sáng',
                                  value: h.lightLabel,
                                  unit: h.lightLevel == null ? '' : (h.isDark ? '· 1' : '· 0'),
                                  icon: h.isDark
                                      ? Icons.nightlight_round
                                      : Icons.wb_sunny_rounded,
                                  accent: h.isDark ? const Color(0xFFA5B4FC) : HydroTheme.sun,
                                  emphasize: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Tự động
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tự động theo cảm biến',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Máy tự chỉnh — app chỉ theo dõi trạng thái.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                            ),
                            const SizedBox(height: 14),
                            _ActuatorTile(
                              title: 'Bơm tuần hoàn',
                              active: h.pumpOn,
                              color: HydroTheme.water,
                              icon: Icons.waves_rounded,
                              detail: h.isWaterLow
                                  ? 'Nước thấp — bơm tắt, hãy đổ nước'
                                  : h.isWaterFull
                                      ? 'Nước đầy — bơm đang tuần hoàn'
                                      : h.pumpOn
                                          ? 'Đang chạy theo mực nước'
                                          : 'Đang nghỉ',
                            ),
                            const SizedBox(height: 10),
                            _ActuatorTile(
                              title: 'Đèn trồng',
                              active: h.lampOn,
                              color: HydroTheme.sun,
                              icon: Icons.lightbulb_outline_rounded,
                              detail: h.lightLevel == null
                                  ? (h.lampOn ? 'Đèn đang bật' : 'Đèn đang tắt')
                                  : h.isDark
                                      ? 'Trời tối (1) — đèn bật'
                                      : 'Đủ sáng (0) — đèn tắt',
                            ),
                            const SizedBox(height: 18),
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
  const _TopBar({
    required this.live,
    required this.chipId,
    required this.onChangeDevice,
    required this.onLogout,
  });
  final bool live;
  final String chipId;
  final VoidCallback onChangeDevice;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: HydroTheme.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.eco_rounded, size: 15, color: HydroTheme.leaf.withValues(alpha: 0.95)),
              const SizedBox(width: 6),
              Text(
                'Chip $chipId',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 12,
                      color: HydroTheme.muted,
                      letterSpacing: 0.3,
                    ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: live ? HydroTheme.leaf : HydroTheme.sun,
            shape: BoxShape.circle,
            boxShadow: live
                ? [BoxShadow(color: HydroTheme.leaf.withValues(alpha: 0.55), blurRadius: 8)]
                : null,
          ),
        )
            .animate(onPlay: (a) => a.repeat(reverse: true))
            .fade(begin: 0.45, end: 1, duration: 1200.ms),
        const SizedBox(width: 6),
        Text(
          live ? 'Live' : 'Chờ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: HydroTheme.soft.withValues(alpha: 0.78),
              ),
        ),
        IconButton(
          tooltip: 'Đổi chip',
          visualDensity: VisualDensity.compact,
          onPressed: onChangeDevice,
          icon: const Icon(Icons.link_off_rounded, size: 20, color: HydroTheme.water),
        ),
        IconButton(
          tooltip: 'Đăng xuất',
          visualDensity: VisualDensity.compact,
          onPressed: onLogout,
          icon: Icon(Icons.logout_rounded, size: 20, color: HydroTheme.soft.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}

class _WaterStage extends StatelessWidget {
  const _WaterStage({
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
          children: [
            Text(
              'Mực nước',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              pctText,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 52,
                    color: accent,
                    height: 0.95,
                  ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  distText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Bể nước minh họa
        SizedBox(
          height: 88,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    color: Colors.white.withValues(alpha: 0.03),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: fraction <= 0 && pctText == '--' ? 0.08 : fraction.clamp(0.08, 1.0),
                  widthFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent.withValues(alpha: 0.35),
                          accent.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  )
                      .animate(onPlay: (a) => a.repeat(reverse: true))
                      .shimmer(duration: 3.seconds, color: Colors.white24),
                ),
              ),
            ],
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
                    color: HydroTheme.soft.withValues(alpha: 0.9),
                  ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms);
  }
}

class _Metric {
  const _Metric({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.accent,
    this.emphasize = false,
  });
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color accent;
  final bool emphasize;
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.items});
  final List<_Metric> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _MetricTile(m: items[i])),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.m});
  final _Metric m;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: HydroTheme.panel.withValues(alpha: 0.55),
        border: Border.all(
          color: m.emphasize
              ? m.accent.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(m.icon, color: m.accent, size: 20),
          const SizedBox(height: 14),
          Text(
            m.label,
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
                    fontSize: m.emphasize ? 22 : 22,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: HydroTheme.soft,
                  ),
              children: [
                TextSpan(text: m.value),
                if (m.unit.isNotEmpty)
                  TextSpan(
                    text: ' ${m.unit}',
                    style: TextStyle(
                      fontSize: 13,
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

class _ActuatorTile extends StatelessWidget {
  const _ActuatorTile({
    required this.title,
    required this.active,
    required this.color,
    required this.icon,
    required this.detail,
  });

  final String title;
  final bool active;
  final Color color;
  final IconData icon;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: HydroTheme.panel.withValues(alpha: 0.55),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: color.withValues(alpha: active ? 0.22 : 0.08),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15.5),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12.5,
                        color: HydroTheme.soft.withValues(alpha: 0.82),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: (active ? color : HydroTheme.muted).withValues(alpha: 0.18),
            ),
            child: Text(
              active ? 'ON' : 'OFF',
              style: TextStyle(
                color: active ? color : HydroTheme.muted,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
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
