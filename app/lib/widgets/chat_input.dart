import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/glass_theme.dart';
import '../theme/typography.dart';

class ChatInput extends StatefulWidget {
  final void Function(String) onSend;
  final bool isLoading;

  const ChatInput({super.key, required this.onSend, this.isLoading = false});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isLoading) return;
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(GlassTheme.radiusLg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: GlassTheme.spacingMd,
            vertical: GlassTheme.spacingSm,
          ),
          decoration: BoxDecoration(
            color: HermesColors.glassFillMid,
            borderRadius: BorderRadius.circular(GlassTheme.radiusLg),
            border: Border.all(color: HermesColors.glassRim, width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: 6,
                  minLines: 1,
                  style: HermesTypography.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'Message Hermes...',
                    hintStyle: TextStyle(color: HermesColors.textTertiary),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: (_) => _send(),
                  textInputAction: TextInputAction.newline,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (_hasText && !widget.isLoading)
                          ? HermesColors.primary
                          : HermesColors.glassFillMid,
                      border: Border.all(
                        color: (_hasText && !widget.isLoading)
                            ? HermesColors.primary.withOpacity(0.5)
                            : HermesColors.glassRim,
                        width: 0.5,
                      ),
                    ),
                    child: widget.isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white,
                            ),
                          )
                        : Icon(
                            Icons.arrow_upward_rounded,
                            size: 18,
                            color: _hasText ? Colors.white : HermesColors.textTertiary,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
