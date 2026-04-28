# Trying Flutter VPN Demo

## Overview

This project is a Flutter demo app that shows a basic VPN client flow. It includes
an example OpenVPN profile, a minimal API client, and a service layer for VPN
operations. The app targets Android, iOS, desktop, and web, but VPN functionality
is typically limited to mobile platforms.

## Features

- Basic Flutter app shell with a home screen.
- VPN service abstraction in the app layer.
- Example OpenVPN configuration asset.
- Android/iOS build scaffolding and platform plugins.

## Project Structure

- lib/main.dart: App entry point.
- lib/screens/home_screen.dart: Main UI screen.
- lib/services/vpn_service.dart: VPN interaction layer.
- lib/network/api_client.dart: API helper for network calls.
- assets/mobile_client.ovpn: Example OpenVPN profile asset.

## Requirements

- Flutter SDK (stable channel).
- Dart SDK (bundled with Flutter).
- Android Studio or Xcode (for mobile builds).
- A real VPN profile if you want to connect (do not use the example in production).

## Setup

1. Install Flutter and confirm the environment:
   flutter doctor

2. Fetch dependencies:
   flutter pub get

3. Run the app:
   flutter run

## Platform Notes

- Android: Ensure you have a device or emulator with VPN support.
- iOS: VPN entitlements and provisioning are required to test on device.
- Desktop/Web: VPN functionality is typically not supported.

## Configuration

- The OpenVPN profile is stored at assets/mobile_client.ovpn.
- Replace the example profile with a valid one before testing real connections.

## Security Notes

- Do not commit real VPN credentials or secrets.
- Treat the sample profile as a placeholder only.

## Development Tips

- Keep network and VPN operations in lib/services for clean separation.
- Use environment-specific config for API endpoints if needed.

## Troubleshooting

- If the app fails to connect, verify the VPN profile and platform permissions.
- Run flutter doctor to ensure the toolchain is configured correctly.

## License

Add your license details here.
