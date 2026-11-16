import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

class CategoryGroupSection extends StatelessWidget {
  const CategoryGroupSection({
    super.key,
    required this.title,
    required this.children,
    this.crossAxisCount = 3,
    this.expanded = true,
    this.onToggle,
  });

  final String title;
  final List<Widget> children;
  final int crossAxisCount;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium!;
    final labelHeight =
        MediaQuery.textScalerOf(context).scale(labelStyle.fontSize!) *
        labelStyle.height!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onToggle == null)
          Text(title, style: theme.textTheme.titleMedium)
        else
          Semantics(
            expanded: expanded,
            child: TextButton(
              onPressed: onToggle,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                foregroundColor: theme.colorScheme.onSurface,
                backgroundColor: expanded
                    ? theme.colorScheme.surfaceContainerHighest
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: AppSpacing.xl,
                  ),
                ],
              ),
            ),
          ),
        if (expanded) ...[
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            mainAxisExtent:
                AppSpacing.md * 2 +
                AppSpacing.xxxl +
                AppSpacing.sm +
                labelHeight * 2,
            children: children,
          ),
        ],
      ],
    );
  }
}
