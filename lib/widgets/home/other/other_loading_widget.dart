import 'package:flutter/material.dart';

import '../../common/app_shimmer.dart';

class OtherLoadingWidget extends StatelessWidget {
  const OtherLoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ShimmerBlock(
              width: double.infinity,
              height: 170,
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            const SizedBox(height: 12),
            const ShimmerBlock(
              width: double.infinity,
              height: 210,
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            const SizedBox(height: 12),
            ...List.generate(
              4,
              (_) => const ShimmerBlock(
                width: double.infinity,
                height: 86,
                borderRadius: BorderRadius.all(Radius.circular(20)),
                margin: EdgeInsets.only(bottom: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
