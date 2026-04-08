import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class ChatMessage {
  final String id;
  final String role;
  final String content;
  final String? provider;
  final String? model;
  final bool isStreaming;
  final int createdAt;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.provider,
    this.model,
    this.isStreaming = false,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'] as String,
    role: j['role'] as String,
    content: j['content'] as String,
    provider: j['provider'] as String?,
    model: j['model'] as String?,
    createdAt: (j['created_at'] as num?)?.toInt() ?? 0,
  );

  ChatMessage copyWith({String? content, bool? isStreaming}) => ChatMessage(
    id: id, role: role,
    content: content ?? this.content,
    provider: provider, model: model,
    isStreaming: isStreaming ?? this.isStreaming,
    createdAt: createdAt,
  );
}

class Conversation {
  final String id;
  final String? title;
  final String agentId;
  final List<ChatMessage> messages;

  const Conversation({
    required this.id,
    this.title,
    required this.agentId,
    required this.messages,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
    id: j['id'] as String,
    title: j['title'] as String?,
    agentId: j['agent_id'] as String,
    messages: (j['messages'] as List? ?? [])
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList(),
  );
}

class ChatState {
  final List<Conversation> conversations;
  final String? activeConversationId;
  final bool isSending;
  final String streamingDelta;
  final int messageCount;

  const ChatState({
    this.conversations = const [],
    this.activeConversationId,
    this.isSending = false,
    this.streamingDelta = '',
    this.messageCount = 0,
  });

  Conversation? get active =>
      conversations.where((c) => c.id == activeConversationId).firstOrNull;

  ChatState copyWith({
    List<Conversation>? conversations,
    String? activeConversationId,
    bool? isSending,
    String? streamingDelta,
    int? messageCount,
  }) => ChatState(
    conversations: conversations ?? this.conversations,
    activeConversationId: activeConversationId ?? this.activeConversationId,
    isSending: isSending ?? this.isSending,
    streamingDelta: streamingDelta ?? this.streamingDelta,
    messageCount: messageCount ?? this.messageCount,
  );
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ApiService api;
  final SocketService socket;

  ChatNotifier(this.api, this.socket) : super(const ChatState()) {
    _listenToSocket();
  }

  void _listenToSocket() {
    socket.onStreamChunk((data) {
      final convoId = data['conversationId'] as String?;
      final delta = data['delta'] as String? ?? '';
      if (convoId == state.activeConversationId) {
        state = state.copyWith(streamingDelta: state.streamingDelta + delta);
      }
    });

    socket.onStreamDone((data) {
      final convoId = data['conversationId'] as String?;
      final content = data['content'] as String? ?? '';
      final messageId = data['messageId'] as String? ?? '';
      if (convoId == null) return;

      final updatedConvos = state.conversations.map((c) {
        if (c.id != convoId) return c;
        final msgs = List<ChatMessage>.from(c.messages);
        // Replace or add assistant message
        final idx = msgs.indexWhere((m) => m.id == messageId);
        final msg = ChatMessage(
          id: messageId, role: 'assistant', content: content,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        if (idx >= 0) msgs[idx] = msg; else msgs.add(msg);
        return Conversation(id: c.id, title: c.title, agentId: c.agentId, messages: msgs);
      }).toList();

      state = state.copyWith(
        conversations: updatedConvos,
        isSending: false,
        streamingDelta: '',
      );
    });
  }

  Future<void> loadConversations() async {
    try {
      final data = await api.get('/conversations');
      // Just store summaries — full messages loaded on open
    } catch (_) {}
  }

  Future<String?> createConversation(String agentId) async {
    try {
      final res = await api.post('/conversations', {'agent_id': agentId});
      final id = res['id'] as String;
      final convo = Conversation(id: id, agentId: agentId, messages: const []);
      state = state.copyWith(
        conversations: [convo, ...state.conversations],
        activeConversationId: id,
      );
      return id;
    } catch (_) { return null; }
  }

  Future<void> openConversation(String id) async {
    try {
      final data = await api.get('/conversations/$id');
      final convo = Conversation.fromJson(data);
      final idx = state.conversations.indexWhere((c) => c.id == id);
      final updated = List<Conversation>.from(state.conversations);
      if (idx >= 0) updated[idx] = convo; else updated.insert(0, convo);
      state = state.copyWith(conversations: updated, activeConversationId: id);
    } catch (_) {}
  }

  Future<void> sendMessage(String content) async {
    final convoId = state.activeConversationId;
    if (convoId == null || content.trim().isEmpty) return;

    // Optimistically add user message
    final userMsg = ChatMessage(
      id: 'tmp_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user', content: content,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    final updatedConvos = state.conversations.map((c) {
      if (c.id != convoId) return c;
      return Conversation(
        id: c.id, title: c.title, agentId: c.agentId,
        messages: [...c.messages, userMsg],
      );
    }).toList();

    state = state.copyWith(
      conversations: updatedConvos,
      isSending: true,
      streamingDelta: '',
      messageCount: state.messageCount + 1,
    );

    try {
      // REST call triggers agent + streams via socket
      await api.post('/conversations/$convoId/messages', {'content': content});
    } catch (e) {
      state = state.copyWith(isSending: false);
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref.watch(apiServiceProvider), ref.watch(socketServiceProvider));
});
