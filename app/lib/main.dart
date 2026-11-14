import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/home/home_screen.dart';

const Color kPrimary = Color(0xFFFF6B35);

void main() {
  runApp(const ProviderScope(child: SwifsApp()));
}

class SwifsApp extends StatelessWidget {
  const SwifsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swifs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: kPrimary,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        colorSchemeSeed: kPrimary,
      ),
      home: const HomeScreen(),
    );
  }
}
