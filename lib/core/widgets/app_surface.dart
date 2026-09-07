import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppSurface extends StatelessWidget {
  const AppSurface({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
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
    final size = compact ? 34.0 : 52.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(compact ? 10 : 16),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.account_balance_wallet_rounded,
        color: AppColors.ink,
        size: compact ? 19 : 28,
      ),
    );
  }
}
