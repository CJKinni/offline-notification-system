import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/connection_provider.dart';
import 'screens/connect_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/crons_screen.dart';
import 'screens/integrations_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/agent_editor_screen.dart';
import 'screens/cron_editor_screen.dart';
import 'widgets/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final connection = ref.watch(connectionProvider);

  return GoRouter(
    initialLocation: connection.isConnected ? '/home' : '/connect',
    redirect: (context, state) {
      final connected = ref.read(connectionProvider).isConnected;
      final onConnect = state.matchedLocation == '/connect';
      if (!connected && !onConnect) return '/connect';
      if (connected && onConnect) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/connect',
        builder: (ctx, _) => const ConnectScreen(),
      ),
      ShellRoute(
        builder: (ctx, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (ctx, _) => const HomeScreen()),
          GoRoute(
            path: '/chat',
            builder: (ctx, _) => const ChatScreen(),
            routes: [
              GoRoute(
                path: 'agent-editor',
                builder: (ctx, state) {
                  final id = state.uri.queryParameters['id'];
                  return AgentEditorScreen(agentId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/crons',
            builder: (ctx, _) => const CronsScreen(),
            routes: [
              GoRoute(
                path: 'editor',
                builder: (ctx, state) {
                  final id = state.uri.queryParameters['id'];
                  return CronEditorScreen(cronId: id);
                },
              ),
            ],
          ),
          GoRoute(path: '/integrations', builder: (ctx, _) => const IntegrationsScreen()),
          GoRoute(
            path: '/settings',
            builder: (ctx, _) => const SettingsScreen(),
            routes: [
              GoRoute(path: 'subscription', builder: (ctx, _) => const SubscriptionScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});
