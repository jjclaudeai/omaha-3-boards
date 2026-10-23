import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/table_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const OmahaApp());
}

class OmahaApp extends StatelessWidget {
  const OmahaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Omaha 3 boards',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E3A), brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const TableScreen(),
    );
  }
}
