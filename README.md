# Company VPN Flutter App

AWS Client VPN · Certificate Auth · Split Tunnel · Android

---

## Project Structure

```
lib/
  main.dart                  ← App entry, auto-connect on launch
  services/
    vpn_service.dart         ← openvpn_flutter wrapper (real VPN logic)
  network/
    api_client.dart          ← Dio + VpnInterceptor
  screens/
    home_screen.dart         ← UI
assets/
  mobile_client.ovpn         ← Your inline .ovpn config (YOU MUST ADD THIS)
android/
  app/src/main/
    AndroidManifest.xml      ← VPN service declaration
```

---

## Step 1 — Generate your inline .ovpn (run on your laptop)

Your current clientconfig.ovpn uses external cert paths that don't work on mobile.
Convert to inline format:

```bash
# Strip the --cert and --key lines
cat clientconfig.ovpn | grep -v "^\-\-cert\|^\-\-key" > mobile_client.ovpn

# Embed the cert inline
echo "<cert>" >> mobile_client.ovpn
cat /home/gideon-dakore/easy-rsa/pki/issued/gideon.dakore.domain.tld.crt >> mobile_client.ovpn
echo "</cert>" >> mobile_client.ovpn

# Embed the key inline
echo "<key>" >> mobile_client.ovpn
cat /home/gideon-dakore/easy-rsa/pki/private/gideon.dakore.domain.tld.key >> mobile_client.ovpn
echo "</key>" >> mobile_client.ovpn
```

Verify the output:
```bash
cat mobile_client.ovpn
# Must contain: <ca>...</ca>  <cert>...</cert>  <key>...</key>
```

Then copy mobile_client.ovpn into the assets/ folder of this project.

---

## Step 2 — Update your App ID

Replace `com.yourcompany.vpnapp` in:
- android/app/build.gradle  → applicationId
- android/app/src/main/AndroidManifest.xml
- lib/services/vpn_service.dart (groupIdentifier — iOS only, can ignore for now)

---

## Step 3 — Update your API base URL

In lib/main.dart:
```dart
ApiClient.init(vpnService, baseUrl: 'http://10.5.1.YOUR_ACTUAL_IP/api');
```

---

## Step 4 — Install dependencies

```bash
flutter pub get
```

---

## Step 5 — Run on Android

```bash
# Connect Android device with USB debugging ON
# OR start an Android emulator

flutter run
```

On first launch, Android will show a system dialog:
  "Company VPN wants to set up a VPN connection"
  → Tap OK

This is a mandatory one-time OS prompt that cannot be bypassed.

---

## How it works

1. App launches → VpnService.initialize() + connect() fires automatically
2. OpenVPN reads mobile_client.ovpn from assets
3. OS creates a tun0 network interface and routes 10.5.1.x traffic through it
4. All other traffic (YouTube, social, etc.) goes through normal ISP — split tunnel
5. Dio interceptor blocks any API call until VPN is confirmed connected
6. Your private APIs at 10.5.1.x are now reachable from the mobile device

---

## Troubleshooting

| Issue | Fix |
|---|---|
| "TLS handshake failed" | Your .ovpn cert/key may be wrong or expired |
| "AUTH_FAILED" | Check that certIsRequired: true matches server config |
| App crashes on connect | Check AndroidManifest.xml has the OpenVPNService declaration |
| API timeout even when connected | Verify your base URL matches the VPN subnet IP |
| "VPN permission denied" | User must tap OK on the Android VPN dialog |
