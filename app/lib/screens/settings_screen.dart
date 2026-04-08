import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/connection_provider.dart';
import '../providers/subscription_provider.dart';
import '../theme/colors.dart';
import '../theme/glass_theme.dart';
import '../theme/typography.dart';
import '../widgets/glass_container.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(connectionProvider);
    final sub = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            GlassTheme.spacingMd, GlassTheme.spacingSm, GlassTheme.spacingMd, 120),
        children: [

          // Subscription banner
          if (!sub.isPremium)
            GlassCard(
              margin: const EdgeInsets.only(bottom: GlassTheme.spacingMd),
              glowColor: HermesColors.warning.withOpacity(0.1),
              onTap: () => context.push('/settings/subscription'),
              child: Row(children: [
                const Icon(Icons.workspace_premium_rounded,
                    size: 28, color: HermesColors.warning),
                const SizedBox(width: GlassTheme.spacingMd),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Go Premium', style: HermesTypography.headlineMedium),
                  Text('Remove ads · Unlimited agents & crons',
                      style: HermesTypography.bodySmall),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: HermesColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(GlassTheme.radiusFull),
                    border: Border.all(color: HermesColors.warning.withOpacity(0.3), width: 0.5),
                  ),
                  child: const Text('\$9.99/yr', style: TextStyle(
                    color: HermesColors.warning, fontSize: 12, fontWeight: FontWeight.w600,
                  )),
                ),
              ]),
            ),

          _SettingsSection(title: 'Server', items: [
            _SettingsItem(
              icon: Icons.dns_rounded,
              label: 'Server URL',
              value: conn.serverUrl ?? 'Not connected',
              onTap: () => context.go('/connect'),
            ),
            _SettingsItem(
              icon: Icons.circle,
              label: 'Status',
              value: conn.isConnected ? 'Connected' : 'Disconnected',
              valueColor: conn.isConnected ? HermesColors.success : HermesColors.error,
              onTap: null,
            ),
            _SettingsItem(
              icon: Icons.link_off_rounded,
              label: 'Disconnect',
              onTap: () async {
                await ref.read(connectionProvider.notifier).disconnect();
                if (context.mounted) context.go('/connect');
              },
            ),
          ]),

          const SizedBox(height: GlassTheme.spacingMd),

          _SettingsSection(title: 'Account', items: [
            _SettingsItem(
              icon: Icons.card_membership_rounded,
              label: sub.isPremium ? 'Premium ✓' : 'Free Plan',
              valueColor: sub.isPremium ? HermesColors.success : null,
              onTap: () => context.push('/settings/subscription'),
            ),
            if (sub.isPremium)
              _SettingsItem(
                icon: Icons.restore_rounded,
                label: 'Restore Purchases',
                onTap: () => ref.read(subscriptionProvider.notifier).restore(),
              ),
          ]),

          const SizedBox(height: GlassTheme.spacingMd),

          _SettingsSection(title: 'About', items: [
            _SettingsItem(icon: Icons.info_outline_rounded, label: 'Version', value: '1.0.0', onTap: null),
            _SettingsItem(icon: Icons.code_rounded, label: 'Open Source', value: 'GitHub', onTap: () {}),
            _SettingsItem(icon: Icons.bug_report_outlined, label: 'Report Issue', onTap: () {}),
          ]),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;

  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(
            left: GlassTheme.spacingSm, bottom: GlassTheme.spacingSm),
        child: Text(title.toUpperCase(), style: HermesTypography.labelSmall),
      ),
      GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: items.asMap().entries.map((e) {
            final item = e.value;
            final isLast = e.key == items.length - 1;
            return Column(children: [
              item,
              if (!isLast)
                const Divider(height: 1, color: HermesColors.glassRim, indent: 52),
            ]);
          }).toList(),
        ),
      ),
    ]);
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color? valueColor;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    this.value,
    this.valueColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 20, color: HermesColors.textSecondary),
      title: Text(label, style: HermesTypography.bodyLarge),
      trailing: value != null
        ? Text(
            value!,
            style: HermesTypography.bodyMedium.copyWith(color: valueColor),
          )
        : onTap != null
          ? const Icon(Icons.chevron_right_rounded, color: HermesColors.textTertiary)
          : null,
    );
  }
}
