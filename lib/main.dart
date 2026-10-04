import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/auth_provider.dart';
import 'core/hydro_provider.dart';
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

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _mqttStarted = false;
  String? _startedForUser;

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
      _mqttStarted = false;
      _startedForUser = null;
      return const LoginPage();
    }

    final uid = auth.user?.id;
    if (!_mqttStarted || _startedForUser != uid) {
      _mqttStarted = true;
      _startedForUser = uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<HydroProvider>().start();
      });
    }

    return const HomePage();
  }
}
