import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart';
import '../main.dart';
import '../network/api_client.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _apiResult = '';
  bool _apiLoading = false;

  // ── Test API call through the VPN tunnel ──────────────────────
  Future<void> _testApiCall() async {
    setState(() {
      _apiLoading = true;
      _apiResult = '';
    });

    try {
      // Replace '/health' with any real endpoint on your private server
      final response = await ApiClient.instance.get('/health');
      setState(() {
        _apiResult = '✓ ${response.statusCode} — ${response.data}';
      });
    } catch (e) {
      setState(() {
        _apiResult = '✗ $e';
      });
    } finally {
      setState(() => _apiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: vpnService,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildStatusCard(),
                  const SizedBox(height: 16),
                  if (vpnService.isConnected) ...[
                    _buildStatsRow(),
                    const SizedBox(height: 16),
                  ],
                  _buildTrafficInfo(),
                  const SizedBox(height: 16),
                  _buildApiTestCard(),
                  const SizedBox(height: 16),
                  if (vpnService.error != null) _buildErrorCard(),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _badge('AWS CLIENT VPN', const Color(0xFF00D4FF)),
            const SizedBox(width: 8),
            _badge('SPLIT TUNNEL', const Color(0xFF818CF8)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Company\nSecure Access',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Auto-connects on launch · Private API traffic only',
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
        ),
      ],
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ── Status Card ───────────────────────────────────────────────

  Widget _buildStatusCard() {
    final stage = vpnService.stage;
    final isConnected = vpnService.isConnected;
    final isBusy = vpnService.isBusy;

    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    if (isConnected) {
      statusColor = const Color(0xFF22C55E);
      statusLabel = 'CONNECTED';
      statusIcon = Icons.shield_rounded;
    } else if (isBusy) {
      statusColor = const Color(0xFFFBBF24);
      statusLabel =
          stage == VPNStage.disconnecting ? 'DISCONNECTING' : 'CONNECTING';
      statusIcon = Icons.sync_rounded;
    } else if (stage == VPNStage.error) {
      statusColor = const Color(0xFFEF4444);
      statusLabel = 'ERROR';
      statusIcon = Icons.error_outline_rounded;
    } else {
      statusColor = const Color(0xFF6B7280);
      statusLabel = 'DISCONNECTED';
      statusIcon = Icons.shield_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(isConnected ? 0.08 : 0.0),
            blurRadius: 24,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Icon with glow
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor.withOpacity(0.25)),
                ),
                child: Icon(statusIcon, color: statusColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _PulsingDot(
                            color: statusColor, animate: isBusy || isConnected),
                        const SizedBox(width: 8),
                        Text(
                          statusLabel,
                          style: GoogleFonts.jetBrainsMono(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vpnService.message,
                      style: GoogleFonts.inter(
                          color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'cvpn-endpoint-004837b1...us-west-2',
                      style: GoogleFonts.jetBrainsMono(
                          color: Colors.white24, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Connect / Disconnect button
          SizedBox(
            width: double.infinity,
            child: _ActionButton(
              label: isConnected
                  ? 'Disconnect'
                  : isBusy
                      ? vpnService.message
                      : 'Connect Now',
              color: isConnected
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF00D4FF),
              loading: isBusy,
              onTap: isBusy
                  ? null
                  : () => isConnected
                      ? vpnService.disconnect()
                      : vpnService.connect(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats Row ─────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'DATA IN',
            value: vpnService.bytesIn,
            color: const Color(0xFF00D4FF),
            icon: Icons.arrow_downward_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'DATA OUT',
            value: vpnService.bytesOut,
            color: const Color(0xFF818CF8),
            icon: Icons.arrow_upward_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'MODE',
            value: 'Split',
            color: const Color(0xFF22C55E),
            icon: Icons.call_split_rounded,
          ),
        ),
      ],
    );
  }

  // ── Traffic Info ──────────────────────────────────────────────

  Widget _buildTrafficInfo() {
    final isConnected = vpnService.isConnected;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SPLIT TUNNEL ROUTING',
            style: GoogleFonts.jetBrainsMono(
                color: Colors.white38, fontSize: 10, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          _RouteRow(
            icon: Icons.lock_rounded,
            label: '10.5.1.x private APIs',
            route: 'Through VPN tunnel',
            color: const Color(0xFF00D4FF),
            active: isConnected,
          ),
          const Divider(color: Colors.white10, height: 20),
          const _RouteRow(
            icon: Icons.public_rounded,
            label: 'All other traffic',
            route: 'Direct · ISP unaffected',
            color: Color(0xFF22C55E),
            active: true,
          ),
        ],
      ),
    );
  }

  // ── API Test Card ─────────────────────────────────────────────

  Widget _buildApiTestCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'API TEST',
            style: GoogleFonts.jetBrainsMono(
                color: Colors.white38, fontSize: 10, letterSpacing: 1.5),
          ),
          const SizedBox(height: 4),
          Text(
            'Calls http://10.8.0.1:3000/api/health through VPN',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 14),
          _ActionButton(
            label: 'Test Private API Call',
            color: const Color(0xFF818CF8),
            loading: _apiLoading,
            onTap: _apiLoading ? null : _testApiCall,
            icon: Icons.bolt_rounded,
          ),
          if (_apiResult.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _apiResult.startsWith('✓')
                    ? const Color(0xFF22C55E).withOpacity(0.08)
                    : const Color(0xFFEF4444).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _apiResult.startsWith('✓')
                      ? const Color(0xFF22C55E).withOpacity(0.25)
                      : const Color(0xFFEF4444).withOpacity(0.25),
                ),
              ),
              child: Text(
                _apiResult,
                style: GoogleFonts.jetBrainsMono(
                  color: _apiResult.startsWith('✓')
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEF4444),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Error Card ────────────────────────────────────────────────

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFEF4444), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              vpnService.error!,
              style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFFEF4444), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  REUSABLE WIDGETS
// ─────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback? onTap;
  final IconData? icon;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.loading,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color:
              onTap == null ? color.withOpacity(0.06) : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: onTap == null
                ? color.withOpacity(0.15)
                : color.withOpacity(0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else if (icon != null)
              Icon(icon, color: color, size: 18),
            if (!loading || icon != null) const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: color.withOpacity(0.6),
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final String label, route;
  final Color color;
  final bool active;

  const _RouteRow({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: active ? color : Colors.white24, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: active ? Colors.white70 : Colors.white38,
              fontSize: 13,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: active
                ? color.withOpacity(0.1)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            route,
            style: GoogleFonts.jetBrainsMono(
              color: active ? color : Colors.white24,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool animate;
  const _PulsingDot({required this.color, required this.animate});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  late final Animation<double> _anim =
      Tween(begin: 0.3, end: 1.0).animate(_ctrl);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color,
        boxShadow: [
          BoxShadow(color: widget.color.withOpacity(0.6), blurRadius: 6)
        ],
      ),
    );
    return widget.animate ? FadeTransition(opacity: _anim, child: dot) : dot;
  }
}
