import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/colors.dart';
import '../theme/glass_theme.dart';
import '../theme/typography.dart';

class ChatBubble extends StatelessWidget {
  final String role;
  final String content;
  final bool isStreaming;
  final String? provider;

  const ChatBubble({
    super.key,
    required this.role,
    required this.content,
    this.isStreaming = false,
    this.provider,
  });

  bool get isUser => role == 'user';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 48,
        bottom: 12,
      ),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _buildAvatar(),
          const SizedBox(width: 8),
          Flexible(child: _buildBubble()),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(
      begin: 0.1, end: 0,
      duration: 200.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HermesColors.primary.withOpacity(0.2),
        border: Border.all(color: HermesColors.primary.withOpacity(0.4), width: 0.5),
      ),
      child: const Icon(Icons.auto_awesome_rounded, size: 14, color: HermesColors.primary),
    );
  }

  Widget _buildBubble() {
    final fillColor = isUser
        ? HermesColors.primary.withOpacity(0.18)
        : HermesColors.glassFill;
    final rimColor = isUser
        ? HermesColors.primary.withOpacity(0.3)
        : HermesColors.glassRim;

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(GlassTheme.radiusMd),
        topRight: const Radius.circular(GlassTheme.radiusMd),
        bottomLeft: Radius.circular(isUser ? GlassTheme.radiusMd : 4),
        bottomRight: Radius.circular(isUser ? 4 : GlassTheme.radiusMd),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: GlassTheme.spacingMd,
            vertical: GlassTheme.spacingSm + 4,
          ),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(GlassTheme.radiusMd),
              topRight: const Radius.circular(GlassTheme.radiusMd),
              bottomLeft: Radius.circular(isUser ? GlassTheme.radiusMd : 4),
              bottomRight: Radius.circular(isUser ? 4 : GlassTheme.radiusMd),
            ),
            border: Border.all(color: rimColor, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isUser)
                Text(content, style: HermesTypography.bodyLarge)
              else
                MarkdownBody(
                  data: content + (isStreaming ? ' ▋' : ''),
                  styleSheet: MarkdownStyleSheet(
                    p: HermesTypography.bodyLarge,
                    code: HermesTypography.mono.copyWith(
                      backgroundColor: HermesColors.glassFillMid,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: HermesColors.glassFillMid,
                      borderRadius: BorderRadius.circular(GlassTheme.radiusSm),
                    ),
                    blockquoteDecoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: HermesColors.primary, width: 3),
                      ),
                    ),
                    h1: HermesTypography.headlineLarge,
                    h2: HermesTypography.headlineMedium,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
