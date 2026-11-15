import 'package:flutter/widgets.dart';

/// Lifts its child above the on-screen keyboard.
///
/// It reads the keyboard height in its own build, so only this padding updates on each
/// keyboard animation frame. The child is passed in unchanged, so the content inside
/// (lists, headers, composers) is not rebuilt with it.
class KeyboardInset extends StatelessWidget {
  final Widget child;

  const KeyboardInset({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: child,
    );
  }
}
