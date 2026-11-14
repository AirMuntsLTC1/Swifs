import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A round profile picture. Shows the user's photo (cached on the phone) or their first letter.
class UserAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;

  const UserAvatar({super.key, required this.url, required this.name, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE4E6EB),
      backgroundImage: hasUrl ? CachedNetworkImageProvider(url!) : null,
      onBackgroundImageError: hasUrl ? (_, __) {} : null,
      child: hasUrl
          ? null
          : Text(
              initial,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.8,
              ),
            ),
    );
  }
}
