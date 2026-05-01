import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_controller.dart';
import 'network/api_client.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/vpn_service.dart';

// Global singletons — instantiated once, used throughout the widget tree.
late final VpnService vpnService;
late final AppController appController;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await [Permission.notification].request();

  vpnService = VpnService();
  final storage = StorageService();
  final auth = AuthService();

  appController = AppController(
    vpnService: vpnService,
    storage: storage,
    auth: auth,
  );

  ApiClient.init(vpnService, baseUrl: 'http://10.8.0.1:3000/api');

  runApp(const ArmsApp());

  // Start the boot sequence after the first frame so the splash is visible.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    appController.initialize();
  });
}

class ArmsApp extends StatelessWidget {
  const ArmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARMS Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D4FF),
          surface: Color(0xFF111827),
        ),
      ),
      home: ListenableBuilder(
        listenable: appController,
        builder: (context, _) {
          return switch (appController.state) {
            AppState.authenticated => const HomeScreen(),
            AppState.login || AppState.authenticating => const LoginScreen(),
            AppState.error => _ErrorScreen(
              message: appController.fatalError ?? 'Unknown error',
              onRetry: appController.retryAfterError,
            ),
            _ => const SplashScreen(),
          };
        },
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 56,
              ),
              const SizedBox(height: 20),
              Text(
                'Connection Failed',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
