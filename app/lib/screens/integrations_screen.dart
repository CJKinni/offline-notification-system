import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/colors.dart';
import '../theme/glass_theme.dart';
import '../theme/typography.dart';
import '../widgets/glass_container.dart';

// Integration type definitions
const _integrationTypes = [
  (
    id: 'gmail',
    name: 'Gmail',
    desc: 'Read, search, and send emails',
    icon: Icons.email_rounded,
    color: Color(0xFFEA4335),
  ),
  (
    id: 'calendar',
    name: 'Google Calendar',
    desc: 'View and create calendar events',
    icon: Icons.calendar_month_rounded,
    color: Color(0xFF4285F4),
  ),
  (
    id: 'slack',
    name: 'Slack',
    desc: 'Post messages and read channels',
    icon: Icons.chat_rounded,
    color: Color(0xFF4A154B),
  ),
  (
    id: 'webhook',
    name: 'Webhook',
    desc: 'Send and receive HTTP webhooks',
    icon: Icons.webhook_rounded,
    color: Color(0xFF10B981),
  ),
  (
    id: 'rss',
    name: 'RSS / Atom Feed',
    desc: 'Monitor and summarize news feeds',
    icon: Icons.rss_feed_rounded,
    color: Color(0xFFF59E0B),
  ),
];

class IntegrationsScreen extends ConsumerWidget {
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Integrations'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            GlassTheme.spacingMd, GlassTheme.spacingSm, GlassTheme.spacingMd, 120),
        children: [
          const Text(
            'Connect services to your agents and flows',
            style: HermesTypography.bodyMedium,
          ),
          const SizedBox(height: GlassTheme.spacingMd),
          ..._integrationTypes.asMap().entries.map((entry) {
            final i = entry.key;
            final t = entry.value;
            return _IntegrationCard(
              id: t.id, name: t.name, desc: t.desc,
              icon: t.icon, color: t.color,
              onConfigure: () => _showConfigSheet(context, t.id, t.name),
            ).animate().fadeIn(delay: (i * 60).ms).slideX(begin: 0.1, end: 0);
          }),
        ],
      ),
    );
  }

  void _showConfigSheet(BuildContext context, String type, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ConfigSheet(type: type, name: name),
    );
  }
}

class _IntegrationCard extends StatelessWidget {
  final String id;
  final String name;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback onConfigure;

  const _IntegrationCard({
    required this.id, required this.name, required this.desc,
    required this.icon, required this.color, required this.onConfigure,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: GlassTheme.spacingSm),
      onTap: onConfigure,
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.15),
            border: Border.all(color: color.withOpacity(0.3), width: 0.5),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        const SizedBox(width: GlassTheme.spacingMd),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: HermesTypography.bodyLarge),
          Text(desc, style: HermesTypography.bodySmall),
        ])),
        const Icon(Icons.add_circle_outline_rounded,
            size: 20, color: HermesColors.textTertiary),
      ]),
    );
  }
}

class _ConfigSheet extends StatefulWidget {
  final String type;
  final String name;
  const _ConfigSheet({required this.type, required this.name});

  @override
  State<_ConfigSheet> createState() => _ConfigSheetState();
}

class _ConfigSheetState extends State<_ConfigSheet> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _ctrls = {};

  Map<String, String> get _fields {
    switch (widget.type) {
      case 'gmail': case 'calendar':
        return {'access_token': 'OAuth Access Token', 'refresh_token': 'Refresh Token'};
      case 'slack':
        return {'bot_token': 'Bot Token'};
      case 'webhook':
        return {'url': 'Webhook URL', 'secret': 'HMAC Secret (optional)'};
      case 'rss':
        return {'url': 'Feed URL'};
      default:
        return {};
    }
  }

  @override
  void initState() {
    super.initState();
    for (final k in _fields.keys) _ctrls[k] = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: GlassTheme.spacingMd, right: GlassTheme.spacingMd,
        bottom: MediaQuery.of(context).viewInsets.bottom + GlassTheme.spacingMd,
        top: GlassTheme.spacingMd,
      ),
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Configure ${widget.name}', style: HermesTypography.headlineMedium),
            const SizedBox(height: GlassTheme.spacingMd),
            Form(
              key: _formKey,
              child: Column(children: _fields.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: GlassTheme.spacingSm),
                child: Container(
                  decoration: BoxDecoration(
                    color: HermesColors.glassFill,
                    borderRadius: BorderRadius.circular(GlassTheme.radiusSm),
                    border: Border.all(color: HermesColors.glassRim, width: 0.5),
                  ),
                  child: TextField(
                    controller: _ctrls[e.key],
                    style: HermesTypography.bodyLarge,
                    decoration: InputDecoration(
                      labelText: e.value,
                      labelStyle: const TextStyle(color: HermesColors.textTertiary, fontSize: 12),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(GlassTheme.spacingMd),
                    ),
                  ),
                ),
              )).toList()),
            ),
            const SizedBox(height: GlassTheme.spacingMd),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: HermesColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GlassTheme.radiusSm),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Save Integration'),
            ),
          ],
        ),
      ),
    );
  }
}
