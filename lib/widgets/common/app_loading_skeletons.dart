import 'package:flutter/material.dart';

import 'app_shimmer.dart';

class AppBootLoadingSkeleton extends StatelessWidget {
  const AppBootLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: AppShimmer(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 24),
                const ShimmerBlock(
                  width: 180,
                  height: 28,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                const SizedBox(height: 16),
                const ShimmerBlock(
                  width: double.infinity,
                  height: 110,
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
                const SizedBox(height: 16),
                const ShimmerBlock(
                  width: double.infinity,
                  height: 170,
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
                const SizedBox(height: 16),
                ...List.generate(
                  4,
                  (_) => const ShimmerBlock(
                    width: double.infinity,
                    height: 78,
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                    margin: EdgeInsets.only(bottom: 12),
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

class FormButtonLoadingSkeleton extends StatelessWidget {
  final double height;

  const FormButtonLoadingSkeleton({super.key, this.height = 48});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ShimmerBlock(
        width: double.infinity,
        height: height,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class DailyReportLoadingSkeleton extends StatelessWidget {
  const DailyReportLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ShimmerBlock(
              width: double.infinity,
              height: 190,
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            const SizedBox(height: 16),
            Row(
              children: const [
                Expanded(
                  child: ShimmerBlock(
                    height: 92,
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ShimmerBlock(
                    height: 92,
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const ShimmerBlock(
              width: double.infinity,
              height: 210,
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            const SizedBox(height: 16),
            ...List.generate(
              5,
              (_) => const ShimmerBlock(
                width: double.infinity,
                height: 92,
                borderRadius: BorderRadius.all(Radius.circular(18)),
                margin: EdgeInsets.only(bottom: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
