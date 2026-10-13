import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'core/auth_provider.dart';
import 'core/background_monitor.dart';
import 'core/hydro_notifications.dart';
import 'core/hydro_provider.dart';
import 'ui/connect_page.dart';
import 'ui/home_page.dart';
import 'ui/login_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  BackgroundMonitor.configure();

  // Chặn crash “đỏ” / thoát app vì lỗi UI hoặc zone không bắt được.
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error\n$stack');
    return true; // đã xử lý — không crash process
  };

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ThuyCanhApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_deferredStartup());
  });
}

Future<void> _deferredStartup() async {
  try {
    await HydroNotifications.init().timeout(const Duration(seconds: 8));
  } catch (e, st) {
    debugPrint('HydroNotifications.init failed: $e\n$st');
  }
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
      child: WithForegroundTask(
        child: MaterialApp(
          title: 'Thủy Canh IoT STEM',
          debugShowCheckedModeBanner: false,
          theme: HydroTheme.dark(),
          builder: (context, child) {
            ErrorWidget.builder = (details) {
              return Material(
                color: HydroTheme.deep,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Đã xảy ra lỗi giao diện.\nThử đóng mở lại app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: HydroTheme.soft.withValues(alpha: 0.9)),
                    ),
                  ),
                ),
              );
            };
            return child ?? const SizedBox.shrink();
          },
          home: const _AuthGate(),
        ),
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

    if (!hydro.canEnterSystem) {
      return const ConnectPage();
    }

    return const HomePage();
  }
}
