import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/agent_provider.dart';
import '../providers/cron_provider.dart';
import '../theme/colors.dart';
import '../theme/glass_theme.dart';
import '../theme/typography.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_container.dart';

const _presets = [
  ('Every minute', '* * * * *'),
  ('Every hour', '0 * * * *'),
  ('Daily at 8am', '0 8 * * *'),
  ('Daily at midnight', '0 0 * * *'),
  ('Weekly (Mon 9am)', '0 9 * * 1'),
  ('Monthly (1st 8am)', '0 8 1 * *'),
];

class CronEditorScreen extends ConsumerStatefulWidget {
  final String? cronId;
  const CronEditorScreen({super.key, this.cronId});

  @override
  ConsumerState<CronEditorScreen> createState() => _CronEditorScreenState();
}

class _CronEditorScreenState extends ConsumerState<CronEditorScreen> {
  final _nameCtrl = TextEditingController();
  final _schedCtrl = TextEditingController(text: '0 8 * * *');
  final _promptCtrl = TextEditingController();
  String? _agentId;
  bool _isSaving = false;

  String _humanReadable(String expr) {
    for (final p in _presets) {
      if (p.$2 == expr.trim()) return p.$1;
    }
    final parts = expr.trim().split(RegExp(r'\s+'));
    if (parts.length >= 5) {
      return 'Custom: $expr';
    }
    return expr;
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _schedCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    await ref.read(cronsProvider.notifier).create({
      'name': _nameCtrl.text.trim(),
      'schedule': _schedCtrl.text.trim(),
      'agent_id': _agentId,
      'prompt': _promptCtrl.text.trim().isEmpty ? null : _promptCtrl.text.trim(),
    });
    setState(() => _isSaving = false);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final agents = ref.watch(agentsProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: HermesColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('New Cron Task'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: GlassTheme.spacingMd),
            child: GlassButton(
              label: 'Save',
              isLoading: _isSaving,
              color: HermesColors.warning,
              onPressed: _isSaving ? null : _save,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(GlassTheme.spacingMd),
        children: [
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Task Name', style: HermesTypography.labelSmall),
              const SizedBox(height: 6),
              _tf(_nameCtrl, 'Daily news summary', 1),
            ]),
          ),

          const SizedBox(height: GlassTheme.spacingMd),

          // Schedule
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Schedule', style: HermesTypography.headlineMedium),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _humanReadable(_schedCtrl.text),
                  style: HermesTypography.bodySmall.copyWith(color: HermesColors.warning),
                ),
              ),
              const SizedBox(height: GlassTheme.spacingMd),

              // Presets
              Wrap(
                spacing: GlassTheme.spacingSm,
                runSpacing: GlassTheme.spacingSm,
                children: _presets.map((p) {
                  final active = _schedCtrl.text.trim() == p.$2;
                  return GestureDetector(
                    onTap: () => setState(() => _schedCtrl.text = p.$2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(GlassTheme.radiusFull),
                        color: active
                          ? HermesColors.warning.withOpacity(0.15)
                          : HermesColors.glassFill,
                        border: Border.all(
                          color: active
                            ? HermesColors.warning.withOpacity(0.4)
                            : HermesColors.glassRim,
                          width: 0.5,
                        ),
                      ),
                      child: Text(p.$1, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: active ? HermesColors.warning : HermesColors.textSecondary,
                      )),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: GlassTheme.spacingMd),
              const Text('Custom expression', style: HermesTypography.labelSmall),
              const SizedBox(height: 6),
              _tf(_schedCtrl, '0 8 * * *', 1),
            ]),
          ),

          const SizedBox(height: GlassTheme.spacingMd),

          // Agent picker
          if (agents.isNotEmpty) GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Run with Agent', style: HermesTypography.headlineMedium),
              const SizedBox(height: GlassTheme.spacingSm),
              ...agents.map((a) {
                final selected = _agentId == a.id;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HermesColors.primary.withOpacity(selected ? 0.25 : 0.1),
                    ),
                    child: Icon(Icons.auto_awesome_rounded, size: 18,
                        color: selected ? HermesColors.primary : HermesColors.textTertiary),
                  ),
                  title: Text(a.name, style: HermesTypography.bodyLarge),
                  trailing: selected
                    ? const Icon(Icons.check_circle_rounded,
                        size: 20, color: HermesColors.primary)
                    : null,
                  onTap: () => setState(() => _agentId = selected ? null : a.id),
                );
              }),
            ]),
          ),

          const SizedBox(height: GlassTheme.spacingMd),

          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Prompt', style: HermesTypography.headlineMedium),
              const SizedBox(height: 4),
              const Text('What should the agent do when this fires?',
                  style: HermesTypography.bodySmall),
              const SizedBox(height: GlassTheme.spacingSm),
              _tf(_promptCtrl, 'Summarize today\'s top tech news in 5 bullet points.', 4),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _tf(TextEditingController c, String hint, int maxLines) {
    return Container(
      decoration: BoxDecoration(
        color: HermesColors.glassFill,
        borderRadius: BorderRadius.circular(GlassTheme.radiusSm),
        border: Border.all(color: HermesColors.glassRim, width: 0.5),
      ),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        style: HermesTypography.bodyLarge,
        onChanged: maxLines == 1 ? (_) => setState(() {}) : null,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: HermesColors.textDisabled),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(GlassTheme.spacingMd),
        ),
      ),
    );
  }
}
