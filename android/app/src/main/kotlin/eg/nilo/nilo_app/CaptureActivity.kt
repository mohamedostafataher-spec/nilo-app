package eg.nilo.nilo_app

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.widget.Toast

// Asks for the permissions, then starts recording the device's playback audio.
class CaptureActivity : Activity() {
    override fun onCreate(b: Bundle?) {
        super.onCreate(b)
        if (Build.VERSION.SDK_INT < 29) {
            Toast.makeText(this, "تسجيل صوت التطبيقات محتاج أندرويد 10 أو أحدث", Toast.LENGTH_LONG).show()
            finish(); return
        }
        val need = ArrayList<String>()
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) need.add(Manifest.permission.RECORD_AUDIO)
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) need.add(Manifest.permission.POST_NOTIFICATIONS)
        if (need.isNotEmpty()) requestPermissions(need.toTypedArray(), 1) else ask()
    }

    override fun onRequestPermissionsResult(rc: Int, p: Array<out String>, r: IntArray) {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) ask()
        else { Toast.makeText(this, "من غير إذن الميكروفون مش هيشتغل", Toast.LENGTH_LONG).show(); finish() }
    }

    private fun ask() {
        val m = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(m.createScreenCaptureIntent(), 7)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(rq: Int, rs: Int, d: Intent?) {
        super.onActivityResult(rq, rs, d)
        if (rq == 7 && rs == RESULT_OK && d != null) {
            val i = Intent(this, AudioCaptureService::class.java).putExtra("rc", rs).putExtra("data", d)
            startForegroundService(i)
            Toast.makeText(this, "بسجّل صوت الجهاز. افتح الفويس وشغّله، وبعدها من الإشعار دوس: إيقاف وترجمة", Toast.LENGTH_LONG).show()
        } else Toast.makeText(this, "اتلغى", Toast.LENGTH_SHORT).show()
        finish()
    }
}
