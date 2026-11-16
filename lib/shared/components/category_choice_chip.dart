import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';

class CategoryChoiceChip extends StatelessWidget {
  const CategoryChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onSelected,
    this.icon,
    this.tooltip,
  });

  final String label;
  final bool selected;
  final Color accentColor;
  final IconData? icon;
  final String? tooltip;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.colorScheme.brightness == Brightness.dark;

    return Tooltip(
      message: tooltip ?? label,
      excludeFromSemantics: true,
      child: Semantics(
        selected: selected,
        child: TextButton(
          onPressed: onSelected,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            foregroundColor: accentColor,
            backgroundColor: selected
                ? accentColor.withValues(alpha: isDark ? 0.14 : 0.06)
                : theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            side: BorderSide(
              width: 1.4,
              color: selected
                  ? accentColor
                  : (isDark
                        ? AppColors.darkBorderSubtle
                        : AppColors.borderSubtle),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  children: [
                    Container(
                      width: AppSpacing.xxxl,
                      height: AppSpacing.xxxl,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(
                          alpha: isDark ? 0.18 : 0.10,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon ?? Icons.category_rounded,
                        size: AppSpacing.xl,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: Center(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Positioned(
                  top: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: Icon(
                    Icons.check_rounded,
                    size: AppSpacing.lg,
                    color: accentColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
