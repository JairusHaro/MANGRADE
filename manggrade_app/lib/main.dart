import 'package:flutter/material.dart';

import 'screens/main_shell.dart';
import 'screens/splash_screen.dart';
import 'services/history_store.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MangGradeApp());
}

class MangGradeApp extends StatefulWidget {
  const MangGradeApp({super.key});

  @override
  State<MangGradeApp> createState() => _MangGradeAppState();
}

class _MangGradeAppState extends State<MangGradeApp> {
  bool showSplash = true;

  @override
  void initState() {
    super.initState();
    HistoryStore.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MangGrade',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: showSplash
          ? SplashScreen(
              onFinished: () {
                if (mounted) {
                  setState(() => showSplash = false);
                }
              },
            )
          : const MainShell(),
    );
  }
}
