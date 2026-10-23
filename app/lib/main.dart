import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'state/profile.dart';
import 'state/profile_scope.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final profile = await PlayerProfile.load();
  runApp(OmahaApp(profile: profile));
}

class OmahaApp extends StatelessWidget {
  const OmahaApp({super.key, required this.profile});
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    return ProfileScope(
      profile: profile,
      child: MaterialApp(
        title: 'Omaha 3 boards',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const AppShell(),
      ),
    );
  }
}
