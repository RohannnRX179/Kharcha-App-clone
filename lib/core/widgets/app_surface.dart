import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppSurface extends StatelessWidget {
  const AppSurface({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}

class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 36.0 : 56.0;
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: AppColors.mintGradient,
          borderRadius: BorderRadius.circular(compact ? 11 : 16),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonMint.withValues(alpha: 0.35),
              blurRadius: compact ? 10 : 20,
              spreadRadius: compact ? 1 : 2,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.account_balance_wallet_rounded,
          color: AppColors.ink,
          size: compact ? 20 : 28,
        ),
      ),
    );
  }
}
