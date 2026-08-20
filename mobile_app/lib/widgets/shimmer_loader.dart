import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/app_colors.dart';

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Shimmer.fromColors(
      baseColor: colors.input,
      highlightColor: colors.border,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.input,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class GroundCardShimmer extends StatelessWidget {
  const GroundCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Shimmer.fromColors(
      baseColor: colors.input,
      highlightColor: colors.border,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: colors.input,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      width: 200,
                      height: 16,
                      color: colors.input,
                      margin: const EdgeInsets.only(bottom: 8)),
                  Container(
                      width: 140,
                      height: 12,
                      color: colors.input,
                      margin: const EdgeInsets.only(bottom: 8)),
                  Container(width: 100, height: 12, color: colors.input),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ListShimmer extends StatelessWidget {
  final int count;

  const ListShimmer({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    // shrinkWrap + no physics: this is dropped into slivers and Columns that
    // give it unbounded height, where a scrollable ListView either throws or
    // becomes a second scroll surface fighting the page.
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (_, __) => const GroundCardShimmer(),
    );
  }
}

/// Skeleton for the fixed-height featured carousel on the home screen.
class FeaturedCardShimmer extends StatelessWidget {
  const FeaturedCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Shimmer.fromColors(
      baseColor: colors.input,
      highlightColor: colors.border,
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
      ),
    );
  }
}

/// Skeleton for the sport category strip.
class CategoryStripShimmer extends StatelessWidget {
  const CategoryStripShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: List.generate(
          4,
          (_) => const Padding(
            padding: EdgeInsets.only(right: 10),
            child: ShimmerBox(width: 80, height: 96, radius: 16),
          ),
        ),
      ),
    );
  }
}

/// Skeleton shaped like a `NotificationCard`.
class NotificationShimmer extends StatelessWidget {
  const NotificationShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Shimmer.fromColors(
      baseColor: colors.input,
      highlightColor: colors.border,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.input,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 14,
                      color: colors.input,
                      margin: const EdgeInsets.only(bottom: 8, right: 80)),
                  Container(
                      height: 12,
                      color: colors.input,
                      margin: const EdgeInsets.only(bottom: 6)),
                  Container(
                      height: 12,
                      color: colors.input,
                      margin: const EdgeInsets.only(right: 120)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
