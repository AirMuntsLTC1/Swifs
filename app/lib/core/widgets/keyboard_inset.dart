import 'package:flutter/widgets.dart';

/// Lifts its child above the on-screen keyboard.
///
/// It reads the keyboard height in its own build, so only this padding updates on each
/// keyboard animation frame. The child is passed in unchanged, so the content inside
/// (lists, headers, composers, text fields) is not rebuilt with it.
///
/// [basePadding] is any padding the child needs. The keyboard height is added to its bottom.
class KeyboardInset extends StatelessWidget {
  final Widget child;
  final EdgeInsets basePadding;

  const KeyboardInset({
    super.key,
    required this.child,
    this.basePadding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        basePadding.left,
        basePadding.top,
        basePadding.right,
        basePadding.bottom + keyboard,
      ),
      child: child,
    );
  }
}
