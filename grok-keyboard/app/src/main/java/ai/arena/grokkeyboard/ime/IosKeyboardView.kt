package ai.arena.grokkeyboard.ime

import android.animation.ObjectAnimator
import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.View
import android.view.animation.AccelerateDecelerateInterpolator
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

class IosKeyboardView(context: Context, private val listener: Listener) : LinearLayout(context) {
    interface Listener {
        fun onText(text: String)
        fun onBackspace()
        fun onEnter()
        fun onSwitchKeyboard()
        fun onMicrophone()
    }

    private val dark = resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
    private val backgroundColor = Color.parseColor(if (dark) "#1C1C1E" else "#D1D3D9")
    private val keyColor = Color.parseColor(if (dark) "#636366" else "#FFFFFF")
    private val modifierColor = Color.parseColor(if (dark) "#3A3A3C" else "#ADB3BC")
    private val foreground = Color.parseColor(if (dark) "#FFFFFF" else "#000000")
    private val blue = Color.parseColor(if (dark) "#0A84FF" else "#007AFF")
    private var shifted = false
    private var symbols = false
    private lateinit var letterArea: LinearLayout
    private lateinit var mic: Button
    private lateinit var status: TextView
    private var pulse: ObjectAnimator? = null

    init {
        orientation = VERTICAL
        setPadding(dp(3), dp(8), dp(3), 0)
        setBackgroundColor(backgroundColor)
        renderKeys()
    }

    private fun renderKeys() {
        removeAllViews()
        letterArea = LinearLayout(context).apply { orientation = VERTICAL }
        addView(letterArea, LayoutParams(LayoutParams.MATCH_PARENT, 0, 1f))
        if (symbols) renderSymbolRows() else renderLetterRows()
        renderBottomRow()
        renderAccessoryInset()
    }

    private fun renderLetterRows() {
        addRow("qwertyuiop".map { it.toString() })
        addRow("asdfghjkl".map { it.toString() }, horizontalInset = 16)
        val row = newRow()
        row.addView(key("⇧", 1.35f, modifier = true) {
            shifted = !shifted
            renderKeys()
        })
        "zxcvbnm".forEach { char -> row.addView(characterKey(char.toString())) }
        row.addView(key("⌫", 1.35f, modifier = true) { listener.onBackspace() })
        letterArea.addView(row, weightedRowParams())
    }

    private fun renderSymbolRows() {
        addRow(listOf("1","2","3","4","5","6","7","8","9","0"))
        addRow(listOf("-","/",":",";","(",")","\$","&","@","\""))
        val row = newRow()
        row.addView(key("#+=", 1.35f, modifier = true) {})
        listOf(".",",","?","!","'").forEach { value -> row.addView(key(value) { listener.onText(value) }) }
        row.addView(key("⌫", 1.35f, modifier = true) { listener.onBackspace() })
        letterArea.addView(row, weightedRowParams())
    }

    private fun renderBottomRow() {
        val row = newRow()
        row.addView(key(if (symbols) "ABC" else "123", 1.5f, modifier = true) {
            symbols = !symbols; shifted = false; renderKeys()
        })
        row.addView(key("◉", 1.1f, modifier = true) { listener.onSwitchKeyboard() })
        row.addView(key("space", 4.4f) { listener.onText(" ") })
        row.addView(key("return", 2f, modifier = true) { listener.onEnter() })
        letterArea.addView(row, weightedRowParams())
    }

