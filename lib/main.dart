import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/auth_provider.dart';
import 'core/hydro_provider.dart';
import 'ui/connect_page.dart';
import 'ui/home_page.dart';
import 'ui/login_page.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ThuyCanhApp());
}

class ThuyCanhApp extends StatefulWidget {
  const ThuyCanhApp({super.key});

  @override
  State<ThuyCanhApp> createState() => _ThuyCanhAppState();
}

class _ThuyCanhAppState extends State<ThuyCanhApp> {
  late final AuthProvider _auth = AuthProvider()..bootstrap();
  late final HydroProvider _hydro = HydroProvider();

  @override
  void initState() {
    super.initState();
    _hydro.onTelemetry = (state) => _auth.syncTelemetry(state);
  }

  @override
  void dispose() {
    _hydro.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _hydro),
      ],
      child: MaterialApp(
        title: 'Thủy Canh IoT STEM',
        debugShowCheckedModeBanner: false,
        theme: HydroTheme.dark(),
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.booting) {
      return const Scaffold(
        backgroundColor: HydroTheme.deep,
        body: Center(child: CircularProgressIndicator(color: HydroTheme.leaf)),
      );
    }

    if (!auth.isLoggedIn) {
      return const LoginPage();
    }

    final hydro = context.watch<HydroProvider>();

    // Bắt buộc nhập tên chip + xác thực trước khi xem cảm biến
    if (!hydro.canEnterSystem) {
      return const ConnectPage();
    }

    return const HomePage();
  }
}
