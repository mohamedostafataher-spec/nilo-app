package eg.nilo.nilo_app

import android.content.Intent
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
            } else result.notImplemented()
        }
    }
}