    private fun renderAccessoryInset() {
        val accessory = FrameLayout(context).apply {
            setPadding(dp(14), 0, dp(14), dp(5))
        }
        status = TextView(context).apply {
            text = ""
            textSize = 12f
            gravity = Gravity.CENTER
            setTextColor(if (dark) Color.LTGRAY else Color.DKGRAY)
        }
        accessory.addView(status, FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, dp(35)))
        mic = Button(context).apply {
            text = "🎙"
            textSize = 17f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(foreground)
            minWidth = 0; minHeight = 0
            setPadding(0, 0, 0, 0)
            background = rounded(modifierColor, 18f)
            setOnClickListener { animateTap(this); listener.onMicrophone() }
            setOnLongClickListener { listener.onMicrophone(); performHapticFeedback(HapticFeedbackConstants.LONG_PRESS); true }
        }
        accessory.addView(mic, FrameLayout.LayoutParams(dp(38), dp(34), Gravity.END or Gravity.TOP))
        addView(accessory, LayoutParams(LayoutParams.MATCH_PARENT, dp(40)))
    }

    fun showIdle() {
        pulse?.cancel(); pulse = null
        if (::mic.isInitialized) {
            mic.alpha = 1f; mic.scaleX = 1f; mic.scaleY = 1f
            mic.setTextColor(foreground)
            mic.background = rounded(modifierColor, 18f)
        }
        if (::status.isInitialized) status.text = ""
    }

    fun showRecording() {
        status.text = "Listening… tap to stop"
        mic.setTextColor(Color.WHITE)
        mic.background = rounded(Color.parseColor("#FF3B30"), 18f)
        pulse?.cancel()
        pulse = ObjectAnimator.ofFloat(mic, View.ALPHA, 1f, .42f).apply {
            duration = 700; repeatMode = ObjectAnimator.REVERSE; repeatCount = ObjectAnimator.INFINITE
            interpolator = AccelerateDecelerateInterpolator(); start()
        }
    }

    fun showProcessing() {
        pulse?.cancel(); mic.alpha = 1f
        status.text = "Transcribing…"
        mic.setTextColor(blue)
        mic.background = rounded(modifierColor, 18f)
    }

    fun showError(message: String) {
        showIdle(); status.text = message.take(52)
        Handler(Looper.getMainLooper()).postDelayed({ if (status.text == message.take(52)) status.text = "" }, 3500)
    }

    private fun addRow(values: List<String>, horizontalInset: Int = 0) {
        val row = newRow().apply { setPadding(dp(horizontalInset), 0, dp(horizontalInset), 0) }
        values.forEach { row.addView(characterKey(it)) }
        letterArea.addView(row, weightedRowParams())
    }

    private fun characterKey(value: String) = key(if (shifted) value.uppercase() else value.lowercase()) {
        listener.onText(if (shifted) value.uppercase() else value.lowercase())
        if (shifted) { shifted = false; renderKeys() }
    }

    private fun newRow() = LinearLayout(context).apply { orientation = HORIZONTAL; gravity = Gravity.CENTER }
    private fun weightedRowParams() = LayoutParams(LayoutParams.MATCH_PARENT, 0, 1f)

    private fun key(label: String, weight: Float = 1f, modifier: Boolean = false, action: () -> Unit): Button =
        Button(context).apply {
            text = label; textSize = if (label.length > 2) 14f else 22f
            setTextColor(foreground); isAllCaps = false; typeface = Typeface.create("sans", Typeface.NORMAL)
            gravity = Gravity.CENTER; minWidth = 0; minHeight = 0; setPadding(0, 0, 0, 0)
            background = rounded(if (modifier) modifierColor else keyColor, 5f)
            stateListAnimator = null
            setOnClickListener { performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP); animateTap(this); action() }
            layoutParams = LayoutParams(0, LayoutParams.MATCH_PARENT, weight).apply { setMargins(dp(3), dp(3), dp(3), dp(5)) }
        }

    private fun animateTap(view: View) {
        view.animate().scaleX(.92f).scaleY(.92f).setDuration(45).withEndAction {
            view.animate().scaleX(1f).scaleY(1f).setDuration(75).start()
        }.start()
    }
    private fun rounded(color: Int, radius: Float) = GradientDrawable().apply { setColor(color); cornerRadius = dp(radius.toInt()).toFloat() }
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
}
