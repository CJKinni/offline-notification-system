import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/agent_provider.dart';
import '../providers/active_agent_id_provider.dart' show activeAgentIdProvider;
import '../theme/colors.dart';
import '../theme/glass_theme.dart';
import '../theme/typography.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_container.dart';

const _providers = ['claude', 'openai', 'gemini', 'ollama', 'minimax'];
const _models = {
  'claude': ['claude-opus-4-6', 'claude-sonnet-4-6', 'claude-haiku-4-5-20251001'],
  'openai': ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-3.5-turbo'],
  'gemini': ['gemini-1.5-pro', 'gemini-1.5-flash'],
  'ollama': ['llama3', 'mistral', 'codellama', 'phi3'],
  'minimax': ['MiniMax-Text-01', 'abab6.5s-chat'],
};

class AgentEditorScreen extends ConsumerStatefulWidget {
  final String? agentId;
  const AgentEditorScreen({super.key, this.agentId});

  @override
  ConsumerState<AgentEditorScreen> createState() => _AgentEditorScreenState();
}

class _AgentEditorScreenState extends ConsumerState<AgentEditorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _nameCtrl = TextEditingController();
  final _promptCtrl = TextEditingController();
  final _personaCtrl = TextEditingController();

  String _provider = 'claude';
  String _model = 'claude-sonnet-4-6';
  String _fallbackProvider = 'openai';
  String _fallbackModel = 'gpt-4o-mini';
  bool _hasFallback = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _promptCtrl.dispose();
    _personaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    final id = await ref.read(agentsProvider.notifier).create({
      'name': _nameCtrl.text.trim(),
      'provider': _provider,
      'model': _model,
      'system_prompt': _promptCtrl.text.trim().isEmpty ? null : _promptCtrl.text.trim(),
      'fallback_provider': _hasFallback ? _fallbackProvider : null,
      'fallback_model': _hasFallback ? _fallbackModel : null,
    });
    setState(() => _isSaving = false);
    if (id != null) {
      ref.read(activeAgentIdProvider.notifier).state = id;
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HermesColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.agentId == null ? 'New Agent' : 'Edit Agent'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: GlassTheme.spacingMd),
            child: GlassButton(
              label: 'Save',
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _save,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: HermesColors.primary,
          unselectedLabelColor: HermesColors.textTertiary,
          indicatorColor: HermesColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Basic'),
            Tab(text: 'Soul'),
            Tab(text: 'Fallback'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _BasicTab(
            nameCtrl: _nameCtrl,
            promptCtrl: _promptCtrl,
            provider: _provider,
            model: _model,
            onProviderChanged: (p) => setState(() {
              _provider = p;
              _model = _models[p]!.first;
            }),
            onModelChanged: (m) => setState(() => _model = m),
          ),
          _SoulTab(personaCtrl: _personaCtrl),
          _FallbackTab(
            hasFallback: _hasFallback,
            fallbackProvider: _fallbackProvider,
            fallbackModel: _fallbackModel,
            onToggle: (v) => setState(() => _hasFallback = v),
            onProviderChanged: (p) => setState(() {
              _fallbackProvider = p;
              _fallbackModel = _models[p]!.first;
            }),
            onModelChanged: (m) => setState(() => _fallbackModel = m),
          ),
        ],
      ),
    );
  }
}

class _BasicTab extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController promptCtrl;
  final String provider;
  final String model;
  final void Function(String) onProviderChanged;
  final void Function(String) onModelChanged;

  const _BasicTab({
    required this.nameCtrl, required this.promptCtrl,
    required this.provider, required this.model,
    required this.onProviderChanged, required this.onModelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(GlassTheme.spacingMd),
      children: [
        _Field(label: 'Agent Name', child: _TextField(controller: nameCtrl, hint: 'My Assistant')),
        const SizedBox(height: GlassTheme.spacingMd),
        _Field(
          label: 'Provider',
          child: _Dropdown(
            value: provider,
            items: _providers,
            onChanged: onProviderChanged,
          ),
        ),
        const SizedBox(height: GlassTheme.spacingMd),
        _Field(
          label: 'Model',
          child: _Dropdown(
            value: model,
            items: _models[provider] ?? [model],
            onChanged: onModelChanged,
          ),
        ),
        const SizedBox(height: GlassTheme.spacingMd),
        _Field(
          label: 'System Prompt (optional)',
          child: _TextField(
            controller: promptCtrl,
            hint: 'You are a helpful assistant...',
            maxLines: 5,
          ),
        ),
      ],
    );
  }
}

