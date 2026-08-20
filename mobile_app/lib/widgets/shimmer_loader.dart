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

/// Skeleton for one row of a grounds list — the horizontal `GroundCard`
/// shape, not the tall detail-page one.
class GroundListItemShimmer extends StatelessWidget {
  const GroundListItemShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Shimmer.fromColors(
      baseColor: colors.input,
      highlightColor: colors.border,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: colors.input,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 64, height: 14, color: colors.input),
                  const SizedBox(height: 8),
                  Container(
                      width: double.infinity, height: 15, color: colors.input),
                  const SizedBox(height: 8),
                  Container(width: 90, height: 12, color: colors.input),
                  const SizedBox(height: 10),
                  Container(width: 72, height: 14, color: colors.input),
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
      // Matches the 20px gutter every real grounds list uses, so the skeleton
      // does not shift the cards sideways when the data lands.
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      itemBuilder: (_, __) => const GroundListItemShimmer(),
    );
  }
}

/// Skeleton for the featured carousel on the home screen.
///
/// Takes its size from the parent so it lands on the same footprint as the
/// card it stands in for, whatever viewport fraction the carousel uses.
class FeaturedCardShimmer extends StatelessWidget {
  const FeaturedCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Shimmer.fromColors(
      baseColor: colors.input,
      highlightColor: colors.border,
      child: Container(
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
    // Same geometry as the real strip: five tiles that run off the right edge
    // rather than a fixed Row, which overflowed on a 390pt phone once the
    // user's text scale pushed the tiles taller.
    final tile = 96 *
        MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3).scale(1);

    return SizedBox(
      height: tile + 16,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        itemCount: 5,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: ShimmerBox(width: 80, height: tile, radius: 16),
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

/// Skeleton shaped like a `BookingCard`: 80px thumbnail, three text lines and
/// a status pill.
class BookingCardShimmer extends StatelessWidget {
  const BookingCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Shimmer.fromColors(
      baseColor: colors.input,
      highlightColor: colors.border,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.input,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 14,
                      color: colors.input,
                      margin: const EdgeInsets.only(bottom: 8, right: 60)),
                  Container(
                      height: 12,
                      color: colors.input,
                      margin: const EdgeInsets.only(bottom: 8, right: 20)),
                  Container(
                      height: 12,
                      width: 90,
                      color: colors.input,
                      margin: const EdgeInsets.only(bottom: 10)),
                  Container(height: 18, width: 72, color: colors.input),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton shaped like a `GameCard`: header row, meta lines and the fill
/// `ProgressBar` along the bottom.
class GameCardShimmer extends StatelessWidget {
  const GameCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Shimmer.fromColors(
      baseColor: colors.input,
      highlightColor: colors.border,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                          margin: const EdgeInsets.only(bottom: 6, right: 40)),
                      Container(height: 11, width: 110, color: colors.input),
                    ],
                  ),
                ),
                Container(height: 20, width: 60, color: colors.input),
              ],
            ),
            const SizedBox(height: 14),
            Container(height: 8, color: colors.input),
            const SizedBox(height: 10),
            Container(height: 11, width: 130, color: colors.input),
          ],
        ),
      ),
    );
  }
}

/// Skeleton shaped like a `CoachCard`: 72px avatar plus name, sport and badges.
class CoachCardShimmer extends StatelessWidget {
  const CoachCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Shimmer.fromColors(
      baseColor: colors.input,
      highlightColor: colors.border,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.input,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 15,
                      color: colors.input,
                      margin: const EdgeInsets.only(bottom: 8, right: 70)),
                  Container(
                      height: 12,
                      color: colors.input,
                      margin: const EdgeInsets.only(bottom: 10, right: 30)),
                  Row(
                    children: [
                      Container(height: 20, width: 66, color: colors.input),
                      const SizedBox(width: 8),
                      Container(height: 20, width: 54, color: colors.input),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for the slot grid on ground detail — a `Wrap` of tile-sized boxes
/// matching `SlotTile`'s footprint.
class SlotGridShimmer extends StatelessWidget {
  final int count;
  const SlotGridShimmer({super.key, this.count = 8});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(
        count,
        (_) => const ShimmerBox(height: 56, width: 100, radius: 10),
      ),
    );
  }
}

/// Repeats a skeleton [count] times without introducing a second scrollable.
/// Use this instead of `ListShimmer` when the placeholder is not ground-shaped.
class ShimmerList extends StatelessWidget {
  final int count;
  final Widget Function() itemBuilder;

  const ShimmerList({super.key, required this.itemBuilder, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (_) => itemBuilder()),
      ),
    );
  }
}
