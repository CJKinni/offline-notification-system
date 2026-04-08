import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../theme/glass_theme.dart';

class ProviderBadge extends StatelessWidget {
  final String provider;
  final bool small;

  const ProviderBadge({super.key, required this.provider, this.small = false});

  @override
  Widget build(BuildContext context) {
    final color = HermesColors.providerColor(provider);
    final label = provider.toUpperCase();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(GlassTheme.radiusFull),
        border: Border.all(color: color.withOpacity(0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: (small ? HermesTypography.labelSmall : HermesTypography.bodySmall)
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
