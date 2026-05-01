import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../network/api_client.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _apiLoading = false;
  String _apiResult = '';

  Future<void> _fetchEmployeeData() async {
    setState(() {
      _apiLoading = true;
      _apiResult = '';
    });
    try {
      // Example query — swap in real GraphQL fields from your gateway.
      final data = await ApiClient.graphQL('''
        query GetEmployee {
          employee {
            name
            department
            position
          }
        }
      ''');
      setState(() => _apiResult = '✓  ${data.toString()}');
    } catch (e) {
      setState(() => _apiResult = '✗  $e');
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 28),
                  _buildWelcomeCard(),
                  const SizedBox(height: 16),
                  _buildVpnStatusCard(),
                  const SizedBox(height: 16),
                  _buildStatsRow(),
                  const SizedBox(height: 16),
                  _buildApiCard(),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        _badge('ARMS MOBILE', const Color(0xFF00D4FF)),
        const Spacer(),
        IconButton(
          onPressed: () => _confirmLogout(context),
          icon: const Icon(
            Icons.logout_rounded,
            color: Colors.white38,
            size: 20,
          ),
          tooltip: 'Sign out',
        ),
      ],
    );
  }

  // ── Welcome ───────────────────────────────────────────────────

  Widget _buildWelcomeCard() {
    final username = appController.username ?? 'employee';
    final displayName = username.replaceAll('.', ' ');
    final initials = displayName
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D4FF).withValues(alpha: 0.12),
            const Color(0xFF818CF8).withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00D4FF).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF00D4FF).withValues(alpha: 0.15),
            child: Text(
              initials,
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0xFF00D4FF),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                _titleCase(displayName),
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$username@amalitech.com',
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── VPN status ────────────────────────────────────────────────

  Widget _buildVpnStatusCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Color(0xFF22C55E),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vpnService.message,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Personalized tunnel · split-tunnel routing',
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          _dot(const Color(0xFF22C55E)),
        ],
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'DATA IN',
            value: vpnService.bytesIn,
            color: const Color(0xFF00D4FF),
            icon: Icons.arrow_downward_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'DATA OUT',
            value: vpnService.bytesOut,
            color: const Color(0xFF818CF8),
            icon: Icons.arrow_upward_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'MODE',
            value: 'Split',
            color: const Color(0xFF22C55E),
            icon: Icons.call_split_rounded,
          ),
        ),
      ],
    );
  }

  // ── API test card ─────────────────────────────────────────────

  Widget _buildApiCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GRAPHQL GATEWAY',
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white38,
              fontSize: 10,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Query employee data via the internal API',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 14),
          _ActionButton(
            label: 'Fetch My Data',
            color: const Color(0xFF818CF8),
            loading: _apiLoading,
            icon: Icons.bolt_rounded,
            onTap: _apiLoading ? null : _fetchEmployeeData,
          ),
          if (_apiResult.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _apiResult.startsWith('✓')
                    ? const Color(0xFF22C55E).withValues(alpha: 0.07)
                    : const Color(0xFFEF4444).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _apiResult.startsWith('✓')
                      ? const Color(0xFF22C55E).withValues(alpha: 0.25)
                      : const Color(0xFFEF4444).withValues(alpha: 0.25),
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

  // ── Helpers ───────────────────────────────────────────────────

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sign out?',
          style: GoogleFonts.spaceGrotesk(color: Colors.white),
        ),
        content: Text(
          'You\'ll be disconnected from the personalized VPN and returned to the login screen.',
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              appController.logout();
            },
            child: Text(
              'Sign out',
              style: GoogleFonts.inter(color: const Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

  Widget _dot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
        ],
      ),
    );
  }

  String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

// ─── Shared sub-widgets ────────────────────────────────────────

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label, value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: color.withValues(alpha: 0.55),
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.loading,
    required this.onTap,
    this.icon,
  });

  final String label;
  final Color color;
  final bool loading;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
        decoration: BoxDecoration(
          color: onTap == null
              ? color.withValues(alpha: 0.05)
              : color.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: onTap == null
                ? color.withValues(alpha: 0.12)
                : color.withValues(alpha: 0.38),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else if (icon != null)
              Icon(icon, color: color, size: 17),
            const SizedBox(width: 8),
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
