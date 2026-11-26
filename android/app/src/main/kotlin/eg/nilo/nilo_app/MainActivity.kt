package eg.nilo.nilo_app

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nilo/native").setMethodCallHandler { call, result ->
            if (call.method == "capture") {
                startActivity(Intent(this, CaptureActivity::class.java))
                result.success(true)
            } else if (call.method == "appinfo") {
                startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + packageName)))
                result.success(true)
            } else if (call.method == "a11y") {
                startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                result.success(true)
            } else if (call.method == "region") {
                // Country from the mobile network or SIM. No permission needed, no location, only a 2-letter code.
                val tm = getSystemService(android.content.Context.TELEPHONY_SERVICE) as? android.telephony.TelephonyManager
                var cc = tm?.networkCountryIso ?: ""
                if (cc.isEmpty()) cc = tm?.simCountryIso ?: ""
                result.success(cc.uppercase())
            } else result.notImplemented()
        }
    }
}
