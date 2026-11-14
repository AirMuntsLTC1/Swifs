import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';

class SwifsIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final double strokeWidth;

  const SwifsIcon(this.icon, {super.key, this.size = 24, this.color, this.strokeWidth = 2.2});

  @override
  Widget build(BuildContext context) {
    return LucideIconWidget(
      icon: icon,
      size: size,
      color: color ?? Theme.of(context).iconTheme.color,
      strokeWidth: strokeWidth,
    );
  }
}
