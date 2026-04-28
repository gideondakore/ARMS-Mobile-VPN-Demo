import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/vpn_service.dart';
import 'network/api_client.dart';
import 'screens/home_screen.dart';

// Global instances — accessible throughout the app
final vpnService = VpnService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request VPN permission on Android before anything else.
  // Android shows a system dialog "Company VPN wants to set up a VPN connection"
  // This is a one-time prompt per device — cannot be bypassed.

  await [
    Permission.notification,
  ].request();

  // Wire up Dio with your private API base URL
  ApiClient.init(vpnService, baseUrl: 'http://10.8.0.1:3000/api');

  runApp(const VpnApp());
}

class VpnApp extends StatefulWidget {
  const VpnApp({super.key});

  @override
  State<VpnApp> createState() => _VpnAppState();
}

class _VpnAppState extends State<VpnApp> {
  @override
  void initState() {
    super.initState();
    // Auto-connect on launch — runs after first frame so UI is visible
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await vpnService.initialize();
      await vpnService.connect();
    });
  }

  @override
  void dispose() {
    vpnService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vpnService,
      builder: (context, _) {
        return MaterialApp(
          title: 'Company App',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0A0E1A),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00D4FF),
              surface: Color(0xFF111827),
            ),
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
