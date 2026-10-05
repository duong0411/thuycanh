import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/auth_provider.dart';
import 'theme.dart';
import 'widgets/feedback.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final pass = _pass.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      showAppSnack(context, message: 'Vui lòng điền đủ tên, email và mật khẩu');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      showAppSnack(context, message: 'Email chưa đúng định dạng (ví dụ: ten@gmail.com)');
      return;
    }
    if (pass.length < 6) {
      showAppSnack(context, message: 'Mật khẩu cần ít nhất 6 ký tự');
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.register(name, email, pass);
    if (!mounted) return;
    if (!ok) {
      showAppSnack(context, message: auth.error ?? 'Đăng ký chưa thành công');
      return;
    }

    showAppSnack(context, message: 'Đăng ký thành công', success: true);
    await showSuccessDialog(
      context,
      title: 'Đăng ký thành công',
      message: 'Tài khoản đã sẵn sàng. Tiếp theo hãy kết nối tên chip.',
    );
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    auth.confirmPendingSession(successMessage: 'Đăng ký thành công');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: HydroTheme.screenGradient(),
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
                    Text('Tạo tài khoản', style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
                  children: [
                    Text(
                      'Chào mừng đến Thủy Canh',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28),
                    ).animate().fadeIn(duration: 350.ms),
                    const SizedBox(height: 8),
                    Text(
                      'Chỉ cần tên, email và mật khẩu để theo dõi hệ thống IoT.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: HydroTheme.soft.withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 28),
                    _field(_name, 'Họ và tên', Icons.person_outline_rounded),
                    const SizedBox(height: 14),
                    _field(
                      _email,
                      'Email',
                      Icons.mail_outline_rounded,
                      keyboard: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      _pass,
                      'Mật khẩu',
                      Icons.lock_outline_rounded,
                      obscure: _obscure,
                      suffix: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: HydroTheme.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
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
                                'Đăng ký',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      style: const TextStyle(color: HydroTheme.soft, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: HydroTheme.soft.withValues(alpha: 0.55)),
        prefixIcon: Icon(icon, color: HydroTheme.leaf),
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
