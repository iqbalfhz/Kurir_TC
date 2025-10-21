import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/delivery_page.dart';
import 'pages/profile_page.dart';
import 'services/theme_controller.dart';
import 'pages/history_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Colors.indigo;

    final light = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );

    final dark = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController.mode,
      builder: (_, mode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Starter Kit',
          theme: light,
          darkTheme: dark,
          themeMode: mode,
          home: const LoginPage(),
          routes: {
            '/login': (_) => const LoginPage(),
            '/home': (_) => const HomePage(),
            '/delivery': (_) => const DeliveryPage(),
            '/profile': (_) => const ProfilePage(),
            '/history': (_) => const HistoryPage(),
          },
        );
      },
    );
  }
}
