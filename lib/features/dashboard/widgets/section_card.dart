import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A titled card with an optional "See all" action — the shared shape of
/// every Dashboard card (spec §11.4) and every Analytics chart card (spec
/// §11.10).
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    this.onSeeAll,
    this.accentColor,
    super.key,
  });

  final String title;
  final Widget child;
  final VoidCallback? onSeeAll;

  /// Optional left-edge accent colour for visual differentiation.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Subtle top-left glow
            Positioned(
              top: -20,
              left: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (accentColor ?? AppColors.neonMint).withValues(
                        alpha: 0.06,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                      ),
                      if (onSeeAll != null)
                        TextButton(
                          onPressed: onSeeAll,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.neonCyan,
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('See all'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "No data for this period" message every chart/card must show instead
/// of an empty or divide-by-zero rendering (spec §11.10 rules, T-6.5).
class EmptySectionBody extends StatelessWidget {
  const EmptySectionBody({
    this.message = 'No data for this period.',
    super.key,
  });
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSubtle),
        const SizedBox(width: 8),
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.textSubtle),
        ),
      ],
    ),
  );
}
