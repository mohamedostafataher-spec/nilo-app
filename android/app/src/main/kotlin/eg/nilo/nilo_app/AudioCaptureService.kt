package eg.nilo.nilo_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import java.io.ByteArrayOutputStream
import java.io.File

// Records what other apps play (only apps that allow capture) until the user stops it.
class AudioCaptureService : Service() {
    private var rec: AudioRecord? = null
    private var proj: MediaProjection? = null
    private var th: Thread? = null
    private val buf = ByteArrayOutputStream()
    @Volatile private var run = false

    companion object {
        @Volatile var inst: AudioCaptureService? = null
        // 70 s max keeps the upload under the API size limit.
        const val MAX = 16000 * 2 * 70
        fun stopAndSave(): String? = inst?.saveAndStop()
    }

    override fun onBind(i: Intent?): IBinder? = null

    override fun onStartCommand(i: Intent?, f: Int, id: Int): Int {
        if (i == null || Build.VERSION.SDK_INT < 29) { stopSelf(); return START_NOT_STICKY }
        inst = this
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(NotificationChannel("nilo_cap", "تسجيل الصوت", NotificationManager.IMPORTANCE_LOW))
        val stop = Intent(this, TranslateActivity::class.java).putExtra("stop_capture", true).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val pi = PendingIntent.getActivity(this, 1, stop, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        @Suppress("DEPRECATION")
        val n = Notification.Builder(this, "nilo_cap")
            .setContentTitle("نيلو بيسجّل صوت الجهاز")
            .setContentText("شغّل الفويس، وبعدين دوس إيقاف وترجمة")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pi)
            .setOngoing(true)
            .addAction(Notification.Action.Builder(0, "إيقاف وترجمة", pi).build())
            .build()
        startForeground(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        try {
            val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val p = mpm.getMediaProjection(i.getIntExtra("rc", 0), i.getParcelableExtra("data")!!)
            p.registerCallback(object : MediaProjection.Callback() {}, null)
            proj = p
            val cfg = AudioPlaybackCaptureConfiguration.Builder(p)
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
                .addMatchingUsage(AudioAttributes.USAGE_GAME)
                .build()
            val fmt = AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT).setSampleRate(16000).setChannelMask(AudioFormat.CHANNEL_IN_MONO).build()
            val r = AudioRecord.Builder().setAudioPlaybackCaptureConfig(cfg).setAudioFormat(fmt).setBufferSizeInBytes(16000 * 2 * 2).build()
            rec = r
            r.startRecording()
            run = true
            th = Thread {
                val b = ByteArray(4096)
                while (run && buf.size() < MAX) {
                    val n2 = r.read(b, 0, b.size)
                    if (n2 > 0) synchronized(buf) { buf.write(b, 0, n2) } else if (n2 < 0) break
                }
            }.also { it.start() }
        } catch (e: Exception) { cleanup(); stopSelf() }
        return START_NOT_STICKY
    }

    @Synchronized
    fun saveAndStop(): String? {
        run = false
        try { th?.join(1500) } catch (e: Exception) {}
        val pcm = synchronized(buf) { buf.toByteArray() }
        cleanup()
        stopSelf()
        if (pcm.size < 16000) return null
        val f = File(cacheDir, "cap.wav")
        f.outputStream().use { o ->
            val len = pcm.size
            val h = java.nio.ByteBuffer.allocate(44).order(java.nio.ByteOrder.LITTLE_ENDIAN)
            h.put("RIFF".toByteArray()).putInt(36 + len).put("WAVE".toByteArray()).put("fmt ".toByteArray())
                .putInt(16).putShort(1).putShort(1).putInt(16000).putInt(32000).putShort(2).putShort(16)
                .put("data".toByteArray()).putInt(len)
            o.write(h.array()); o.write(pcm)
        }
        return f.absolutePath
    }

    private fun cleanup() {
        run = false
        try { rec?.stop() } catch (e: Exception) {}
        try { rec?.release() } catch (e: Exception) {}
        try { proj?.stop() } catch (e: Exception) {}
        rec = null; proj = null; inst = null
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    override fun onDestroy() { cleanup(); super.onDestroy() }
}
