import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../network/api_client.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _users = const [];
  List<dynamic> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.instance.get('/admin/users'),
        ApiClient.instance.get('/admin/sessions'),
      ]);
      setState(() {
        _users = results[0].data as List<dynamic>;
        _sessions = results[1].data as List<dynamic>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _regenerateCRL() async {
    _showSnack('Regenerating CRL…');
    try {
      await ApiClient.instance.post('/admin/crl/regenerate');
      _showSnack('CRL regenerated', success: true);
    } catch (e) {
      _showSnack('Failed: $e', error: true);
    }
  }

  Future<void> _revoke(String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text(
          'Revoke $username?',
          style: GoogleFonts.spaceGrotesk(color: Colors.white),
        ),
        content: Text(
          "This adds the user's certificate to the CRL, deletes their CCD "
          'policy, and kicks any active tunnel. They will be unable to '
          'reconnect until they sign in again.',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Revoke',
              style: GoogleFonts.inter(
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    _showSnack('Revoking $username…');
    try {
      await ApiClient.instance.post(
        '/admin/revoke',
        data: {'username': username},
      );
      _showSnack('$username revoked', success: true);
      await _loadAll();
    } catch (e) {
      _showSnack('Failed: $e', error: true);
    }
  }

  void _showSnack(String text, {bool success = false, bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error
            ? const Color(0xFFEF4444)
            : success
            ? const Color(0xFF22C55E)
            : const Color(0xFF111827),
        content: Text(
          text,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        elevation: 0,
        title: Text(
          'Admin Panel',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Reload',
            onPressed: _loadAll,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
              )
            : _error != null
            ? _buildError()
            : RefreshIndicator(
                onRefresh: _loadAll,
                color: const Color(0xFF00D4FF),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildCrlCard(),
                    const SizedBox(height: 20),
                    _buildSectionLabel('ACTIVE SESSIONS (${_sessions.length})'),
                    const SizedBox(height: 10),
                    if (_sessions.isEmpty)
                      _buildEmptyHint('No tunnels currently connected.')
                    else
                      ..._sessions.map(_buildSessionCard),
                    const SizedBox(height: 24),
                    _buildSectionLabel('ALL USERS (${_users.length})'),
                    const SizedBox(height: 10),
                    ..._users.map(_buildUserCard),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF4444),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load admin data',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadAll, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.jetBrainsMono(
        color: Colors.white38,
        fontSize: 10,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildEmptyHint(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
      ),
    );
  }

  Widget _buildCrlCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF818CF8).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF818CF8).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF818CF8).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF818CF8),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Certificate Revocation List',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Refresh the CRL distributed to OpenVPN.',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _regenerateCRL,
            child: Text(
              'Regenerate',
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0xFF818CF8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(dynamic raw) {
    final s = raw as Map<String, dynamic>;
    final tunnelIp = s['tunnelIp'] as String? ?? '-';
    final cn = s['commonName'] as String? ?? '-';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF22C55E).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF22C55E),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              cn,
              style: GoogleFonts.jetBrainsMono(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            tunnelIp,
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(dynamic raw) {
    final u = raw as Map<String, dynamic>;
    final name = u['name'] as String? ?? '';
    final username = u['username'] as String? ?? '';
    final position = u['position'] as String? ?? '';
    final department = u['department'] as String? ?? '';
    final isAdmin = u['isAdmin'] as bool? ?? false;
    final certIssued = u['certIssued'] as bool? ?? false;
    final ccdActive = u['ccdActive'] as bool? ?? false;
    final canRevoke = certIssued && !isAdmin;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 6),
                          _tag('ADMIN', const Color(0xFF818CF8)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$position · $department',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      username,
                      style: GoogleFonts.jetBrainsMono(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (canRevoke)
                TextButton(
                  onPressed: () => _revoke(username),
                  child: Text(
                    'Revoke',
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Text(
                  isAdmin ? 'protected' : 'no cert',
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white24,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statusPill('cert', certIssued, certIssued ? 'issued' : 'none'),
              const SizedBox(width: 6),
              _statusPill('ccd', ccdActive, ccdActive ? 'active' : 'none'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _statusPill(String label, bool active, String value) {
    final color = active ? const Color(0xFF22C55E) : const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.jetBrainsMono(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
