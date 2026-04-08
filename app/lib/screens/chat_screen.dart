import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../providers/agent_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/subscription_provider.dart';
import '../theme/colors.dart';
import '../theme/glass_theme.dart';
import '../theme/typography.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/glass_container.dart';
import '../widgets/provider_badge.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollCtrl = ScrollController();
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    _initAd();
    _initConversation();
  }

  Future<void> _initConversation() async {
    final agent = ref.read(activeAgentProvider);
    if (agent == null) return;
    final chatNotifier = ref.read(chatProvider.notifier);
    final chat = ref.read(chatProvider);
    if (chat.activeConversationId == null) {
      await chatNotifier.createConversation(agent.id);
    }
  }

  void _initAd() {
    final isPremium = ref.read(subscriptionProvider).isPremium;
    if (isPremium) return;
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/2934735716', // Test ID
      size: AdSize.banner,
      request: const AdRequest(),
      listener: const BannerAdListener(),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final activeAgent = ref.watch(activeAgentProvider);
    final isPremium = ref.watch(subscriptionProvider).isPremium;
    final msgs = chat.active?.messages ?? [];

    ref.listen(chatProvider, (prev, next) {
      if ((next.active?.messages.length ?? 0) > (prev?.active?.messages.length ?? 0)) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: activeAgent != null
          ? Row(children: [
              const Icon(Icons.auto_awesome_rounded, size: 18, color: HermesColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(activeAgent.name, style: HermesTypography.headlineMedium),
              ])),
            ])
          : const Text('Chat'),
        actions: [
          if (activeAgent != null)
            GestureDetector(
              onTap: () => _showAgentSelector(context),
              child: Padding(
                padding: const EdgeInsets.only(right: GlassTheme.spacingMd),
                child: ProviderBadge(provider: activeAgent.provider),
              ),
            ),
          GestureDetector(
            onTap: () => context.push('/chat/agent-editor'),
            child: Padding(
              padding: const EdgeInsets.only(right: GlassTheme.spacingMd),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HermesColors.glassFill,
                  border: Border.all(color: HermesColors.glassRim, width: 0.5),
                ),
                child: const Icon(Icons.tune_rounded, size: 18, color: HermesColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: msgs.isEmpty
              ? _EmptyState(onTap: () {})
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(
                      GlassTheme.spacingMd, GlassTheme.spacingSm,
                      GlassTheme.spacingMd, GlassTheme.spacingSm),
                  itemCount: msgs.length + (chat.isSending ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i == msgs.length && chat.isSending) {
                      // Streaming placeholder
                      return ChatBubble(
                        role: 'assistant',
                        content: chat.streamingDelta.isEmpty
                            ? ' ' : chat.streamingDelta,
                        isStreaming: true,
                      );
                    }
                    final m = msgs[i];
                    return ChatBubble(
                      role: m.role,
                      content: m.content,
                      provider: m.provider,
                    );
                  },
                ),
          ),

          // Ad banner (hidden for premium)
          if (!isPremium && _bannerAd != null)
            Container(
              height: 52,
              alignment: Alignment.center,
              child: AdWidget(ad: _bannerAd!),
            ),

          // Input
          Padding(
            padding: EdgeInsets.fromLTRB(
              GlassTheme.spacingMd,
              GlassTheme.spacingSm,
              GlassTheme.spacingMd,
              MediaQuery.of(context).padding.bottom + 80, // above tab bar
            ),
            child: ChatInput(
              isLoading: chat.isSending,
              onSend: (text) {
                if (chat.activeConversationId == null && activeAgent != null) {
                  ref.read(chatProvider.notifier)
                      .createConversation(activeAgent.id)
                      .then((_) => ref.read(chatProvider.notifier).sendMessage(text));
                } else {
                  ref.read(chatProvider.notifier).sendMessage(text);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAgentSelector(BuildContext context) {
    final agents = ref.read(agentsProvider).valueOrNull ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AgentSelectorSheet(
        agents: agents,
        activeId: ref.read(activeAgentIdProvider),
        onSelect: (agent) {
          ref.read(activeAgentIdProvider.notifier).state = agent.id;
          ref.read(chatProvider.notifier).createConversation(agent.id);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.auto_awesome_rounded, size: 48, color: HermesColors.primary)
            .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 16),
        const Text('Start a conversation', style: HermesTypography.headlineMedium),
        const SizedBox(height: 4),
        const Text('Type a message below to begin', style: HermesTypography.bodySmall),
      ]),
    );
  }
}

class _AgentSelectorSheet extends StatelessWidget {
  final List<Agent> agents;
  final String? activeId;
  final void Function(Agent) onSelect;

  const _AgentSelectorSheet({
    required this.agents, required this.activeId, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(GlassTheme.spacingMd),
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Switch Agent', style: HermesTypography.headlineMedium),
            const SizedBox(height: GlassTheme.spacingMd),
            ...agents.map((a) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HermesColors.primary.withOpacity(0.15),
                ),
                child: const Icon(Icons.auto_awesome_rounded, size: 18, color: HermesColors.primary),
              ),
              title: Text(a.name, style: HermesTypography.bodyLarge),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                ProviderBadge(provider: a.provider, small: true),
                if (a.id == activeId) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle_rounded,
                      size: 18, color: HermesColors.success),
                ],
              ]),
              onTap: () => onSelect(a),
            )),
          ],
        ),
      ),
    );
  }
}
