import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart';

/// Wraps openvpn_flutter for AWS Client VPN with certificate-only auth.
/// Reads the inline .ovpn config from app assets at connection time.
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

  String get bytesIn =>
      _formatBytes(int.tryParse(_vpnStatus?.byteIn?.replaceAll(',', '') ?? '0') ?? 0);

  String get bytesOut =>
      _formatBytes(int.tryParse(_vpnStatus?.byteOut?.replaceAll(',', '') ?? '0') ?? 0);

  // ── Lifecycle ─────────────────────────────────────────────────

  /// Must be called once before connect().
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _openVPN = OpenVPN(
        onVpnStatusChanged: _onStatusChanged,
        onVpnStageChanged: _onStageChanged,
      );

      await _openVPN.initialize(
        groupIdentifier: 'group.com.yourcompany.vpnapp',
        providerBundleIdentifier: 'com.yourcompany.vpnapp.VPNExtension',
        localizedDescription: 'Company VPN',
      );

      _initialized = true;
    } catch (e) {
      _error = 'VPN init failed: $e';
      _message = 'VPN unavailable on this device';
      notifyListeners();
    }
  }

  Future<void> connect() async {
    if (!_initialized) await initialize();
    if (!_initialized || isConnected || isBusy) return;

    _error = null;

    try {
      final config = await rootBundle.loadString('assets/mobile_client.ovpn');
      await _openVPN.connect(
        config,
        'Company VPN',
        certIsRequired: true,
      );
    } catch (e) {
      _error = e.toString();
      _message = 'Failed to start VPN';
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (!isConnected && !isBusy) return;
    _openVPN.disconnect();
  }

  // ── Private callbacks ─────────────────────────────────────────

  void _onStageChanged(VPNStage stage, String message) {
    _stage = stage;
    _message = _labelFor(stage);
    // Clear error on successful transitions
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
