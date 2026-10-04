import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/hydro_provider.dart';
import 'ui/home_page.dart';
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
  late final HydroProvider _hydro = HydroProvider();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydro.start();
    });
  }

  @override
  void dispose() {
    _hydro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _hydro,
      child: MaterialApp(
        title: 'Thủy Canh IoT STEM',
        debugShowCheckedModeBanner: false,
        theme: HydroTheme.dark(),
        home: const HomePage(),
      ),
    );
  }
}
