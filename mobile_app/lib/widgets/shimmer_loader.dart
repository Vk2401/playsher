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
    return ListView.builder(
      itemCount: count,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (_, __) => const GroundCardShimmer(),
    );
  }
}
