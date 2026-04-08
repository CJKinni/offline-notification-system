import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/cron_provider.dart';
import '../theme/colors.dart';
import '../theme/glass_theme.dart';
import '../theme/typography.dart';
import '../widgets/glass_container.dart';

class CronsScreen extends ConsumerWidget {
  const CronsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crons = ref.watch(cronsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Scheduled Tasks'),
        actions: [
          GestureDetector(
            onTap: () => context.push('/crons/editor'),
            child: Padding(
              padding: const EdgeInsets.only(right: GlassTheme.spacingMd),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HermesColors.primary.withOpacity(0.15),
                  border: Border.all(color: HermesColors.primary.withOpacity(0.3), width: 0.5),
                ),
                child: const Icon(Icons.add_rounded, size: 20, color: HermesColors.primary),
              ),
            ),
          ),
        ],
      ),
      body: crons.when(
        loading: () => const Center(child: CircularProgressIndicator(color: HermesColors.primary)),
        error: (e, _) => Center(child: Text(e.toString(), style: HermesTypography.bodyMedium)),
        data: (list) => list.isEmpty
          ? _EmptyCrons(onAdd: () => context.push('/crons/editor'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                GlassTheme.spacingMd, GlassTheme.spacingSm,
                GlassTheme.spacingMd, 120,
              ),
              itemCount: list.length,
              itemBuilder: (ctx, i) => _CronCard(
                cron: list[i],
                onDelete: () => ref.read(cronsProvider.notifier).delete(list[i].id),
                onTrigger: () => ref.read(cronsProvider.notifier).trigger(list[i].id),
                onEdit: () => context.push('/crons/editor?id=${list[i].id}'),
              ).animate().fadeIn(delay: (i * 50).ms).slideY(begin: 0.1, end: 0),
            ),
      ),
    );
  }
}

class _CronCard extends StatelessWidget {
  final CronJob cron;
  final VoidCallback onDelete;
  final VoidCallback onTrigger;
  final VoidCallback onEdit;

  const _CronCard({
    required this.cron, required this.onDelete,
    required this.onTrigger, required this.onEdit,
  });

  String _humanSchedule(String expr) {
    final parts = expr.trim().split(RegExp(r'\s+'));
    if (parts.length < 5) return expr;
    final min = parts[0]; final hour = parts[1];
    final dom = parts[2]; final mon = parts[3]; final dow = parts[4];
    if (min == '*' && hour == '*') return 'Every minute';
    if (dom == '*' && mon == '*' && dow == '*') {
      return 'Every day at ${hour.padLeft(2, '0')}:${min.padLeft(2, '0')}';
    }
    return expr;
  }

  String? _lastRun() {
    if (cron.lastRunAt == null) return null;
    final dt = DateTime.fromMillisecondsSinceEpoch(cron.lastRunAt! * 1000);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: GlassTheme.spacingSm),
      onTap: onEdit,
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (cron.isActive ? HermesColors.warning : HermesColors.glassFillMid),
            border: Border.all(
              color: cron.isActive
                ? HermesColors.warning.withOpacity(0.4)
                : HermesColors.glassRim,
              width: 0.5,
            ),
          ),
          child: Icon(
            cron.isActive ? Icons.schedule_rounded : Icons.pause_circle_outline_rounded,
            size: 22,
            color: cron.isActive ? HermesColors.warning : HermesColors.textTertiary,
          ),
        ),
        const SizedBox(width: GlassTheme.spacingMd),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cron.name, style: HermesTypography.bodyLarge,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(_humanSchedule(cron.schedule), style: HermesTypography.bodySmall),
          if (_lastRun() != null)
            Text('Last run: ${_lastRun()}', style: HermesTypography.bodySmall
                .copyWith(color: HermesColors.textDisabled)),
        ])),
        Row(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: onTrigger,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HermesColors.success.withOpacity(0.1),
              ),
              child: const Icon(Icons.play_arrow_rounded, size: 18, color: HermesColors.success),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HermesColors.error.withOpacity(0.1),
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 18, color: HermesColors.error),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _EmptyCrons extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyCrons({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.schedule_rounded, size: 48, color: HermesColors.warning)
            .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 16),
        const Text('No scheduled tasks', style: HermesTypography.headlineMedium),
        const SizedBox(height: 4),
        const Text('Schedule recurring AI tasks on your server',
            style: HermesTypography.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: GlassTheme.spacingMd, vertical: GlassTheme.spacingSm),
            decoration: BoxDecoration(
              color: HermesColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(GlassTheme.radiusFull),
              border: Border.all(color: HermesColors.warning.withOpacity(0.3), width: 0.5),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, size: 18, color: HermesColors.warning),
              SizedBox(width: 6),
              Text('Add Cron Task', style: TextStyle(color: HermesColors.warning, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ]),
    );
  }
}
