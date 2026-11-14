import 'package:flutter/material.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Wait 2.5 seconds, then fade into the Main App
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const MainShell(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFF6B35), // Swifs Orange
      body: Center(
        child: SwifsPlaneLogo(),
      ),
    );
  }
}

// Custom widget to draw the 3D-looking paper plane using standard Icons
class SwifsPlaneLogo extends StatelessWidget {
  const SwifsPlaneLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.4), // Orange glow
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Transform.rotate(
        angle: -0.2, // Slight tilt like the screenshot
        child: const Icon(
          Icons.send_rounded, // Solid paper plane
          size: 100,
          color: Colors.white,
        ),
      ),
    );
  }
}