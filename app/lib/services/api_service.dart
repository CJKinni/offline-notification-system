import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  late final Dio _dio;
  static const _storage = FlutterSecureStorage();

  ApiService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (opts, handler) async {
        final url = await _storage.read(key: 'server_url');
        final token = await _storage.read(key: 'server_token');
        if (url != null) {
          opts.baseUrl = '$url/api/v1';
        }
        if (token != null) {
          opts.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(opts);
      },
    ));
  }

  Future<Map<String, dynamic>> get(String path) async {
    final res = await _dio.get<Map<String, dynamic>>(path);
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final res = await _dio.post<Map<String, dynamic>>(path, data: body);
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final res = await _dio.put<Map<String, dynamic>>(path, data: body);
    return res.data ?? {};
  }

  Future<void> delete(String path) async {
    await _dio.delete(path);
  }
}

final apiServiceProvider = Provider<ApiService>((_) => ApiService());
