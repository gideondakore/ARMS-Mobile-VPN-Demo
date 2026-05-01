import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart';

import 'config.dart';
import 'network/api_client.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/vpn_service.dart';

enum AppState {
  initializing,
  connectingDefault,
  login,
  authenticating,
  fetchingConfig,
  reconnecting,
  authenticated,
  error,
}

class AppController extends ChangeNotifier {
  AppController({
    required this.vpnService,
    required this.storage,
    required this.auth,
  });

  final VpnService vpnService;
  final StorageService storage;
  final AuthService auth;

  AppState _state = AppState.initializing;
  String? _fatalError;
  String? _loginError;
  String? _username;

  AppState get state => _state;
  String? get fatalError => _fatalError;
  String? get loginError => _loginError;
  String? get username => _username;

  // ── Boot sequence ─────────────────────────────────────────────

  Future<void> initialize() async {
    _set(AppState.initializing);
    _fatalError = null;

    try {
      await vpnService.initialize();

      final token = await storage.getToken();
      final ovpn = await storage.getOvpnConfig();
      final savedUsername = await storage.getUsername();

      if (token != null && ovpn != null && savedUsername != null) {
        // Returning user — reconnect with their personalized config.
        _username = savedUsername;
        ApiClient.setAuthToken(token);
        _set(AppState.reconnecting);
        await vpnService.connect(configOverride: ovpn);
        await _awaitConnected();
        _set(AppState.authenticated);
      } else {
        // First launch — connect with the bundled default config.
        // The default config only grants access to the auth endpoint.
        _set(AppState.connectingDefault);
        await vpnService.connect();
        await _awaitConnected();
        _set(AppState.login);
      }
    } catch (e) {
      _fatalError = _friendlyError(e);
      _set(AppState.error);
    }
  }

  // ── Auth flow ─────────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    _loginError = null;
    _set(AppState.authenticating);

    try {
      // 1. Authenticate → JWT
      final result = await auth.login(email, password);
      _username = result.username;

      // 2. Fetch the personalized .ovpn with the fresh JWT
      _set(AppState.fetchingConfig);
      final ovpn = await auth.fetchPersonalizedConfig();

      // 3. Persist session
      await Future.wait([
        storage.saveToken(result.token),
        storage.saveUsername(result.username),
        storage.saveOvpnConfig(ovpn),
      ]);

      // 4. Swap VPN config — disconnect default, connect personalized
      _set(AppState.reconnecting);
      await vpnService.reconnectWith(ovpn);
      await _awaitConnected();

      _set(AppState.authenticated);
    } catch (e) {
      _loginError = _friendlyError(e);
      _set(AppState.login);
    }
  }

  Future<void> logout() async {
    _loginError = null;
    _username = null;

    await storage.clearAll();
    ApiClient.clearAuthToken();

    final defaultConfig = await rootBundle.loadString(
      'assets/mobile_client.ovpn',
    );
    _set(AppState.connectingDefault);
    await vpnService.reconnectWith(defaultConfig);
    await _awaitConnected();
    _set(AppState.login);
  }

  Future<void> retryAfterError() => initialize();

  // ── Helpers ───────────────────────────────────────────────────

  Future<void> _awaitConnected({
    Duration timeout = const Duration(seconds: 45),
  }) async {
    // Emulators cannot create TUN/TAP interfaces, so VPN never connects.
    // BYPASS_VPN=true skips the wait so the UI flow can be tested without
    // a real device. Never set this in production.
    if (kBypassVpn) return;

    final deadline = DateTime.now().add(timeout);

    // Brief pause so the library has time to kick off the connection.
    await Future.delayed(const Duration(milliseconds: 600));

    while (true) {
      if (vpnService.isConnected) return;

      if (vpnService.stage == VPNStage.error || vpnService.error != null) {
        throw Exception(vpnService.error ?? 'VPN connection failed');
      }

      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException(
          'VPN did not connect within ${timeout.inSeconds} seconds.',
        );
      }

      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'Invalid email or password.';
    }
    if (msg.contains('timed out') || msg is TimeoutException) {
      return 'Connection timed out. Check your network.';
    }
    if (msg.contains('VPN')) return msg;
    return 'Something went wrong. Please try again.';
  }

  void _set(AppState s) {
    _state = s;
    notifyListeners();
  }
}
