import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart';

import '../config.dart';

/// Wraps openvpn_flutter for AWS Client VPN with certificate-only auth.
/// Reads the inline .ovpn config from app assets at connection time.
///
/// All OpenVPN native calls are skipped when [kBypassVpn] is true so the
/// app can run on Android emulators (which crash on VpnService.prepare()).
class VpnService extends ChangeNotifier {
  late OpenVPN _openVPN;

  VPNStage _stage = VPNStage.disconnected;
  VpnStatus? _vpnStatus;
  String _message = 'Not connected';
  String? _error;
  bool _initialized = false;

  // ── Public state ──────────────────────────────────────────────

  VPNStage get stage => _stage;
  VpnStatus? get vpnStatus => _vpnStatus;
  String get message => _message;
  String? get error => _error;

  bool get isConnected => _stage == VPNStage.connected;

  bool get isBusy =>
      _stage == VPNStage.connecting ||
      _stage == VPNStage.disconnecting ||
      _stage == VPNStage.unknown;

  String get bytesIn => _formatBytes(
    int.tryParse(_vpnStatus?.byteIn?.replaceAll(',', '') ?? '0') ?? 0,
  );

  String get bytesOut => _formatBytes(
    int.tryParse(_vpnStatus?.byteOut?.replaceAll(',', '') ?? '0') ?? 0,
  );

  // ── Lifecycle ─────────────────────────────────────────────────

  /// Must be called once before connect().
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> initialize() async {
    if (_initialized) return;

    // Skip all native VPN calls in bypass mode — the emulator's
    // VpnService.prepare() invocation causes a hard native crash.
    if (kBypassVpn) {
      _initialized = true;
      _message = 'Bypass mode — no tunnel';
      notifyListeners();
      return;
    }

    try {
      debugPrint('[VPN] initialize() — creating OpenVPN instance');
      _openVPN = OpenVPN(
        onVpnStatusChanged: _onStatusChanged,
        onVpnStageChanged: _onStageChanged,
      );

      debugPrint('[VPN] initialize() — calling _openVPN.initialize()');
      await _openVPN.initialize(
        groupIdentifier: 'group.com.amalitech.arms_mobile_demo',
        providerBundleIdentifier: 'com.amalitech.arms_mobile_demo.VPNExtension',
        localizedDescription: 'ARMS VPN',
      );

      _initialized = true;
      debugPrint('[VPN] initialize() — DONE — stage=$_stage');
    } catch (e, st) {
      debugPrint('[VPN] initialize() FAILED: $e\n$st');
      _error = 'VPN init failed: $e';
      _message = 'VPN unavailable on this device';
      notifyListeners();
    }
  }

  /// Connects using [configOverride] if provided, otherwise reads the bundled
  /// default config from assets.
  Future<void> connect({String? configOverride}) async {
    debugPrint(
      '[VPN] connect() ENTER — kBypassVpn=$kBypassVpn _initialized=$_initialized stage=$_stage isConnected=$isConnected configOverride=${configOverride != null}',
    );
    if (kBypassVpn) return;
    if (!_initialized) await initialize();
    if (!_initialized) {
      debugPrint('[VPN] connect() ABORT — not initialized');
      return;
    }
    if (isConnected) {
      debugPrint('[VPN] connect() ABORT — already connected');
      return;
    }
    // Only block if a connection/disconnection is explicitly in progress.
    // VPNStage.unknown is a stale state the library may report after init
    // (especially on second launch when permission is already granted) and
    // must NOT prevent a fresh connect attempt.
    if (_stage == VPNStage.connecting || _stage == VPNStage.disconnecting) {
      debugPrint('[VPN] connect() ABORT — busy stage=$_stage');
      return;
    }

    _error = null;

    try {
      final config =
          configOverride ??
          await rootBundle.loadString('assets/mobile_client.ovpn');
      debugPrint(
        '[VPN] connect() — config loaded (${config.length} chars), calling native',
      );
      // NOTE: openvpn_flutter 1.3.4's `connect` method-channel handler
      // never calls result.success(), so awaiting this Future hangs
      // forever. We don't need the result — the actual connection
      // progress is reported via the stage EventChannel. Fire and
      // forget; consumers should listen for VPNStage.connected.
      unawaited(
        _openVPN.connect(config, 'ARMS VPN', certIsRequired: true).catchError((
          Object e,
          StackTrace st,
        ) {
          debugPrint('[VPN] _openVPN.connect FAILED: $e\n$st');
          _error = e.toString();
          _message = 'Failed to start VPN';
          notifyListeners();
        }),
      );
    } catch (e, st) {
      debugPrint('[VPN] connect() FAILED: $e\n$st');
      _error = e.toString();
      _message = 'Failed to start VPN';
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (kBypassVpn) return;
    if (!isConnected && !isBusy) return;
    _openVPN.disconnect();
  }

  /// Disconnects the active tunnel then reconnects with [configString].
  /// Used when swapping the default config for the personalized one.
  Future<void> reconnectWith(String configString) async {
    if (kBypassVpn) return;
    if (isConnected || isBusy) {
      _openVPN.disconnect();
      for (int i = 0; i < 40; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_stage == VPNStage.disconnected) break;
      }
    }
    await connect(configOverride: configString);
  }

  // ── Private callbacks ─────────────────────────────────────────

  void _onStageChanged(VPNStage stage, String message) {
    debugPrint('[VPN] stage callback — $stage ("$message")');
    _stage = stage;
    _message = _labelFor(stage);
    if (stage == VPNStage.connected) _error = null;
    notifyListeners();
  }

  void _onStatusChanged(VpnStatus? status) {
    _vpnStatus = status;
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────

  String _labelFor(VPNStage stage) {
    switch (stage) {
      case VPNStage.connected:
        return 'Connected · Tunnel active';
      case VPNStage.connecting:
        return 'Connecting to AWS VPN...';
      case VPNStage.disconnecting:
        return 'Disconnecting...';
      case VPNStage.disconnected:
        return 'Not connected';
      case VPNStage.error:
        return 'Connection error';
      case VPNStage.vpn_generate_config:
        return 'Generating config...';
      case VPNStage.wait_connection:
        return 'Waiting for connection...';
      case VPNStage.authenticating:
        return 'Authenticating with AWS...';
      case VPNStage.exiting:
        return 'Closing tunnel...';
      default:
        return stage.toString().split('.').last;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
