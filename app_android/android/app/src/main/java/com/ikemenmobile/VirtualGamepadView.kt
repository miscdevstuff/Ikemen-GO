package com.ikemenmobile

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.util.Log
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import org.libsdl.app.SDLActivity
import kotlin.math.*

class VirtualGamepadView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : View(context, attrs) {

    companion object {
        private const val TAG = "VirtualGamepad"
        private const val DEBUG = true
    }

    private val density = resources.displayMetrics.density
    private fun dp(v: Float) = v * density

    // Paints
    private val basePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dp(2f)
        alpha = 180
    }
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        alpha = 70
    }
    private val pressedPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        alpha = 140
    }

    // State
    private val activeKeys = mutableSetOf<Int>()
    private var gamepadVisible = true

    // Layout cache
    private var cachedW = 0
    private var cachedH = 0

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        if (width <= 0 || height <= 0) return
        cachedW = width
        cachedH = height

        // Toggle button is always visible
        drawToggleButton(canvas)

        if (!gamepadVisible) return

        drawDpad(canvas)
        drawButtons(canvas)
        drawStart(canvas)
    }

    // ---------------- Layout helpers ----------------

    private fun dpadCenterX() = dp(16f) + min(width, height) * 0.16f
    private fun dpadCenterY() = height - dp(16f) - min(width, height) * 0.16f
    private fun dpadRadius() = min(width, height) * 0.16f

    private fun buttonClusterRadius() = min(width, height) * 0.11f
    private fun buttonRadius() = buttonClusterRadius() * 0.35f
    private fun buttonClusterCenterX() = width - dp(16f) - buttonClusterRadius()
    private fun buttonClusterCenterY() = height - dp(16f) - buttonClusterRadius()

    private fun startRect(): RectF {
        val w = dp(90f)
        val h = dp(28f)
        val cx = width / 2f
        val cy = height - dp(40f)
        return RectF(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
    }

    private fun toggleRect(): RectF {
        val r = dp(18f)
        val cx = width - dp(26f)
        val cy = dp(26f)
        return RectF(cx - r, cy - r, cx + r, cy + r)
    }

    // ---------------- Drawing ----------------

    private fun drawDpad(canvas: Canvas) {
        val cx = dpadCenterX()
        val cy = dpadCenterY()
        val r = dpadRadius()

        // Outer circle
        canvas.drawCircle(cx, cy, r, basePaint)

        // Cross lines
        canvas.drawLine(cx - r, cy, cx + r, cy, basePaint)
        canvas.drawLine(cx, cy - r, cx, cy + r, basePaint)

        // Highlight pressed directions
        fun isPressed(code: Int) = activeKeys.contains(code)

        val sectorPaint = pressedPaint

        // Up
        if (isPressed(KeyEvent.KEYCODE_DPAD_UP)) {
            val pathR = RectF(cx - r, cy - r, cx + r, cy + r)
            canvas.drawArc(pathR, 225f, 90f, true, sectorPaint)
        }
        // Down
        if (isPressed(KeyEvent.KEYCODE_DPAD_DOWN)) {
            val pathR = RectF(cx - r, cy - r, cx + r, cy + r)
            canvas.drawArc(pathR, 45f, 90f, true, sectorPaint)
        }
        // Left
        if (isPressed(KeyEvent.KEYCODE_DPAD_LEFT)) {
            val pathR = RectF(cx - r, cy - r, cx + r, cy + r)
            canvas.drawArc(pathR, 135f, 90f, true, sectorPaint)
        }
        // Right
        if (isPressed(KeyEvent.KEYCODE_DPAD_RIGHT)) {
            val pathR = RectF(cx - r, cy - r, cx + r, cy + r)
            canvas.drawArc(pathR, -45f, 90f, true, sectorPaint)
        }
    }

    // four action buttons: A/B/C/X mapped to Z,X,C,A keys
    private fun drawButtons(canvas: Canvas) {
        val cx = buttonClusterCenterX()
        val cy = buttonClusterCenterY()
        val cr = buttonClusterRadius()
        val br = buttonRadius()

        // Layout diamond: top, right, bottom, left
        val topX = cx
        val topY = cy - cr * 0.6f
        val rightX = cx + cr * 0.6f
        val rightY = cy
        val bottomX = cx
        val bottomY = cy + cr * 0.6f
        val leftX = cx - cr * 0.6f
        val leftY = cy

        drawButtonCircle(
            canvas, topX, topY, br,
            KeyEvent.KEYCODE_A, // maps to 'A' (X button in config)
        )
        drawButtonCircle(
            canvas, rightX, rightY, br,
            KeyEvent.KEYCODE_X, // 'X' (B button)
        )
        drawButtonCircle(
            canvas, bottomX, bottomY, br,
            KeyEvent.KEYCODE_Z, // 'Z' (A button)
        )
        drawButtonCircle(
            canvas, leftX, leftY, br,
            KeyEvent.KEYCODE_C, // 'C'
        )
    }

    private fun drawButtonCircle(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        r: Float,
        keyCode: Int
    ) {
        val p = if (activeKeys.contains(keyCode)) pressedPaint else fillPaint
        canvas.drawCircle(cx, cy, r, p)
        canvas.drawCircle(cx, cy, r, basePaint)
    }

    private fun drawStart(canvas: Canvas) {
        val rect = startRect()
        val paint = if (activeKeys.contains(KeyEvent.KEYCODE_ENTER)) pressedPaint else fillPaint
        canvas.drawRoundRect(rect, dp(8f), dp(8f), paint)
        canvas.drawRoundRect(rect, dp(8f), dp(8f), basePaint)
    }

    private fun drawToggleButton(canvas: Canvas) {
        val rect = toggleRect()
        val p = fillPaint
        val b = basePaint
        canvas.drawOval(rect, p)
        canvas.drawOval(rect, b)
        // crude indicator: filled if visible
        if (gamepadVisible) {
            val inner = RectF(
                rect.left + dp(4f),
                rect.top + dp(4f),
                rect.right - dp(4f),
                rect.bottom - dp(4f)
            )
            canvas.drawOval(inner, pressedPaint)
        }
    }

    // ---------------- Touch handling ----------------

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (width <= 0 || height <= 0) return false

        when (event.actionMasked) {
            MotionEvent.ACTION_CANCEL -> {
                releaseAllKeys()
                return true
            }
        }

        val newPressed = mutableSetOf<Int>()

        // First: check toggle button separately for single taps
        if (event.actionMasked == MotionEvent.ACTION_DOWN ||
            event.actionMasked == MotionEvent.ACTION_POINTER_DOWN
        ) {
            val idx = event.actionIndex
            val x = event.getX(idx)
            val y = event.getY(idx)
            if (hitToggle(x, y)) {
                toggleVisibility()
                return true
            }
        }

        if (gamepadVisible) {
            // For all pointers, accumulate which keys should be down
            val pointerCount = event.pointerCount
            for (i in 0 until pointerCount) {
                val x = event.getX(i)
                val y = event.getY(i)
                hitGamepad(x, y, newPressed)
            }
        }

        // Compare with previous state and send key events
        updateKeys(newPressed)
        invalidate()
        return true
    }

    private fun hitToggle(x: Float, y: Float): Boolean {
        val r = toggleRect()
        return r.contains(x, y)
    }

    private fun toggleVisibility() {
        gamepadVisible = !gamepadVisible
        if (!gamepadVisible) {
            if (DEBUG) Log.d(TAG, "Gamepad hidden, releasing all keys")
            releaseAllKeys()
        } else {
            if (DEBUG) Log.d(TAG, "Gamepad shown")
        }
        invalidate()
    }

    private fun hitGamepad(x: Float, y: Float, collector: MutableSet<Int>) {
        // DPad
        hitDpad(x, y, collector)

        // Action cluster
        hitButtons(x, y, collector)

        // Start
        if (startRect().contains(x, y)) {
            collector.add(KeyEvent.KEYCODE_ENTER) // RETURN in config.ini
        }
    }

    private fun hitDpad(x: Float, y: Float, collector: MutableSet<Int>) {
        val cx = dpadCenterX()
        val cy = dpadCenterY()
        val r = dpadRadius()
        val dx = x - cx
        val dy = y - cy
        val dist = hypot(dx, dy)

        if (dist > r * 1.1f) return

        // angle: -pi to pi, 0 at +X, positive CCW
        val angle = atan2(-dy, dx) // invert y so up is positive
        val deg = (Math.toDegrees(angle.toDouble()) + 360.0) % 360.0

        // 8-way zones (45° each)
        fun add(code: Int) = collector.add(code)

        when {
            deg in 337.5..360.0 || deg < 22.5 -> {          // Right
                add(KeyEvent.KEYCODE_DPAD_RIGHT)
            }
            deg < 67.5 -> {                                 // Up-Right
                add(KeyEvent.KEYCODE_DPAD_RIGHT)
                add(KeyEvent.KEYCODE_DPAD_UP)
            }
            deg < 112.5 -> {                                // Up
                add(KeyEvent.KEYCODE_DPAD_UP)
            }
            deg < 157.5 -> {                                // Up-Left
                add(KeyEvent.KEYCODE_DPAD_UP)
                add(KeyEvent.KEYCODE_DPAD_LEFT)
            }
            deg < 202.5 -> {                                // Left
                add(KeyEvent.KEYCODE_DPAD_LEFT)
            }
            deg < 247.5 -> {                                // Down-Left
                add(KeyEvent.KEYCODE_DPAD_LEFT)
                add(KeyEvent.KEYCODE_DPAD_DOWN)
            }
            deg < 292.5 -> {                                // Down
                add(KeyEvent.KEYCODE_DPAD_DOWN)
            }
            else -> {                                       // Down-Right
                add(KeyEvent.KEYCODE_DPAD_DOWN)
                add(KeyEvent.KEYCODE_DPAD_RIGHT)
            }
        }
    }

    private fun hitButtons(x: Float, y: Float, collector: MutableSet<Int>) {
        val cx = buttonClusterCenterX()
        val cy = buttonClusterCenterY()
        val cr = buttonClusterRadius()
        val br = buttonRadius()

        val topX = cx
        val topY = cy - cr * 0.6f
        val rightX = cx + cr * 0.6f
        val rightY = cy
        val bottomX = cx
        val bottomY = cy + cr * 0.6f
        val leftX = cx - cr * 0.6f
        val leftY = cy

        fun inside(cx: Float, cy: Float): Boolean {
            val dx = x - cx
            val dy = y - cy
            return dx * dx + dy * dy <= br * br
        }

        // Top: A -> Android KEYCODE_A
        if (inside(topX, topY)) {
            collector.add(KeyEvent.KEYCODE_A)
        }
        // Right: X -> KEYCODE_X
        if (inside(rightX, rightY)) {
            collector.add(KeyEvent.KEYCODE_X)
        }
        // Bottom: Z -> KEYCODE_Z
        if (inside(bottomX, bottomY)) {
            collector.add(KeyEvent.KEYCODE_Z)
        }
        // Left: C -> KEYCODE_C
        if (inside(leftX, leftY)) {
            collector.add(KeyEvent.KEYCODE_C)
        }
    }

    private fun updateKeys(newPressed: MutableSet<Int>) {
        // Keys to press: in newPressed but not currently active
        val toPress = newPressed - activeKeys
        // Keys to release: in activeKeys but not in newPressed
        val toRelease = activeKeys - newPressed

        for (code in toPress) {
            if (DEBUG) Log.d(TAG, "Key DOWN: $code")
            SDLActivity.onNativeKeyDown(code)
        }
        for (code in toRelease) {
            if (DEBUG) Log.d(TAG, "Key UP  : $code")
            SDLActivity.onNativeKeyUp(code)
        }

        activeKeys.clear()
        activeKeys.addAll(newPressed)
    }

    private fun releaseAllKeys() {
        for (code in activeKeys) {
            if (DEBUG) Log.d(TAG, "Releasing stuck key: $code")
            SDLActivity.onNativeKeyUp(code)
        }
        activeKeys.clear()
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        releaseAllKeys()
    }
}