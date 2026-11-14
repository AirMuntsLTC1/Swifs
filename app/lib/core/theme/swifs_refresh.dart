import 'package:flutter/material.dart';
import 'swifs_icon.dart';

const Color kPrimary = Color(0xFFFF6B35);

Widget buildSwifsRefreshIcon(IconData icon) {
  return Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Center(
      child: SwifsIcon(icon, color: kPrimary, size: 22),
    ),
  );
}
