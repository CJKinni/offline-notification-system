import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../providers/connection_provider.dart';
import '../theme/colors.dart';
import '../theme/glass_theme.dart';
import '../theme/typography.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_container.dart';

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  final _urlCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  bool _showQr = false;
  String? _error;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _urlCtrl.text.trim();
    final token = _tokenCtrl.text.trim();
    if (url.isEmpty || token.isEmpty) {
      setState(() => _error = 'Please enter both server URL and token.');
      return;
    }
    setState(() => _error = null);

    final ok = await ref.read(connectionProvider.notifier).connect(url, token);
    if (!ok && mounted) {
      setState(() => _error = ref.read(connectionProvider).errorMessage);
    } else if (ok && mounted) {
      context.go('/home');
    }
  }

  void _onQrDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    final parts = barcode!.rawValue!.split('\n');
    if (parts.length >= 2) {
      _urlCtrl.text = parts[0].trim();
      _tokenCtrl.text = parts[1].trim();
      setState(() => _showQr = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectionProvider);
    final isConnecting = state.status == ConnectionStatus.connecting;

    return Scaffold(
      backgroundColor: HermesColors.background,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.2,
                colors: [Color(0x336366F1), Colors.transparent],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(GlassTheme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),

                  // Logo
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: HermesColors.primary.withOpacity(0.15),
                            border: Border.all(
                              color: HermesColors.primary.withOpacity(0.4), width: 1,
                            ),
                          ),
                          child: const Icon(Icons.bolt_rounded,
                              size: 36, color: HermesColors.primary),
                        ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                        const SizedBox(height: 16),
                        const Text('Hermes', style: HermesTypography.displayLarge)
                            .animate().fadeIn(delay: 150.ms),
                        const SizedBox(height: 4),
                        const Text(
                          'Your personal AI agent platform',
                          style: HermesTypography.bodyMedium,
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 250.ms),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Connect to your server',
                            style: HermesTypography.headlineMedium),
                        const SizedBox(height: 4),
                        const Text(
                          'Run  hermes-setup  on your VPS to get the URL and token.',
                          style: HermesTypography.bodySmall,
                        ),
                        const SizedBox(height: GlassTheme.spacingMd),

                        _GlassTextField(
                          controller: _urlCtrl,
                          label: 'Server URL',
                          hint: 'http://1.2.3.4:3001',
                          icon: Icons.dns_rounded,
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: GlassTheme.spacingSm),
                        _GlassTextField(
                          controller: _tokenCtrl,
                          label: 'Bearer Token',
                          hint: 'eyJhbGc...',
                          icon: Icons.key_rounded,
                          obscure: true,
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: GlassTheme.spacingSm),
                          Text(_error!,
                              style: HermesTypography.bodySmall
                                  .copyWith(color: HermesColors.error)),
                        ],

                        const SizedBox(height: GlassTheme.spacingMd),

                        GlassButton(
                          label: 'Connect',
                          icon: Icons.link_rounded,
                          isLoading: isConnecting,
                          onPressed: isConnecting ? null : _connect,
                        ),

                        const SizedBox(height: GlassTheme.spacingSm),

                        GlassButton.outlined(
                          label: 'Scan QR Code',
                          icon: Icons.qr_code_scanner_rounded,
                          onPressed: () => setState(() => _showQr = !_showQr),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),

                  if (_showQr) ...[
                    const SizedBox(height: GlassTheme.spacingMd),
                    GlassCard(
                      child: Column(
                        children: [
                          const Text('Point camera at the QR code',
                              style: HermesTypography.bodyMedium),
                          const SizedBox(height: GlassTheme.spacingSm),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(GlassTheme.radiusSm),
                            child: SizedBox(
                              height: 240,
                              child: MobileScanner(onDetect: _onQrDetect),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: GlassTheme.spacingXl),

                  Center(
                    child: GestureDetector(
                      onTap: () {}, // Open docs
                      child: const Text(
                        'How to set up your server →',
                        style: TextStyle(
                          color: HermesColors.primary,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
  });

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
        obscureText: obscure,
        keyboardType: keyboardType,
        style: HermesTypography.bodyLarge,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: HermesColors.textTertiary, fontSize: 12),
          hintText: hint,
          hintStyle: const TextStyle(color: HermesColors.textDisabled),
          prefixIcon: Icon(icon, size: 18, color: HermesColors.textTertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: GlassTheme.spacingMd,
            vertical: GlassTheme.spacingSm,
          ),
        ),
      ),
    );
  }
}
