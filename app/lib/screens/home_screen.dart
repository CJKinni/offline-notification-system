import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/agent_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/cron_provider.dart';
import '../theme/colors.dart';
import '../theme/glass_theme.dart';
import '../theme/typography.dart';
import '../widgets/glass_container.dart';
import '../widgets/provider_badge.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agents = ref.watch(agentsProvider);
    final activeAgent = ref.watch(activeAgentProvider);
    final crons = ref.watch(cronsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        // Background glow
        Positioned(top: -100, right: -60,
          child: Container(width: 300, height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                HermesColors.primary.withOpacity(0.12), Colors.transparent,
              ]),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    GlassTheme.spacingMd, GlassTheme.spacingLg,
                    GlassTheme.spacingMd, GlassTheme.spacingSm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Hermes', style: HermesTypography.displayMedium),
                      const Text('Your AI Agent Platform',
                          style: HermesTypography.bodySmall),
                    ]),
                    GestureDetector(
                      onTap: () => context.push('/settings'),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: HermesColors.glassFillMid,
                          border: Border.all(color: HermesColors.glassRim, width: 0.5),
                        ),
                        child: const Icon(Icons.person_rounded,
                            size: 20, color: HermesColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),
            ),

            // Active agent chip
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: GlassTheme.spacingMd, vertical: GlassTheme.spacingSm),
                child: agents.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (list) => list.isEmpty
                    ? _EmptyAgentBanner(onTap: () => context.push('/chat/agent-editor'))
                    : _ActiveAgentCard(agent: activeAgent ?? list.first),
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
            ),

            // Stats row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    GlassTheme.spacingMd, GlassTheme.spacingSm,
                    GlassTheme.spacingMd, GlassTheme.spacingSm),
                child: Row(children: [
                  Expanded(child: _StatCard(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Chats', value: '—',
                    color: HermesColors.primary,
                    onTap: () => context.go('/chat'),
                  )),
                  const SizedBox(width: GlassTheme.spacingSm),
                  Expanded(child: crons.when(
                    loading: () => _StatCard(icon: Icons.schedule_rounded,
                        label: 'Crons', value: '—', color: HermesColors.warning,
                        onTap: () => context.go('/crons')),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (list) => _StatCard(
                      icon: Icons.schedule_rounded,
                      label: 'Crons',
                      value: list.where((c) => c.isActive).length.toString(),
                      color: HermesColors.warning,
                      onTap: () => context.go('/crons'),
                    ),
                  )),
                  const SizedBox(width: GlassTheme.spacingSm),
                  Expanded(child: agents.when(
                    loading: () => _StatCard(icon: Icons.smart_toy_outlined,
                        label: 'Agents', value: '—', color: HermesColors.success,
                        onTap: () => context.push('/chat/agent-editor')),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (list) => _StatCard(
                      icon: Icons.smart_toy_outlined,
                      label: 'Agents',
                      value: list.length.toString(),
                      color: HermesColors.success,
                      onTap: () => context.push('/chat/agent-editor'),
                    ),
                  )),
                ]),
              ).animate().fadeIn(delay: 150.ms),
            ),

            // Quick actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    GlassTheme.spacingMd, GlassTheme.spacingSm,
                    GlassTheme.spacingMd, 0),
                child: const Text('Quick Actions', style: HermesTypography.headlineMedium),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  GlassTheme.spacingMd, GlassTheme.spacingSm,
                  GlassTheme.spacingMd, 120),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: GlassTheme.spacingSm,
                  crossAxisSpacing: GlassTheme.spacingSm,
                  childAspectRatio: 1.5,
                ),
                delegate: SliverChildListDelegate([
                  _QuickAction(
                    icon: Icons.add_comment_rounded,
                    label: 'New Chat',
                    color: HermesColors.primary,
                    onTap: () => context.go('/chat'),
                  ),
                  _QuickAction(
                    icon: Icons.add_alarm_rounded,
                    label: 'New Cron',
                    color: HermesColors.warning,
                    onTap: () => context.push('/crons/editor'),
                  ),
                  _QuickAction(
                    icon: Icons.add_link_rounded,
                    label: 'Add Integration',
                    color: HermesColors.success,
                    onTap: () => context.go('/integrations'),
                  ),
                  _QuickAction(
                    icon: Icons.workspace_premium_rounded,
                    label: 'Go Premium',
                    color: HermesColors.warning,
                    onTap: () => context.push('/settings/subscription'),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ActiveAgentCard extends StatelessWidget {
  final Agent agent;
  const _ActiveAgentCard({required this.agent});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => context.push('/chat/agent-editor?id=${agent.id}'),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: HermesColors.primary.withOpacity(0.15),
            border: Border.all(color: HermesColors.primary.withOpacity(0.3), width: 0.5),
          ),
          child: const Icon(Icons.auto_awesome_rounded, size: 22, color: HermesColors.primary),
        ),
        const SizedBox(width: GlassTheme.spacingMd),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(agent.name, style: HermesTypography.headlineMedium),
          const SizedBox(height: 2),
          Row(children: [
            ProviderBadge(provider: agent.provider, small: true),
            const SizedBox(width: 6),
            Text(agent.model, style: HermesTypography.bodySmall,
                overflow: TextOverflow.ellipsis),
          ]),
        ])),
        const Icon(Icons.chevron_right_rounded, color: HermesColors.textTertiary),
      ]),
    );
  }
}

class _EmptyAgentBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyAgentBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      glowColor: HermesColors.primary.withOpacity(0.1),
      child: Row(children: [
        const Icon(Icons.add_circle_outline_rounded, color: HermesColors.primary, size: 24),
        const SizedBox(width: GlassTheme.spacingMd),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Create your first agent', style: HermesTypography.headlineMedium),
          Text('Tap to configure an AI agent', style: HermesTypography.bodySmall),
        ])),
        const Icon(Icons.chevron_right_rounded, color: HermesColors.textTertiary),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon, required this.label,
    required this.value, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(GlassTheme.spacingMd),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: color),
        const Spacer(),
        Text(value, style: HermesTypography.displayMedium.copyWith(color: color)),
        Text(label, style: HermesTypography.bodySmall),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(GlassTheme.spacingMd),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const Spacer(),
          Text(label, style: HermesTypography.labelLarge),
        ],
      ),
    );
  }
}
