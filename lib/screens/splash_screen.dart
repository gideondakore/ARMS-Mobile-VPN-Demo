import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_controller.dart';
import '../main.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: appController,
          builder: (context, _) {
            final (label, sub) = _labels(appController.state);
            return Column(
              children: [
                const Spacer(flex: 2),
                // Logo / icon
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4FF).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Color(0xFF00D4FF),
                    size: 42,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'ARMS Mobile',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Secure enterprise access',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                ),
                const Spacer(flex: 2),
                // Status area
                Column(
                  children: [
                    _PulsingShield(state: appController.state),
                    const SizedBox(height: 20),
                    Text(
                      label,
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sub,
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // VPN stage message from the service itself
                ListenableBuilder(
                  listenable: vpnService,
                  builder: (context, _) {
                    return Text(
                      vpnService.message,
                      style: GoogleFonts.jetBrainsMono(
                        color: Colors.white24,
                        fontSize: 11,
                      ),
                    );
                  },
                ),
                const Spacer(),
              ],
            );
          },
        ),
      ),
    );
  }

  (String, String) _labels(AppState state) => switch (state) {
    AppState.initializing => ('Starting up', 'Preparing secure environment…'),
    AppState.reconnecting => (
      'Activating access',
      'Connecting with your personalized config…',
    ),
    AppState.fetchingConfig => (
      'Setting up access',
      'Generating your personalized VPN config…',
    ),
    _ => ('Please wait', ''),
  };
}

class _PulsingShield extends StatefulWidget {
  const _PulsingShield({required this.state});
  final AppState state;

  @override
  State<_PulsingShield> createState() => _PulsingShieldState();
}

class _PulsingShieldState extends State<_PulsingShield>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween(
    begin: 0.95,
    end: 1.05,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF00D4FF).withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF00D4FF).withValues(alpha: 0.25),
          ),
        ),
        child: const Icon(
          Icons.lock_outline_rounded,
          color: Color(0xFF00D4FF),
          size: 26,
        ),
      ),
    );
  }
}
