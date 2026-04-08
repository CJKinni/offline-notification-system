import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/subscription_provider.dart';
import '../theme/colors.dart';
import '../theme/glass_theme.dart';
import '../theme/typography.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_container.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: HermesColors.background,
      body: Stack(children: [
        // Golden glow
        Positioned(top: -80, left: 0, right: 0,
          child: Container(
            height: 300,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 0.8,
                colors: [Color(0x44F59E0B), Colors.transparent],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            // Back button
            Row(children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: HermesColors.textSecondary),
                onPressed: () => context.pop(),
              ),
            ]),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: GlassTheme.spacingLg),
                child: Column(children: [
                  const SizedBox(height: GlassTheme.spacingLg),

                  // Icon
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HermesColors.warning.withOpacity(0.15),
                      border: Border.all(color: HermesColors.warning.withOpacity(0.4), width: 1),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded,
                        size: 40, color: HermesColors.warning),
                  ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

                  const SizedBox(height: GlassTheme.spacingMd),
                  const Text('Hermes Premium', style: HermesTypography.displayMedium)
                      .animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: GlassTheme.spacingSm),
                  const Text(
                    'The full power of your AI agent platform, ad-free.',
                    style: HermesTypography.bodyMedium,
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: GlassTheme.spacingXl),

                  // Price card
                  GlassCard(
                    glowColor: HermesColors.warning.withOpacity(0.08),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('\$9.99', style: TextStyle(
                          fontSize: 36, fontWeight: FontWeight.w700,
                          color: HermesColors.warning,
                        )),
                        const SizedBox(width: 4),
                        Text(' / year',
                            style: HermesTypography.bodyMedium
                                .copyWith(color: HermesColors.textTertiary)),
                      ]),
                      const SizedBox(height: 4),
                      const Text('That\'s less than a dollar a month',
                          style: HermesTypography.bodySmall),
                    ]),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: GlassTheme.spacingMd),

                  // Feature checklist
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('What\'s included', style: HermesTypography.headlineMedium),
                        const SizedBox(height: GlassTheme.spacingMd),
                        ...[
                          ('No ads — ever', Icons.block_rounded, HermesColors.error),
                          ('Unlimited agents', Icons.smart_toy_outlined, HermesColors.primary),
                          ('Unlimited cron tasks', Icons.schedule_rounded, HermesColors.warning),
                          ('Unlimited integrations', Icons.extension_rounded, HermesColors.success),
                          ('Priority support', Icons.support_agent_rounded, HermesColors.primary),
                          ('Early access to new features', Icons.new_releases_rounded, HermesColors.warning),
                        ].map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: GlassTheme.spacingSm),
                          child: Row(children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: f.$3.withOpacity(0.15),
                              ),
                              child: Icon(f.$2, size: 16, color: f.$3),
                            ),
                            const SizedBox(width: GlassTheme.spacingMd),
                            Text(f.$1, style: HermesTypography.bodyLarge),
                          ]),
                        )),
                      ],
                    ),
                  ).animate().fadeIn(delay: 250.ms),

                  const SizedBox(height: GlassTheme.spacingLg),

                  if (sub.isPremium)
                    GlassCard(
                      glowColor: HermesColors.success.withOpacity(0.1),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.check_circle_rounded,
                            color: HermesColors.success),
                        const SizedBox(width: 8),
                        const Text('You\'re on Premium! Thank you.',
                            style: TextStyle(color: HermesColors.success,
                                fontWeight: FontWeight.w500)),
                      ]),
                    )
                  else
                    Column(children: [
                      SizedBox(
                        width: double.infinity,
                        child: GlassButton(
                          label: sub.isLoading ? 'Processing...' : 'Start Premium — \$9.99/yr',
                          color: HermesColors.warning,
                          isLoading: sub.isLoading,
                          onPressed: sub.isLoading ? null : () async {
                            await ref.read(subscriptionProvider.notifier).purchaseYearly();
                          },
                        ),
                      ),
                      const SizedBox(height: GlassTheme.spacingSm),
                      GestureDetector(
                        onTap: () => ref.read(subscriptionProvider.notifier).restore(),
                        child: const Text('Restore previous purchase',
                            style: TextStyle(
                              color: HermesColors.textTertiary,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            )),
                      ),
                    ]),

                  const SizedBox(height: GlassTheme.spacingLg),
                  const Text(
                    'Subscription renews annually. Cancel any time in the App Store or Play Store.',
                    style: HermesTypography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: GlassTheme.spacingXl),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
