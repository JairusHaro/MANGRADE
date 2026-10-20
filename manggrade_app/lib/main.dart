import 'package:flutter/material.dart';

import 'screens/main_shell.dart';
import 'screens/splash_screen.dart';
import 'services/history_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HistoryStore.initialize();

  runApp(const MangoGradeApp());
}

class MangoGradeApp extends StatefulWidget {
  const MangoGradeApp({super.key});

  @override
  State<MangoGradeApp> createState() => _MangoGradeAppState();
}

class _MangoGradeAppState extends State<MangoGradeApp> {
  bool showSplash = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MangoGrade',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: showSplash
          ? SplashScreen(
              onFinished: () => setState(() => showSplash = false),
            )
          : const MainShell(),
    );
  }
}
