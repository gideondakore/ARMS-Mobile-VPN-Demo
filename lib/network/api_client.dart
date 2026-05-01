import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/vpn_service.dart';

/// Intercepts every outbound request and blocks it until the VPN is connected.
/// This makes VPN logic completely invisible to the rest of the app —
/// just use [ApiClient.dio] normally and it handles the tunnel automatically.
class VpnInterceptor extends Interceptor {
  final VpnService _vpn;

  static const _timeoutSeconds = 30;
  static const _pollInterval = Duration(milliseconds: 500);

  VpnInterceptor(this._vpn);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_vpn.isConnected) {
      return handler.next(options);
    }

    int elapsed = 0;
    while (!_vpn.isConnected) {
      await Future.delayed(_pollInterval);
      elapsed++;
      if (elapsed >= _timeoutSeconds * 2) {
        return handler.reject(
          DioException(
            requestOptions: options,
            message:
                'VPN did not connect within $_timeoutSeconds seconds. '
                'Cannot reach private API.',
            type: DioExceptionType.connectionTimeout,
          ),
        );
      }
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.unknown) {
      handler.next(
        DioException(
          requestOptions: err.requestOptions,
          message: 'Network error. Check VPN connection: ${err.message}',
          type: err.type,
        ),
      );
    } else {
      handler.next(err);
    }
  }
}

/// Singleton Dio client pre-configured for your private VPC endpoints.
class ApiClient {
  ApiClient._();

  static Dio? _instance;

  static Dio init(
    VpnService vpnService, {
    String baseUrl = 'http://10.8.0.1:3000/api',
  }) {
    _instance = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _instance!.interceptors.addAll([
      VpnInterceptor(vpnService),
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('[API] $obj'),
      ),
    ]);

    return _instance!;
  }

  static Dio get instance {
    assert(
      _instance != null,
      'ApiClient.init() must be called before accessing instance',
    );
    return _instance!;
  }

  static void setAuthToken(String token) {
    _instance?.options.headers['Authorization'] = 'Bearer $token';
  }

  static void clearAuthToken() {
    _instance?.options.headers.remove('Authorization');
  }

  /// Convenience wrapper for GraphQL queries/mutations via the gateway.
  static Future<Map<String, dynamic>> graphQL(
    String query, {
    Map<String, dynamic>? variables,
  }) async {
    final response = await instance.post(
      '/graphql',
      data: {'query': query, 'variables': variables},
    );
    final body = response.data as Map<String, dynamic>;
    if (body['errors'] != null) {
      final errors = body['errors'] as List;
      throw Exception(errors.map((e) => e['message']).join('; '));
    }
    return body['data'] as Map<String, dynamic>;
  }
}
