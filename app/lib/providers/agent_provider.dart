import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

class Agent {
  final String id;
  final String name;
  final String? description;
  final String provider;
  final String model;
  final String? fallbackProvider;
  final String? fallbackModel;
  final int createdAt;

  const Agent({
    required this.id,
    required this.name,
    this.description,
    required this.provider,
    required this.model,
    this.fallbackProvider,
    this.fallbackModel,
    required this.createdAt,
  });

  factory Agent.fromJson(Map<String, dynamic> j) => Agent(
    id: j['id'] as String,
    name: j['name'] as String,
    description: j['description'] as String?,
    provider: j['provider'] as String,
    model: j['model'] as String,
    fallbackProvider: j['fallback_provider'] as String?,
    fallbackModel: j['fallback_model'] as String?,
    createdAt: (j['created_at'] as num?)?.toInt() ?? 0,
  );
}

class AgentsNotifier extends StateNotifier<AsyncValue<List<Agent>>> {
  final ApiService api;

  AgentsNotifier(this.api) : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final data = await api.get('/agents');
      final list = (data['agents'] as List)
          .map((j) => Agent.fromJson(j as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<String?> create(Map<String, dynamic> body) async {
    try {
      final res = await api.post('/agents', body);
      await fetch();
      return res['id'] as String?;
    } catch (_) { return null; }
  }

  Future<void> delete(String id) async {
    await api.delete('/agents/$id');
    await fetch();
  }
}

final agentsProvider = StateNotifierProvider<AgentsNotifier, AsyncValue<List<Agent>>>(
  (ref) => AgentsNotifier(ref.watch(apiServiceProvider)),
);

final activeAgentIdProvider = StateProvider<String?>((ref) => null);

final activeAgentProvider = Provider<Agent?>((ref) {
  final id = ref.watch(activeAgentIdProvider);
  final agents = ref.watch(agentsProvider).valueOrNull ?? [];
  if (id == null) return agents.isEmpty ? null : agents.first;
  return agents.where((a) => a.id == id).firstOrNull;
});
