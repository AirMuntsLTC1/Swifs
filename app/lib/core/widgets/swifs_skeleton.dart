import 'package:flutter/material.dart';

const Color _kBase = Color(0xFFEDEFF2);
const Color _kHighlight = Color(0xFFF8F9FB);

/// A light sweep across its child: the shimmer effect used for loading skeletons.
/// Wrap a whole group of skeleton blocks in one [SwifsShimmer] (one animation, not one per block).
class SwifsShimmer extends StatefulWidget {
  final Widget child;

  const SwifsShimmer({super.key, required this.child});

  @override
  State<SwifsShimmer> createState() => _SwifsShimmerState();
}

class _SwifsShimmerState extends State<SwifsShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value * 2 - 1; // -1 to 1 across the loop
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(-1.0 + 2 * t, 0),
            end: Alignment(1.0 + 2 * t, 0),
            colors: const [_kBase, _kHighlight, _kBase],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// One grey block. Give it a width (or place it where the width is known) and a height.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 6,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _kBase,
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// A full grey block with its own shimmer. Used as the placeholder while a photo loads.
class SwifsSkeletonBox extends StatelessWidget {
  const SwifsSkeletonBox({super.key});

  @override
  Widget build(BuildContext context) {
    return const SwifsShimmer(child: ColoredBox(color: _kBase, child: SizedBox.expand()));
  }
}

/// Skeleton for feed posts: header row, media square, actions, and caption lines.
class FeedSkeleton extends StatelessWidget {
  final int count;

  const FeedSkeleton({super.key, this.count = 2});

  @override
  Widget build(BuildContext context) {
    return SwifsShimmer(
      child: Column(
        children: [for (int i = 0; i < count; i++) const _FeedCardSkeleton()],
      ),
    );
  }
}

class _FeedCardSkeleton extends StatelessWidget {
  const _FeedCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const SkeletonBox(width: 36, height: 36, shape: BoxShape.circle),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 110, height: 12),
                  SizedBox(height: 6),
                  SkeletonBox(width: 60, height: 10),
                ],
              ),
            ],
          ),
        ),
        const AspectRatio(aspectRatio: 4 / 5, child: ColoredBox(color: _kBase)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletonBox(width: 80, height: 12),
              SizedBox(height: 8),
              SkeletonBox(width: 240, height: 12),
              SizedBox(height: 6),
              SkeletonBox(width: 180, height: 12),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Skeleton for a grid of photos (profile and explore).
class GridSkeleton extends StatelessWidget {
  final int count;

  const GridSkeleton({super.key, this.count = 12});

  @override
  Widget build(BuildContext context) {
    return SwifsShimmer(
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        children: List.generate(count, (_) => const ColoredBox(color: _kBase)),
      ),
    );
  }
}

/// Skeleton for a list of people or conversations (messages, notifications, followers).
class ListRowsSkeleton extends StatelessWidget {
  final int rows;

  const ListRowsSkeleton({super.key, this.rows = 6});

  @override
  Widget build(BuildContext context) {
    return SwifsShimmer(
      child: Column(
        children: List.generate(
          rows,
          (_) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                SkeletonBox(width: 52, height: 52, shape: BoxShape.circle),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 140, height: 12),
                      SizedBox(height: 8),
                      SkeletonBox(width: 200, height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
