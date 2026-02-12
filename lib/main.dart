import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app_shell.dart';
import 'core/motion.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        pageTransitionsTheme: Motion.pageTransitionsTheme,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: const ButtonStyle(
            animationDuration: Motion.microAnimationDuration,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: const ButtonStyle(
            animationDuration: Motion.microAnimationDuration,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: const ButtonStyle(
            animationDuration: Motion.microAnimationDuration,
          ),
        ),
      ),
      home: const AppShell(),
    );
  }
}
