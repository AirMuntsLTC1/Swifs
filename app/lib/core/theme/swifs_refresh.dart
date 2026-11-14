import 'package:flutter/material.dart';
import 'swifs_icon.dart';

const Color kPrimary = Color(0xFFFF6B35);

Widget buildSwifsRefreshIcon(IconData icon) {
  return Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: const [
        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
      ],
      border: Border.all(color: const Color(0xFFF0F2F5), width: 1.5),
    ),
    child: Center(
      child: SwifsIcon(icon, color: kPrimary, size: 20),
    ),
  );
}
