// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/enhanced_constellation_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Celestial Navigator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A237E),
          elevation: 0,
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.disabled)) {
              return Colors.blue.withOpacity(.32);
            }
            return Colors.blue;
          }),
        ),
      ),
      home: const EnhancedConstellationScreen(),
    );
  }
}