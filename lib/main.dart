import 'dart:async';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'services/app_config.dart';
import 'services/auth_service.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize environment variables
      await AppConfig.initialize();

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details); // Still logs to console
        // Optionally send to analytics or crash reporting
      };

      runApp(const MyApp());
    },
    (Object error, StackTrace stack) {
      // Handle all uncaught async errors here
      debugPrint('🔴 Caught in runZonedGuarded: $error');
      // Optionally log or report this too
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zurtex',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Shabnam',
        scaffoldBackgroundColor: const Color(0xFF212121),
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF9700FF)),
        textTheme: const TextTheme().apply(fontFamily: 'Shabnam'),
      ),
      home: const AuthWrapper(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF212121),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF9700FF)),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data == true) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
