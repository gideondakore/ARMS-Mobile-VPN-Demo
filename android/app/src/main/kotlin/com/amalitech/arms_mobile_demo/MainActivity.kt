package com.amalitech.arms_mobile_demo

import android.content.Intent
import id.laskarmedia.openvpn_flutter.OpenVPNFlutterPlugin
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Required by openvpn_flutter: forwards the VPN permission-dialog
    // result back into the plugin so vpnHelper.startVPN() actually runs.
    // Without this override the plugin shows the system VPN consent
    // dialog, the user accepts, and the tunnel is never started.
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        OpenVPNFlutterPlugin.connectWhileGranted(
            requestCode == 24 && resultCode == RESULT_OK
        )
        super.onActivityResult(requestCode, resultCode, data)
    }
}
