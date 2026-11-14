import 'package:flutter/material.dart';
import '../../main.dart';

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
      backgroundColor: Color(0xFFFF5733), // Exact orange from screenshot
      body: Center(
        child: SizedBox(
          width: 180,
          height: 180,
          child: CustomPaint(painter: PaperPlanePainter()),
        ),
      ),
    );
  }
}

// Custom Painter to draw the exact 3D paper plane from the screenshot
class PaperPlanePainter extends CustomPainter {
  const PaperPlanePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Scale factor based on 700x700 bounding box
    final w = size.width;
    final h = size.height;

    // Rotate the canvas slightly
    canvas.translate(w / 2, h / 2);
    canvas.rotate(-0.2); // Tilt right
    canvas.translate(-w / 2, -h / 2);

    // Left Wing (White)
    paint.color = Colors.white;
    final leftWing = Path()
      ..moveTo(w * 0.1, h * 0.4)
      ..lineTo(w * 0.9, h * 0.1)
      ..lineTo(w * 0.3, h * 0.7)
      ..close();
    canvas.drawPath(leftWing, paint);

    // Right Wing (Light shadow)
    paint.color = const Color(0xFFFFF0EB);
    final rightWing = Path()
      ..moveTo(w * 0.9, h * 0.1)
      ..lineTo(w * 0.5, h * 0.9)
      ..lineTo(w * 0.3, h * 0.7)
      ..close();
    canvas.drawPath(rightWing, paint);

    // Fold (Darker shadow)
    paint.color = const Color(0xFFFFD1C1);
    final fold = Path()
      ..moveTo(w * 0.5, h * 0.9)
      ..lineTo(w * 0.3, h * 0.7)
      ..lineTo(w * 0.6, h * 0.6)
      ..close();
    canvas.drawPath(fold, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

