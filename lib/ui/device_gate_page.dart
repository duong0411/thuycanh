import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/auth_provider.dart';
import '../core/config.dart';
import '../core/hydro_provider.dart';
import 'theme.dart';

/// Chặn vào hệ thống cho đến khi MQTT nhận đúng chipId cấu hình.
class DeviceGatePage extends StatelessWidget {
  const DeviceGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HydroProvider>();
    final auth = context.watch<AuthProvider>();

    String step;
    if (h.connecting) {
      step = 'Đang kết nối MQTT...';
    } else if (!h.mqttConnected) {
      step = 'Chưa kết nối MQTT — kéo xuống hoặc bấm Thử lại';
    } else if (!h.chipVerified || h.linkedChipId != AppConfig.chipId) {
      step = 'Đã MQTT — đang chờ chip ${AppConfig.chipId} phản hồi...';
    } else if (!h.online && !h.hasTelemetry) {
      step = 'Chip ${AppConfig.chipId} chưa online';
    } else {
      step = 'Đã xác thực chip ${AppConfig.chipId}';
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0C261A), HydroTheme.deep, Color(0xFF05140F)],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: HydroTheme.leaf,
            onRefresh: () => h.reconnect(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              children: [
                Row(
                  children: [
                    const Icon(Icons.eco_rounded, color: HydroTheme.leaf, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Xác thực thiết bị',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: HydroTheme.muted,
                            letterSpacing: 0.8,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Đăng xuất',
                      onPressed: () => auth.logout(),
                      icon: Icon(
                        Icons.logout_rounded,
                        color: HydroTheme.soft.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text(
                  'THỦY CANH',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 42),
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 10),
                Text(
                  'App chỉ vào hệ thống khi kết nối đúng chip ESP32.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: HydroTheme.water.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: HydroTheme.panel.withValues(alpha: 0.7),
                    border: Border.all(color: HydroTheme.leaf.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chip yêu cầu',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppConfig.chipId,
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontSize: 40,
                              color: HydroTheme.leaf,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _row('MQTT', h.mqttConnected ? 'Đã kết nối' : 'Chưa kết nối', h.mqttConnected),
                      const SizedBox(height: 8),
                      _row(
                        'Chip ID',
                        h.chipVerified && h.linkedChipId == AppConfig.chipId
                            ? 'Khớp ${h.linkedChipId}'
                            : 'Chưa xác thực',
                        h.chipVerified && h.linkedChipId == AppConfig.chipId,
                      ),
                      const SizedBox(height: 8),
                      _row(
                        'Thiết bị',
                        h.online
                            ? 'Online'
                            : h.hasTelemetry
                                ? 'Có dữ liệu'
                                : 'Đang chờ...',
                        h.online || h.hasTelemetry,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.06),
                const SizedBox(height: 22),
                Text(
                  step,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: HydroTheme.soft.withValues(alpha: 0.8),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bật ESP32 đã nạp firmware Thủy Canh (CHIP_ID = ${AppConfig.chipId}). '
                  'Chip khác (ví dụ 789) sẽ bị từ chối.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: h.connecting ? null : () => h.reconnect(),
                    style: FilledButton.styleFrom(
                      backgroundColor: HydroTheme.leaf,
                      foregroundColor: HydroTheme.deep,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: h.connecting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: HydroTheme.deep),
                          )
                        : const Text(
                            'Thử kết nối lại',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                  ),
                ),
                if (auth.user?.email != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Tài khoản: ${auth.user!.email}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, bool ok) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 18,
          color: ok ? HydroTheme.leaf : HydroTheme.muted,
        ),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: HydroTheme.muted, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: ok ? HydroTheme.soft : HydroTheme.sun,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
