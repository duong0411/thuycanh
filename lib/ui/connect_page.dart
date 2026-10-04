import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/auth_provider.dart';
import '../core/config.dart';
import '../core/hydro_provider.dart';
import 'theme.dart';
import 'widgets/feedback.dart';

/// Nhập tên chip → kết nối thiết bị → vào màn theo dõi thủy canh.
class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  late final TextEditingController _chip;
  bool _bannerShown = false;
  String? _successStatus;

  @override
  void initState() {
    super.initState();
    _chip = TextEditingController(text: AppConfig.chipId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPendingBanner());
  }

  void _showPendingBanner() {
    if (!mounted || _bannerShown) return;
    final msg = context.read<AuthProvider>().consumeSuccessBanner();
    if (msg != null) {
      _bannerShown = true;
      setState(() => _successStatus = msg);
    }
  }

  @override
  void dispose() {
    _chip.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final id = _chip.text.trim();
    if (id.isEmpty) {
      showAppSnack(context, message: 'Vui lòng nhập tên chip của máy');
      return;
    }

    final auth = context.read<AuthProvider>();
    final hydro = context.read<HydroProvider>();

    await auth.bindChip(id);
    final ok = await hydro.connectWithChip(id);
    if (!mounted) return;

    if (!ok) {
      showAppSnack(context, message: 'Chưa kết nối được — kiểm tra mạng rồi thử lại');
      return;
    }

    showAppSnack(context, message: 'Đang tìm máy $id...', success: true);
  }

  String _friendlyHint(HydroProvider h, String chip) {
    if (h.connecting) return 'Đang kết nối với máy của bạn...';
    if (!h.chipBound) return 'Nhập tên chip rồi bấm Tiếp tục để xem cảm biến.';
    if (!h.mqttConnected) return 'Chưa kết nối được — hãy thử lại.';
    if (!h.chipVerified || h.linkedChipId != AppConfig.chipId) {
      return 'Đang chờ máy $chip phản hồi...';
    }
    if (!h.online && !h.hasTelemetry) return 'Máy $chip chưa sẵn sàng — hãy bật thiết bị.';
    return 'Đã tìm thấy máy — đang mở bảng theo dõi...';
  }

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HydroProvider>();
    final auth = context.watch<AuthProvider>();
    final chip = _chip.text.trim().isEmpty ? AppConfig.defaultChipId : _chip.text.trim();
    final waiting = h.chipBound && !h.canEnterSystem;

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
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -50,
              child: _orb(220, HydroTheme.leaf.withValues(alpha: 0.14))
                  .animate(onPlay: (a) => a.repeat(reverse: true))
                  .scale(
                    begin: const Offset(0.96, 0.96),
                    end: const Offset(1.06, 1.06),
                    duration: 5.seconds,
                  ),
            ),
            Positioned(
              bottom: 100,
              left: -50,
              child: _orb(180, HydroTheme.water.withValues(alpha: 0.1)),
            ),
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
                children: [
                  Row(
                    children: [
                      Text(
                        'Chọn máy',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 16,
                              color: HydroTheme.soft.withValues(alpha: 0.85),
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Đăng xuất',
                        onPressed: () async {
                          context.read<HydroProvider>().disconnectChip();
                          await auth.clearBoundChip();
                          await auth.logout();
                        },
                        icon: Icon(
                          Icons.logout_rounded,
                          color: HydroTheme.soft.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'THỦY CANH',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 44,
                          height: 0.95,
                          letterSpacing: -1.2,
                        ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),
                  const SizedBox(height: 10),
                  Text(
                    'Nhập tên chip trên máy để theo dõi dinh dưỡng và mực nước.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: HydroTheme.water.withValues(alpha: 0.92),
                          height: 1.45,
                          fontSize: 16,
                        ),
                  ),
                  const SizedBox(height: 24),
                  if (_successStatus != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: HydroTheme.leaf.withValues(alpha: 0.14),
                        border: Border.all(color: HydroTheme.leaf.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: HydroTheme.leaf, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _successStatus!,
                              style: const TextStyle(
                                color: HydroTheme.soft,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 350.ms),
                  ],
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: HydroTheme.panel.withValues(alpha: 0.7),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tên chip',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Dùng đúng mã gắn trên máy ESP32 thủy canh.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: HydroTheme.muted,
                                fontSize: 13,
                              ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _chip,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            if (!h.connecting) _connect();
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z_\-]')),
                          ],
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                fontSize: 32,
                                color: HydroTheme.leaf,
                                letterSpacing: 2,
                              ),
                          decoration: InputDecoration(
                            hintText: 'Ví dụ ${AppConfig.defaultChipId}',
                            hintStyle: TextStyle(
                              color: HydroTheme.leaf.withValues(alpha: 0.28),
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.memory_rounded, color: HydroTheme.water, size: 28),
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(color: HydroTheme.leaf, width: 1.5),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          children: [
                            _ChipSuggestion(
                              label: AppConfig.defaultChipId,
                              selected: _chip.text.trim() == AppConfig.defaultChipId,
                              onTap: () => setState(() => _chip.text = AppConfig.defaultChipId),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.05),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _friendlyHint(h, chip),
                      key: ValueKey(_friendlyHint(h, chip)),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            color: HydroTheme.soft.withValues(alpha: 0.78),
                            height: 1.4,
                          ),
                    ),
                  ),
                  if (waiting) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(
                      color: HydroTheme.leaf,
                      backgroundColor: Color(0x334ADE80),
                      minHeight: 3,
                      borderRadius: BorderRadius.all(Radius.circular(99)),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: h.connecting ? null : _connect,
                      style: FilledButton.styleFrom(
                        backgroundColor: HydroTheme.leaf,
                        foregroundColor: HydroTheme.deep,
                        disabledBackgroundColor: HydroTheme.leaf.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: h.connecting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: HydroTheme.deep,
                              ),
                            )
                          : Text(
                              waiting ? 'Thử lại' : 'Tiếp tục',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                    ),
                  ),
                  if (auth.user?.email != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      auth.user!.email,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            color: HydroTheme.soft.withValues(alpha: 0.45),
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

class _ChipSuggestion extends StatelessWidget {
  const _ChipSuggestion({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? HydroTheme.leaf.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: selected
                  ? HydroTheme.leaf.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_rounded : Icons.eco_rounded,
                size: 16,
                color: selected ? HydroTheme.leaf : HydroTheme.muted,
              ),
              const SizedBox(width: 8),
              Text(
                'Máy $label',
                style: TextStyle(
                  color: selected ? HydroTheme.soft : HydroTheme.soft.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
