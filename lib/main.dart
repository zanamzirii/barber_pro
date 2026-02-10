import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/customer/home_screen.dart';

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
      theme: ThemeData(fontFamily: 'Inter'),
      home: const _AppEntry(),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  late final Future<void> _splashDelayFuture;

  @override
  void initState() {
    super.initState();
    _splashDelayFuture = Future<void>.delayed(const Duration(seconds: 3));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _splashDelayFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SplashScreen(autoNavigate: false);
        }

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen(autoNavigate: false);
            }

            if (authSnapshot.hasData) {
              return const HomeScreen();
            }
            return const WelcomeScreen(
              backgroundImageAsset: 'assets/images/welcome_screen.png',
            );
          },
        );
      },
    );
  }
}
