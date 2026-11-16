import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

class CategoryGroupSection extends StatelessWidget {
  const CategoryGroupSection({
    super.key,
    required this.title,
    required this.children,
    this.crossAxisCount = 3,
  });

  final String title;
  final List<Widget> children;
  final int crossAxisCount;

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
        Text(title, style: theme.textTheme.titleMedium),
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
    );
  }
}
