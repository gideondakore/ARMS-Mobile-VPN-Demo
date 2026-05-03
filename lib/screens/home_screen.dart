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
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _clocking;
  Map<String, dynamic>? _leaveBalance;
  List<dynamic>? _recentLeaves;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.instance.get('/employee/profile'),
        ApiClient.instance.get('/clocking/today'),
        ApiClient.instance.get('/leaves/balance'),
        ApiClient.instance.get('/leaves/recent'),
      ]);
      setState(() {
        _profile = results[0].data as Map<String, dynamic>;
        _clocking = results[1].data as Map<String, dynamic>;
        _leaveBalance = results[2].data as Map<String, dynamic>;
        _recentLeaves = results[3].data as List<dynamic>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load dashboard data.\n${e.toString()}';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? _buildLoader()
            : _error != null
            ? _buildErrorView()
            : _buildDashboard(context),
      ),
    );
  }

  // ── States ────────────────────────────────────────────────────

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFF00D4FF)),
          const SizedBox(height: 16),
          Text(
            'Loading dashboard…',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFFEF4444),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadDashboard,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: const Color(0xFF00D4FF),
      backgroundColor: const Color(0xFF111827),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(context),
            const SizedBox(height: 24),
            _buildProfileCard(),
            const SizedBox(height: 14),
            _buildVpnBadge(),
            const SizedBox(height: 20),
            _buildAttendanceCard(),
            const SizedBox(height: 14),
            _buildSectionLabel('LEAVE BALANCE'),
            const SizedBox(height: 10),
            _buildLeaveBalanceRow(),
            const SizedBox(height: 20),
            _buildSectionLabel('RECENT LEAVE REQUESTS'),
            const SizedBox(height: 10),
            _buildRecentLeaves(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        _chip('ARMS MOBILE', const Color(0xFF00D4FF)),
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

  // ── Profile card ──────────────────────────────────────────────

  Widget _buildProfileCard() {
    final name = _profile?['name'] as String? ?? appController.username ?? '';
    final position = _profile?['position'] as String? ?? '';
    final dept = _profile?['department'] as String? ?? '';
    final empId = _profile?['employeeId'] as String? ?? '';
    final initials = name
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
            const Color(0xFF818CF8).withValues(alpha: 0.07),
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
            radius: 30,
            backgroundColor: const Color(0xFF00D4FF).withValues(alpha: 0.15),
            child: Text(
              initials,
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0xFF00D4FF),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  position,
                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  dept,
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  empId,
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF00D4FF).withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── VPN status badge ──────────────────────────────────────────

  Widget _buildVpnBadge() {
    return ListenableBuilder(
      listenable: vpnService,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF22C55E).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF22C55E),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Personalized VPN active · split-tunnel routing',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF22C55E),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Attendance card ───────────────────────────────────────────

  Widget _buildAttendanceCard() {
    final status = _clocking?['status'] as String? ?? 'not_clocked_in';
    final clockIn = _clocking?['clockIn'] as String?;
    final hours = _clocking?['hoursWorked'] as String?;
    final location = _clocking?['location'] as String?;
    final date = _clocking?['date'] as String? ?? '';

    final isClockedIn = status == 'clocked_in';
    final color = isClockedIn
        ? const Color(0xFF22C55E)
        : const Color(0xFF6B7280);
    final label = isClockedIn ? 'CLOCKED IN' : 'NOT CLOCKED IN';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time_rounded, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                "TODAY'S ATTENDANCE",
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              _chip(label, color),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _attendanceStat('DATE', date, const Color(0xFF00D4FF)),
              const SizedBox(width: 12),
              _attendanceStat(
                'CLOCK IN',
                clockIn ?? '--',
                const Color(0xFF22C55E),
              ),
              const SizedBox(width: 12),
              _attendanceStat(
                'HOURS',
                hours != null ? '${hours}h' : '--',
                const Color(0xFF818CF8),
              ),
            ],
          ),
          if (location != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: Colors.white24,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  location,
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _attendanceStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
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
      ),
    );
  }

  // ── Leave balance ─────────────────────────────────────────────

  Widget _buildLeaveBalanceRow() {
    if (_leaveBalance == null) return const SizedBox.shrink();

    final items = [
      ('annual', 'Annual', const Color(0xFF00D4FF)),
      ('sick', 'Sick', const Color(0xFFEF4444)),
      ('emergency', 'Emergency', const Color(0xFF818CF8)),
    ];

    return Row(
      children: items.expand((item) {
        final (key, label, color) = item;
        final data = _leaveBalance![key] as Map<String, dynamic>?;
        return [
          Expanded(
            child: _LeaveCard(
              label: label,
              remaining: data?['remaining'] as int? ?? 0,
              total: data?['total'] as int? ?? 0,
              color: color,
            ),
          ),
          if (key != 'emergency') const SizedBox(width: 10),
        ];
      }).toList(),
    );
  }

  // ── Recent leaves ─────────────────────────────────────────────

  Widget _buildRecentLeaves() {
    if (_recentLeaves == null || _recentLeaves!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Center(
          child: Text(
            'No recent leave requests',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: _recentLeaves!.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value as Map<String, dynamic>;
          return _LeaveRequestRow(
            item: item,
            showDivider: i < _recentLeaves!.length - 1,
          );
        }).toList(),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.jetBrainsMono(
        color: Colors.white38,
        fontSize: 10,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

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
          'You\'ll be disconnected from your personalized VPN and returned to the login screen.',
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
}

// ── Leave balance card ─────────────────────────────────────────

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({
    required this.label,
    required this.remaining,
    required this.total,
    required this.color,
  });

  final String label;
  final int remaining, total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Text(
            '$remaining',
            style: GoogleFonts.spaceGrotesk(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '/ $total days',
            style: GoogleFonts.jetBrainsMono(
              color: color.withValues(alpha: 0.55),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white38,
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Leave request row ─────────────────────────────────────────

class _LeaveRequestRow extends StatelessWidget {
  const _LeaveRequestRow({required this.item, required this.showDivider});

  final Map<String, dynamic> item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final status = item['status'] as String? ?? '';
    final (statusColor, statusLabel) = switch (status) {
      'approved' => (const Color(0xFF22C55E), 'Approved'),
      'pending' => (const Color(0xFFFBBF24), 'Pending'),
      'rejected' => (const Color(0xFFEF4444), 'Rejected'),
      _ => (const Color(0xFF6B7280), status),
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['type'] as String? ?? '',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item['from']}  →  ${item['to']}  ·  ${item['days']} day${(item['days'] as int) > 1 ? 's' : ''}',
                      style: GoogleFonts.jetBrainsMono(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.jetBrainsMono(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
      ],
    );
  }
}
