import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';
import '../theme/glass_theme.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HermesColors.background,
      extendBody: true,
      body: child,
      bottomNavigationBar: _GlassTabBar(),
    );
  }
}

class _GlassTabBar extends StatelessWidget {
  static const _tabs = [
    (icon: Icons.home_rounded, label: 'Home', path: '/home'),
    (icon: Icons.chat_bubble_rounded, label: 'Chat', path: '/chat'),
    (icon: Icons.schedule_rounded, label: 'Crons', path: '/crons'),
    (icon: Icons.extension_rounded, label: 'Connect', path: '/integrations'),
    (icon: Icons.settings_rounded, label: 'Settings', path: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 8,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GlassTheme.radiusXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: HermesColors.glassFillMid,
              borderRadius: BorderRadius.circular(GlassTheme.radiusXl),
              border: Border.all(color: HermesColors.glassRimBright, width: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _tabs.map((tab) {
                final active = location.startsWith(tab.path);
                return Expanded(
                  child: GestureDetector(
                    onTap: () => context.go(tab.path),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active
                                  ? HermesColors.primary.withOpacity(0.2)
                                  : Colors.transparent,
                            ),
                            child: Icon(
                              tab.icon,
                              size: 22,
                              color: active
                                  ? HermesColors.primary
                                  : HermesColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                              color: active
                                  ? HermesColors.primary
                                  : HermesColors.textTertiary,
                            ),
                            child: Text(tab.label),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
