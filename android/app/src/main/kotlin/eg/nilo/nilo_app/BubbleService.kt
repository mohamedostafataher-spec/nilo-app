package eg.nilo.nilo_app

import android.accessibilityservice.AccessibilityService
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

// Floating bubble over any app. One tap reads the visible text and shows its translation.
class BubbleService : AccessibilityService() {
    private lateinit var wm: WindowManager
    private var bubble: TextView? = null
    private var panel: View? = null
    private val codes = arrayOf("ar", "en", "ru", "de", "fr", "it", "es", "pl", "uk", "tr")
    private val names = arrayOf("عربي", "English", "Русский", "Deutsch", "Français", "Italiano", "Español", "Polski", "Українська", "Türkçe")
    private var li = 0
    private var seq = 0
    private var lastOut = ""

    override fun onServiceConnected() {
        super.onServiceConnected()
        wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        li = codes.indexOf(getSharedPreferences("nilo_tr", Context.MODE_PRIVATE).getString("bub", "ar")).coerceAtLeast(0)
        addBubble()
    }

    override fun onAccessibilityEvent(e: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    override fun onDestroy() {
        super.onDestroy()
        try { bubble?.let { wm.removeView(it) } } catch (e: Exception) {}
        closePanel()
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    private fun lp(w: Int, h: Int, g: Int): WindowManager.LayoutParams {
        val p = WindowManager.LayoutParams(w, h, WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS, PixelFormat.TRANSLUCENT)
        p.gravity = g
        return p
    }

    private fun addBubble() {
        val b = TextView(this)
        b.text = "🌐"
        b.textSize = 24f
        b.gravity = Gravity.CENTER
        val bg = GradientDrawable()
        bg.shape = GradientDrawable.OVAL
        bg.setColor(Color.parseColor("#E61F9D6B"))
        b.background = bg
        val p = lp(dp(54), dp(54), Gravity.TOP or Gravity.START)
        p.x = 0
        p.y = dp(300)
        var sx = 0f; var sy = 0f; var ox = 0; var oy = 0; var moved = false
        b.setOnTouchListener { v, ev ->
            when (ev.action) {
                MotionEvent.ACTION_DOWN -> { sx = ev.rawX; sy = ev.rawY; ox = p.x; oy = p.y; moved = false }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (ev.rawX - sx).toInt(); val dy = (ev.rawY - sy).toInt()
                    if (Math.abs(dx) > dp(6) || Math.abs(dy) > dp(6)) moved = true
                    if (moved) { p.x = ox + dx; p.y = oy + dy; try { wm.updateViewLayout(v, p) } catch (e: Exception) {} }
                }
                MotionEvent.ACTION_UP -> if (!moved) translateScreen()
            }
            true
        }
        bubble = b
        wm.addView(b, p)
    }

    private fun collect(n: AccessibilityNodeInfo?, out: MutableList<String>) {
        if (n == null) return
        try {
            if (n.isVisibleToUser && !n.isPassword && !n.isEditable) {
                val t = n.text?.toString()?.trim()
                if (!t.isNullOrEmpty() && t.length > 1 && n.childCount == 0) out.add(t)
            }
            for (i in 0 until n.childCount) collect(n.getChild(i), out)
        } catch (e: Exception) {}
    }

    private fun translateScreen() {
        val lines = ArrayList<String>()
        collect(rootInActiveWindow, lines)
        val seen = LinkedHashSet<String>(lines)
        var txt = seen.joinToString("\n")
        if (txt.length > 1700) txt = txt.substring(txt.length - 1700)
        showPanel()
        val res = panel!!.findViewWithTag<TextView>("res")
        if (txt.isBlank()) { res.text = "مالقيتش نص على الشاشة. افتح الشات وجرب تاني."; return }
        go(txt, res)
    }

    private fun go(txt: String, res: TextView) {
        val my = ++seq
        res.text = "بترجم…"
        val to = codes[li]
        Thread {
            var out = ""
            var err = ""
            try {
                val c = URL("https://nilo-eg.vercel.app/api/tr").openConnection() as HttpURLConnection
                c.requestMethod = "POST"; c.connectTimeout = 15000; c.readTimeout = 45000; c.doOutput = true
                c.setRequestProperty("Content-Type", "application/json")
                c.outputStream.use { it.write(JSONObject().put("text", txt).put("to", to).put("lines", true).toString().toByteArray(Charsets.UTF_8)) }
                val s = (if (c.responseCode < 400) c.inputStream else c.errorStream).bufferedReader().readText()
                val j = JSONObject(s)
                out = j.optString("translation", "")
                if (out.isEmpty()) err = j.optString("error", "الترجمة مش متاحة دلوقتي")
            } catch (e: Exception) { err = "مفيش اتصال بالنت" }
            res.post { if (my == seq) { lastOut = out; res.text = if (out.isEmpty()) "⚠ $err" else out } }
        }.start()
    }

    private fun closePanel() {
        try { panel?.let { wm.removeView(it) } } catch (e: Exception) {}
        panel = null
    }

    private fun showPanel() {
        closePanel()
        val root = LinearLayout(this)
        root.orientation = LinearLayout.VERTICAL
        root.setPadding(dp(14), dp(12), dp(14), dp(10))
        root.layoutDirection = View.LAYOUT_DIRECTION_RTL
        val bg = GradientDrawable()
        bg.cornerRadius = dp(18).toFloat()
        bg.setColor(Color.parseColor("#F2101E36"))
        root.background = bg
        val head = TextView(this)
        head.text = "🌐 ترجمة نيلو"
        head.setTextColor(Color.WHITE)
        head.textSize = 15f
        root.addView(head)
        val res = TextView(this)
        res.tag = "res"
        res.setTextColor(Color.WHITE)
        res.textSize = 17f
        res.setTextIsSelectable(false)
        val sc = ScrollView(this)
        sc.addView(res)
        root.addView(sc, LinearLayout.LayoutParams(-1, dp(300)))
        val row = LinearLayout(this)
        row.gravity = Gravity.CENTER
        val lb = Button(this)
        lb.text = "إلى: " + names[li]
        lb.setOnClickListener {
            li = (li + 1) % codes.size
            getSharedPreferences("nilo_tr", Context.MODE_PRIVATE).edit().putString("bub", codes[li]).apply()
            lb.text = "إلى: " + names[li]
            translateAgain(res)
        }
        val cp = Button(this); cp.text = "📋"
        cp.setOnClickListener {
            if (lastOut.isNotEmpty()) {
                (getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("t", lastOut))
                Toast.makeText(this, "اتنسخت", Toast.LENGTH_SHORT).show()
            }
        }
        val x = Button(this); x.text = "✕"
        x.setOnClickListener { closePanel() }
        row.addView(lb); row.addView(cp); row.addView(x)
        root.addView(row)
        val p = lp(resources.displayMetrics.widthPixels - dp(24), WindowManager.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL)
        p.y = dp(24)
        p.flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
        panel = root
        wm.addView(root, p)
    }

    private fun translateAgain(res: TextView) {
        // The panel covers little of the chat; re-read the screen text with the new target language.
        val lines = ArrayList<String>()
        collect(rootInActiveWindow, lines)
        var txt = LinkedHashSet<String>(lines).joinToString("\n")
        if (txt.length > 1700) txt = txt.substring(txt.length - 1700)
        if (txt.isNotBlank()) go(txt, res)
    }
}
