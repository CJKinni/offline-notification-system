import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class CronJob {
  final String id;
  final String name;
  final String? description;
  final String schedule;
  final String? flowId;
  final String? agentId;
  final bool isActive;
  final int? lastRunAt;
  final int runCount;

  const CronJob({
    required this.id,
    required this.name,
    this.description,
    required this.schedule,
    this.flowId,
    this.agentId,
    required this.isActive,
    this.lastRunAt,
    required this.runCount,
  });

  factory CronJob.fromJson(Map<String, dynamic> j) => CronJob(
    id: j['id'] as String,
    name: j['name'] as String,
    description: j['description'] as String?,
    schedule: j['schedule'] as String,
    flowId: j['flow_id'] as String?,
    agentId: j['agent_id'] as String?,
    isActive: (j['is_active'] as int?) == 1,
    lastRunAt: (j['last_run_at'] as num?)?.toInt(),
    runCount: (j['run_count'] as num?)?.toInt() ?? 0,
  );
}

class CronsNotifier extends StateNotifier<AsyncValue<List<CronJob>>> {
  final ApiService api;
  final SocketService socket;

  CronsNotifier(this.api, this.socket) : super(const AsyncValue.loading()) {
    fetch();
    _listen();
  }

  void _listen() {
    socket.onCronFired((data) {
      // Refresh list when a cron fires
      fetch();
    });
  }

  Future<void> fetch() async {
    try {
      final data = await api.get('/crons');
      final list = (data['crons'] as List)
          .map((j) => CronJob.fromJson(j as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<String?> create(Map<String, dynamic> body) async {
    try {
      final res = await api.post('/crons', body);
      await fetch();
      return res['id'] as String?;
    } catch (_) { return null; }
  }

  Future<void> delete(String id) async {
    await api.delete('/crons/$id');
    await fetch();
  }

  Future<void> trigger(String id) async {
    await api.post('/crons/$id/trigger', {});
  }
}

final cronsProvider = StateNotifierProvider<CronsNotifier, AsyncValue<List<CronJob>>>(
  (ref) => CronsNotifier(ref.watch(apiServiceProvider), ref.watch(socketServiceProvider)),
);
