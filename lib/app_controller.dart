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
  //
  // Mirrors the trying_flutter pattern that's known to work on real
  // Android devices: initialize the OpenVPN library, kick off the
  // connection without awaiting it, and let the UI be reactive.
  //
  // Why not await the connection here? The native callbacks fire on
  // the platform thread and any async work between initialize() and
  // connect() can leave the library reporting a stale "unknown" stage,
  // which silently blocks subsequent connect() calls.
  //
  // The VpnInterceptor in api_client.dart blocks every API request
  // until the tunnel is up, so the rest of the app behaves as if VPN
  // connection were synchronous.

  Future<void> initialize() async {
    _set(AppState.initializing);
    _fatalError = null;

    try {
      await vpnService.initialize();

      final token = await storage.getToken();
      final ovpn = await storage.getOvpnConfig();
      final savedUsername = await storage.getUsername();

      final hasSession = token != null && ovpn != null && savedUsername != null;

      if (hasSession) {
        _username = savedUsername;
        ApiClient.setAuthToken(token);
        // Fire and forget — VpnInterceptor will gate API requests.
        unawaited(vpnService.connect(configOverride: ovpn));
        _set(AppState.authenticated);
      } else {
        unawaited(vpnService.connect());
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
      // 1. Authenticate. The VpnInterceptor blocks this request
      //    until the default VPN tunnel is up.
      final result = await auth.login(email, password);
      _username = result.username;

      // 2. Fetch the personalized .ovpn (still on the default tunnel).
      _set(AppState.fetchingConfig);
      final ovpn = await auth.fetchPersonalizedConfig();

      // 3. Persist session.
      await Future.wait([
        storage.saveToken(result.token),
        storage.saveUsername(result.username),
        storage.saveOvpnConfig(ovpn),
      ]);

      // 4. Swap to the personalized config and wait for it to come up
      //    before showing the home screen, so the dashboard's API calls
      //    fire over the right tunnel.
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
    _set(AppState.reconnecting);
    await vpnService.reconnectWith(defaultConfig);
    _set(AppState.login);
  }

  Future<void> retryAfterError() => initialize();

  // ── Helpers ───────────────────────────────────────────────────

  /// Waits up to [timeout] for the VPN to reach the connected state.
  /// Used after reconnectWith() so home-screen API calls don't fire
  /// before the personalized tunnel is fully established.
  Future<void> _awaitConnected({
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (kBypassVpn) return;
    if (vpnService.isConnected) return;

    final completer = Completer<void>();

    void listener() {
      if (completer.isCompleted) return;
      if (vpnService.isConnected) {
        completer.complete();
      } else if (vpnService.stage == VPNStage.error ||
          vpnService.error != null) {
        completer.completeError(
          Exception(vpnService.error ?? 'VPN connection failed'),
        );
      }
    }

    vpnService.addListener(listener);
    try {
      await completer.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'VPN did not connect within ${timeout.inSeconds}s.',
        ),
      );
    } finally {
      vpnService.removeListener(listener);
    }
  }

  String _friendlyError(Object e) {
    if (e is TimeoutException) {
      return 'Connection timed out. Check your network and try again.';
    }
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'Invalid email or password.';
    }
    if (msg.contains('VPN')) return msg;
    return 'Something went wrong. Please try again.';
  }

  void _set(AppState s) {
    _state = s;
    notifyListeners();
  }
}
