package eg.nilo.nilo_app

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

// Popup translator opened from the text-selection menu or the Share sheet of any app.
class TranslateActivity : Activity() {
    private val codes = arrayOf("ar", "ru", "en", "de", "fr", "it", "es", "pl", "uk", "tr")
    private val names = arrayOf("عربي مصري", "Русский", "English", "Deutsch", "Français", "Italiano", "Español", "Polski", "Українська", "Türkçe")
    private var src: String = ""
    private var clipMode = false
    private var loaded = false
    private lateinit var sp: Spinner
    private lateinit var orig: TextView
    private lateinit var res: TextView
    private lateinit var sub: TextView
    private var last = ""
    private var seq = 0

    override fun onCreate(b: Bundle?) {
        super.onCreate(b)
        var t: CharSequence? = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)
        if (t == null) t = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)
        src = (t ?: "").toString().trim()
        val dp = resources.displayMetrics.density
        val pad = (16 * dp).toInt()
        val root = LinearLayout(this)
        root.orientation = LinearLayout.VERTICAL
        root.setPadding(pad, pad, pad, pad)
        root.layoutDirection = View.LAYOUT_DIRECTION_RTL
        val title = TextView(this)
        title.text = "🌐 ترجمة نيلو"
        title.textSize = 18f
        root.addView(title)
        orig = TextView(this)
        orig.text = if (src.length > 400) src.substring(0, 400) + "…" else src
        orig.textSize = 14f
        orig.alpha = 0.7f
        orig.setPadding(0, pad / 2, 0, pad / 2)
        orig.layoutDirection = View.LAYOUT_DIRECTION_LTR
        root.addView(orig)
        sp = Spinner(this)
        sp.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, names)
        val prefs = getSharedPreferences("nilo_tr", Context.MODE_PRIVATE)
        clipMode = src.isEmpty()
        pickDefault()
        root.addView(sp)
        res = TextView(this)
        res.textSize = 20f
        res.setPadding(0, pad / 2, 0, pad / 2)
        res.setTextIsSelectable(true)
        sub = TextView(this)
        sub.textSize = 13f
        sub.alpha = 0.7f
        val sc = ScrollView(this)
        val inner = LinearLayout(this)
        inner.orientation = LinearLayout.VERTICAL
        inner.addView(res)
        inner.addView(sub)
        sc.addView(inner)
        root.addView(sc, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, (260 * dp).toInt()))
        val row = LinearLayout(this)
        row.gravity = Gravity.CENTER
        val cp = Button(this); cp.text = "📋 انسخ"
        cp.setOnClickListener {
            if (last.isNotEmpty()) {
                (getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("t", last))
                Toast.makeText(this, "اتنسخت", Toast.LENGTH_SHORT).show()
            }
        }
        val op = Button(this); op.text = "افتح المترجم"
        op.setOnClickListener {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://nilo-eg.vercel.app/translate.html?text=" + Uri.encode(src))))
            finish()
        }
        val cl = Button(this); cl.text = "إغلاق"
        cl.setOnClickListener { finish() }
        val ac = Button(this); ac.text = "فعّل الزر العايم"
        ac.setOnClickListener { startActivity(Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)) }
        row.addView(cp); row.addView(op); row.addView(cl)
        root.addView(ac)
        root.addView(row)
        setContentView(root)
        if (clipMode) { res.text = "بقرا الحافظة…"; }
        sp.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(p: AdapterView<*>?, v: View?, pos: Int, id: Long) {
                if (src.any { it in '\u0600'..'\u06FF' }) getSharedPreferences("nilo_tr", Context.MODE_PRIVATE).edit().putString("out", codes[pos]).apply()
                if (src.isNotEmpty()) go(codes[pos])
            }
            override fun onNothingSelected(p: AdapterView<*>?) {}
        }
    }

    private fun pickDefault() {
        val prefs = getSharedPreferences("nilo_tr", Context.MODE_PRIVATE)
        val hasAr = src.any { it in '\u0600'..'\u06FF' }
        val def = if (hasAr) prefs.getString("out", "ru") else "ar"
        sp.setSelection(codes.indexOf(def).coerceAtLeast(0))
    }

    override fun onWindowFocusChanged(f: Boolean) {
        super.onWindowFocusChanged(f)
        if (f && clipMode && !loaded) {
            loaded = true
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val t = cm.primaryClip?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.coerceToText(this)?.toString()?.trim() ?: ""
            if (t.isEmpty()) { res.text = "الحافظة فاضية. انسخ الرسالة الأول (اضغط مطولاً ← نسخ) وافتح تاني."; return }
            src = t
            orig.text = if (t.length > 400) t.substring(0, 400) + "…" else t
            pickDefault()
            go(codes[sp.selectedItemPosition])
        }
    }

    private fun go(to: String) {
        val my = ++seq
        res.text = "بترجم…"
        sub.text = ""
        Thread {
            var out = ""
            var note = ""
            try {
                val c = URL("https://nilo-eg.vercel.app/api/tr").openConnection() as HttpURLConnection
                c.requestMethod = "POST"
                c.connectTimeout = 15000
                c.readTimeout = 45000
                c.doOutput = true
                c.setRequestProperty("Content-Type", "application/json")
                val body = JSONObject().put("text", src.take(1800)).put("to", to).toString()
                c.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
                val s = (if (c.responseCode < 400) c.inputStream else c.errorStream).bufferedReader().readText()
                val j = JSONObject(s)
                out = j.optString("translation", "")
                if (out.isEmpty()) note = j.optString("error", "الترجمة مش متاحة دلوقتي")
                else note = (j.optString("rom", "") + " " + j.optString("note", "")).trim()
            } catch (e: Exception) { note = "مفيش اتصال بالنت" }
            runOnUiThread {
                if (my == seq) {
                    last = out
                    res.text = if (out.isEmpty()) "⚠ $note" else out
                    sub.text = if (out.isEmpty()) "" else note
                }
            }
        }.start()
    }
}
