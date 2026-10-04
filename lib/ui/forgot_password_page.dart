import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/auth_provider.dart';
import 'theme.dart';
import 'widgets/feedback.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _done = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    final confirm = _confirm.text;

    if (email.isEmpty || pass.isEmpty || confirm.isEmpty) {
      showAppSnack(context, message: 'Vui lòng điền đủ email và mật khẩu mới');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      showAppSnack(context, message: 'Email chưa đúng định dạng');
      return;
    }
    if (pass.length < 6) {
      showAppSnack(context, message: 'Mật khẩu mới cần ít nhất 6 ký tự');
      return;
    }
    if (pass != confirm) {
      showAppSnack(context, message: 'Mật khẩu xác nhận chưa khớp');
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.resetPassword(email, pass);
    if (!mounted) return;
    if (ok) {
      setState(() => _done = true);
      showAppSnack(context, message: 'Đặt lại mật khẩu thành công', success: true);
      await showSuccessDialog(
        context,
        title: 'Đặt lại mật khẩu thành công',
        message: 'Bạn có thể đăng nhập bằng mật khẩu mới.',
      );
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } else {
      showAppSnack(context, message: auth.error ?? 'Không đặt lại được mật khẩu');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0C261A), HydroTheme.deep, Color(0xFF05140F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: HydroTheme.soft),
                    ),
                    Text('Quên mật khẩu', style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
                  children: [
                    Text(
                      'Đặt mật khẩu mới',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28),
                    ).animate().fadeIn(duration: 350.ms),
                    const SizedBox(height: 8),
                    Text(
                      'Nhập email đã đăng ký và mật khẩu mới để khôi phục truy cập.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: HydroTheme.soft.withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 28),
                    if (_done)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: HydroTheme.leaf.withValues(alpha: 0.12),
                          border: Border.all(color: HydroTheme.leaf.withValues(alpha: 0.35)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: HydroTheme.leaf),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Thành công — mật khẩu đã được cập nhật.',
                                style: TextStyle(
                                  color: HydroTheme.soft,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _field(
                      controller: _email,
                      label: 'Email',
                      icon: Icons.mail_outline_rounded,
                      keyboard: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _pass,
                      label: 'Mật khẩu mới',
                      icon: Icons.lock_outline_rounded,
                      obscure: _obscure,
                      suffix: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: HydroTheme.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _confirm,
                      label: 'Xác nhận mật khẩu mới',
                      icon: Icons.verified_user_outlined,
                      obscure: _obscure,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: auth.busy || _done ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: HydroTheme.leaf,
                          foregroundColor: HydroTheme.deep,
                          disabledBackgroundColor: HydroTheme.leaf.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: auth.busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: HydroTheme.deep,
                                ),
                              )
                            : Text(
                                _done ? 'Đã cập nhật' : 'Đặt lại mật khẩu',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      style: const TextStyle(color: HydroTheme.soft, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: HydroTheme.soft.withValues(alpha: 0.55)),
        prefixIcon: Icon(icon, color: HydroTheme.leaf.withValues(alpha: 0.9)),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: HydroTheme.leaf, width: 1.4),
        ),
      ),
    );
  }
}
