import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/auth_provider.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';
import 'theme.dart';
import 'widgets/feedback.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    if (email.isEmpty || pass.isEmpty) {
      showAppSnack(context, message: 'Vui lòng nhập email và mật khẩu');
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.login(email, pass);
    if (!mounted) return;
    if (!ok) {
      showAppSnack(context, message: auth.error ?? 'Đăng nhập chưa thành công');
      return;
    }

    showAppSnack(context, message: 'Đăng nhập thành công', success: true);
    await showSuccessDialog(
      context,
      title: 'Đăng nhập thành công',
      message: 'Tiếp theo hãy nhập tên chip để theo dõi máy.',
    );
    if (!mounted) return;
    auth.confirmPendingSession(successMessage: 'Đăng nhập thành công');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final h = MediaQuery.sizeOf(context).height;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: HydroTheme.screenGradient(),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -60,
              child: _blob(260, HydroTheme.leaf.withValues(alpha: 0.13))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(0.95, 0.95),
                    end: const Offset(1.07, 1.07),
                    duration: 6.seconds,
                  ),
            ),
            Positioned(
              bottom: 40,
              left: -60,
              child: _blob(210, HydroTheme.water.withValues(alpha: 0.1)),
            ),
            SafeArea(
              child: ListView(
                padding: EdgeInsets.fromLTRB(28, h * 0.08, 28, 28),
                children: [
                  Text(
                    'THỦY CANH',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 48,
                          height: 0.95,
                          letterSpacing: -1.4,
                        ),
                  ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.1),
                  const SizedBox(height: 12),
                  Text(
                    'Giám sát mực nước, pH và môi trường\nhệ thống thủy canh IoT STEM.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: HydroTheme.water.withValues(alpha: 0.92),
                          height: 1.45,
                          fontSize: 16,
                        ),
                  ).animate().fadeIn(delay: 80.ms),
                  SizedBox(height: h * 0.06),
                  _field(
                    controller: _email,
                    label: 'Email',
                    icon: Icons.mail_outline_rounded,
                    keyboard: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _pass,
                    label: 'Mật khẩu',
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        final changed = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                        );
                        if (!context.mounted) return;
                        if (changed == true) {
                          showAppSnack(
                            context,
                            message: 'Đặt lại mật khẩu thành công — hãy đăng nhập',
                            success: true,
                          );
                        }
                      },
                      child: Text(
                        'Quên mật khẩu?',
                        style: TextStyle(
                          color: HydroTheme.water.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: auth.busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: HydroTheme.leaf,
                        foregroundColor: HydroTheme.deep,
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
                          : const Text(
                              'Đăng nhập',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RegisterPage()),
                        );
                      },
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            color: HydroTheme.soft.withValues(alpha: 0.75),
                            fontSize: 14,
                          ),
                          children: const [
                            TextSpan(text: 'Chưa có tài khoản? '),
                            TextSpan(
                              text: 'Đăng ký',
                              style: TextStyle(
                                color: HydroTheme.water,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
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
        fillColor: Colors.white.withValues(alpha: 0.05),
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