class _SoulTab extends StatelessWidget {
  final TextEditingController personaCtrl;
  const _SoulTab({required this.personaCtrl});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(GlassTheme.spacingMd),
      children: [
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Soul Configuration', style: HermesTypography.headlineMedium),
            const SizedBox(height: 4),
            const Text(
              'Define your agent\'s personality, tone, and values. '
              'This is the SOUL.md equivalent — it shapes how your agent thinks and communicates.',
              style: HermesTypography.bodySmall,
            ),
          ]),
        ),
        const SizedBox(height: GlassTheme.spacingMd),
        _Field(
          label: 'Persona',
          child: _TextField(
            controller: personaCtrl,
            hint: 'You are a sharp, pragmatic assistant who values brevity...',
            maxLines: 4,
          ),
        ),
        const SizedBox(height: GlassTheme.spacingMd),
        _Field(
          label: 'Tone',
          child: _Dropdown(
            value: 'helpful',
            items: ['helpful', 'professional', 'casual', 'concise', 'creative', 'technical'],
            onChanged: (_) {},
          ),
        ),
      ],
    );
  }
}

class _FallbackTab extends StatelessWidget {
  final bool hasFallback;
  final String fallbackProvider;
  final String fallbackModel;
  final void Function(bool) onToggle;
  final void Function(String) onProviderChanged;
  final void Function(String) onModelChanged;

  const _FallbackTab({
    required this.hasFallback, required this.fallbackProvider,
    required this.fallbackModel, required this.onToggle,
    required this.onProviderChanged, required this.onModelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(GlassTheme.spacingMd),
      children: [
        GlassCard(
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Enable Fallback', style: HermesTypography.bodyLarge),
              const Text(
                'If the primary provider fails, automatically retry with a backup.',
                style: HermesTypography.bodySmall,
              ),
            ])),
            Switch(
              value: hasFallback,
              onChanged: onToggle,
              activeColor: HermesColors.primary,
            ),
          ]),
        ),
        if (hasFallback) ...[
          const SizedBox(height: GlassTheme.spacingMd),
          _Field(
            label: 'Fallback Provider',
            child: _Dropdown(
              value: fallbackProvider,
              items: _providers,
              onChanged: onProviderChanged,
            ),
          ),
          const SizedBox(height: GlassTheme.spacingMd),
          _Field(
            label: 'Fallback Model',
            child: _Dropdown(
              value: fallbackModel,
              items: _models[fallbackProvider] ?? [fallbackModel],
              onChanged: onModelChanged,
            ),
          ),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: HermesTypography.labelSmall),
      const SizedBox(height: 6),
      child,
    ]);
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  const _TextField({required this.controller, this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HermesColors.glassFill,
        borderRadius: BorderRadius.circular(GlassTheme.radiusSm),
        border: Border.all(color: HermesColors.glassRim, width: 0.5),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: HermesTypography.bodyLarge,
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

class _Dropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final void Function(String) onChanged;
  const _Dropdown({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HermesColors.glassFill,
        borderRadius: BorderRadius.circular(GlassTheme.radiusSm),
        border: Border.all(color: HermesColors.glassRim, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: GlassTheme.spacingMd),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        dropdownColor: HermesColors.surfaceElevated,
        underline: const SizedBox.shrink(),
        style: HermesTypography.bodyLarge,
        iconEnabledColor: HermesColors.textTertiary,
        items: items.map((v) => DropdownMenuItem(
          value: v,
          child: Text(v, style: HermesTypography.bodyLarge),
        )).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    );
  }
}
