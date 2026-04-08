import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  io.Socket? _socket;
  static const _storage = FlutterSecureStorage();

  Future<void> connect() async {
    final url = await _storage.read(key: 'server_url');
    final token = await _storage.read(key: 'server_token');
    if (url == null || token == null) return;

    _socket = io.io(url, io.OptionBuilder()
      .setTransports(['websocket'])
      .setAuth({'token': token})
      .enableAutoConnect()
      .enableReconnection()
      .setReconnectionAttempts(10)
      .build());

    _socket!.onConnect((_) => print('[Socket] Connected'));
    _socket!.onDisconnect((_) => print('[Socket] Disconnected'));
    _socket!.onConnectError((e) => print('[Socket] Error: $e'));
  }

  void disconnect() => _socket?.disconnect();

  void onStreamChunk(void Function(Map<String, dynamic>) handler) {
    _socket?.on('stream:chunk', (data) {
      if (data is Map<String, dynamic>) handler(data);
    });
  }

  void onStreamDone(void Function(Map<String, dynamic>) handler) {
    _socket?.on('stream:done', (data) {
      if (data is Map<String, dynamic>) handler(data);
    });
  }

  void onStreamError(void Function(Map<String, dynamic>) handler) {
    _socket?.on('stream:error', (data) {
      if (data is Map<String, dynamic>) handler(data);
    });
  }

  void onCronFired(void Function(Map<String, dynamic>) handler) {
    _socket?.on('cron:fired', (data) {
      if (data is Map<String, dynamic>) handler(data);
    });
  }

  void onFlowUpdate(void Function(Map<String, dynamic>) handler) {
    _socket?.on('flow:update', (data) {
      if (data is Map<String, dynamic>) handler(data);
    });
  }

  bool get isConnected => _socket?.connected ?? false;
}

final socketServiceProvider = Provider<SocketService>((_) {
  final svc = SocketService();
  svc.connect();
  return svc;
});
