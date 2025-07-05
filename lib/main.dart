import 'dart:async';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

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
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF56A6E7)),
        textTheme: const TextTheme().apply(fontFamily: 'Shabnam'),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
