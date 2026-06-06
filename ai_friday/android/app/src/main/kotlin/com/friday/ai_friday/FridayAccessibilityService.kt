package com.friday.ai_friday

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Универсальный сервис автоматизации Пятницы.
 * Видит содержимое экрана любого приложения и умеет печатать текст,
 * кликать по элементам (по тексту/описанию) и выполнять системные действия.
 */
class FridayAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile
        var instance: FridayAccessibilityService? = null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) { /* no-op */ }

    override fun onInterrupt() { /* no-op */ }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) instance = null
    }

    private fun collect(node: AccessibilityNodeInfo?, out: MutableList<AccessibilityNodeInfo>) {
        if (node == null) return
        out.add(node)
        for (i in 0 until node.childCount) {
            collect(node.getChild(i), out)
        }
    }

    private fun allNodes(): List<AccessibilityNodeInfo> {
        val out = mutableListOf<AccessibilityNodeInfo>()
        collect(rootInActiveWindow, out)
        return out
    }

    private fun clickableAncestor(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        var n = node
        var depth = 0
        while (n != null && depth < 7) {
            if (n.isClickable) return n
            n = n.parent
            depth++
        }
        return null
    }

    /** Печатает текст в сфокусированное (или первое) редактируемое поле. */
    fun setText(text: String): Boolean {
        val nodes = allNodes()
        val target = nodes.firstOrNull { it.isEditable && it.isFocused }
            ?: nodes.firstOrNull { it.isEditable }
            ?: return false
        val args = Bundle()
        args.putCharSequence(
            AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
            text
        )
        return target.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    /** Кликает по элементу, чьи text/описание содержат одну из меток. */
    fun clickByLabel(labels: List<String>): Boolean {
        if (labels.isEmpty()) return false
        val lowered = labels.map { it.lowercase() }
        for (n in allNodes()) {
            val t = (n.text?.toString() ?: "").lowercase()
            val d = (n.contentDescription?.toString() ?: "").lowercase()
            val match = lowered.any { lbl ->
                (t.isNotEmpty() && t.contains(lbl)) || (d.isNotEmpty() && d.contains(lbl))
            }
            if (match) {
                val target = if (n.isClickable) n else clickableAncestor(n)
                if (target != null && target.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                    return true
                }
            }
        }
        return false
    }

    /** Жмёт кнопку отправки по типичным меткам в разных приложениях. */
    fun pressSend(): Boolean {
        return clickByLabel(
            listOf("send", "отправить", "send message", "жіберу", "жөнөтүү", "жөнөт")
        )
    }

    fun back(): Boolean = performGlobalAction(GLOBAL_ACTION_BACK)
    fun home(): Boolean = performGlobalAction(GLOBAL_ACTION_HOME)

    /** Сериализует дерево экрана в компактный текст для модели (глаза агента). */
    fun readScreen(): String {
        val root = rootInActiveWindow ?: return "пустой экран"
        val sb = StringBuilder()
        sb.append("Экран приложения: ").append(root.packageName ?: "?").append('\n')
        var count = 0
        fun walk(n: AccessibilityNodeInfo?) {
            if (n == null || count >= 120) return
            val t = n.text?.toString()?.trim() ?: ""
            val d = n.contentDescription?.toString()?.trim() ?: ""
            if (t.isNotEmpty() || d.isNotEmpty()) {
                val r = Rect()
                n.getBoundsInScreen(r)
                val cx = (r.left + r.right) / 2
                val cy = (r.top + r.bottom) / 2
                val label = if (t.isNotEmpty()) "\"$t\"" else "($d)"
                val flags = buildString {
                    if (n.isClickable) append("[клик]")
                    if (n.isEditable) append("[поле]")
                }
                sb.append(label).append(' ').append(flags).append(" @").append(cx).append(',').append(cy).append('\n')
                count++
            }
            for (i in 0 until n.childCount) walk(n.getChild(i))
        }
        walk(root)
        return sb.toString().take(4000)
    }

    /** Тап по координатам экрана (жест). */
    fun tapCoordinate(x: Int, y: Int): Boolean {
        return try {
            val path = Path()
            path.moveTo(x.toFloat(), y.toFloat())
            val stroke = GestureDescription.StrokeDescription(path, 0, 60)
            dispatchGesture(GestureDescription.Builder().addStroke(stroke).build(), null, null)
        } catch (e: Exception) {
            false
        }
    }

    /** Скролл экрана жестом: up/down/left/right. */
    fun scrollScreen(direction: String): Boolean {
        return try {
            val dm = resources.displayMetrics
            val w = dm.widthPixels.toFloat()
            val h = dm.heightPixels.toFloat()
            val cx = w / 2f
            val cy = h / 2f
            val path = Path()
            when (direction.lowercase()) {
                "up" -> { path.moveTo(cx, h * 0.3f); path.lineTo(cx, h * 0.75f) }
                "down" -> { path.moveTo(cx, h * 0.75f); path.lineTo(cx, h * 0.3f) }
                "left" -> { path.moveTo(w * 0.8f, cy); path.lineTo(w * 0.2f, cy) }
                "right" -> { path.moveTo(w * 0.2f, cy); path.lineTo(w * 0.8f, cy) }
                else -> { path.moveTo(cx, h * 0.75f); path.lineTo(cx, h * 0.3f) }
            }
            val stroke = GestureDescription.StrokeDescription(path, 0, 300)
            dispatchGesture(GestureDescription.Builder().addStroke(stroke).build(), null, null)
        } catch (e: Exception) {
            false
        }
    }
}
