import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class ConnectionState {
  final String? serverUrl;
  final String? token;
  final ConnectionStatus status;
  final String? errorMessage;

  const ConnectionState({
    this.serverUrl,
    this.token,
    this.status = ConnectionStatus.disconnected,
    this.errorMessage,
  });

  bool get isConnected => status == ConnectionStatus.connected;

  ConnectionState copyWith({
    String? serverUrl,
    String? token,
    ConnectionStatus? status,
    String? errorMessage,
  }) => ConnectionState(
    serverUrl: serverUrl ?? this.serverUrl,
    token: token ?? this.token,
    status: status ?? this.status,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

class ConnectionNotifier extends StateNotifier<ConnectionState> {
  static const _storage = FlutterSecureStorage();
  static const _urlKey = 'server_url';
  static const _tokenKey = 'server_token';

  ConnectionNotifier() : super(const ConnectionState()) {
    _load();
  }

  Future<void> _load() async {
    final url = await _storage.read(key: _urlKey);
    final token = await _storage.read(key: _tokenKey);
    if (url != null && token != null) {
      state = state.copyWith(
        serverUrl: url,
        token: token,
        status: ConnectionStatus.connected,
      );
    }
  }

  Future<bool> connect(String url, String token) async {
    state = state.copyWith(status: ConnectionStatus.connecting);
    try {
      // Test connection
      final uri = Uri.parse('$url/api/v1/auth/me');
      final response = await Future.any([
        _testConnection(uri, token),
        Future.delayed(const Duration(seconds: 8), () => false),
      ]);
      if (response) {
        await _storage.write(key: _urlKey, value: url);
        await _storage.write(key: _tokenKey, value: token);
        state = state.copyWith(
          serverUrl: url, token: token, status: ConnectionStatus.connected,
        );
        return true;
      }
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: 'Could not reach server. Check URL and token.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> _testConnection(Uri uri, String token) async {
    // Just returns true — real implementation uses Dio
    return true;
  }

  Future<void> disconnect() async {
    await _storage.delete(key: _urlKey);
    await _storage.delete(key: _tokenKey);
    state = const ConnectionState();
  }
}

final connectionProvider = StateNotifierProvider<ConnectionNotifier, ConnectionState>(
  (_) => ConnectionNotifier(),
);
