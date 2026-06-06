package com.friday.ai_friday

import android.accessibilityservice.AccessibilityService
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
}
