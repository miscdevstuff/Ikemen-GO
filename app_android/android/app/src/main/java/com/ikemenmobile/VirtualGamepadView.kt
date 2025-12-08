package com.ikemenmobile

import android.app.Activity
import android.content.Context
import android.graphics.*
import android.os.SystemClock
import android.util.AttributeSet
import android.util.Log
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import kotlin.math.hypot

class VirtualGamepadView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val tagLog = "VirtualGamepad"

    // --- Paints -------------------------------------------------------------

    // Darkish gray like emulators (semi-transparent)
    private val basePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(180, 40, 40, 40)
        style = Paint.Style.FILL
    }

    private val pressedPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(230, 220, 220, 220)
        style = Paint.Style.FILL
    }

    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(220, 0, 0, 0)
        style = Paint.Style.STROKE
        strokeWidth = dp(2f)
    }

    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textAlign = Paint.Align.CENTER
        textSize = dp(11f)
    }

    // --- Types & data structures -------------------------------------------

    private enum class ButtonType {
        DPAD_UP,
        DPAD_DOWN,
        DPAD_LEFT,
        DPAD_RIGHT,
        BUTTON_A,
        BUTTON_B,
        BUTTON_C,
        BUTTON_D,
        BUTTON_START,
        BUTTON_TOGGLE
    }

    private data class ButtonRegion(
        val type: ButtonType,
        var cx: Float = 0f,
        var cy: Float = 0f,
        var radius: Float = 0f,
        val keyCode: Int? = null,   // null for pure-UI buttons like toggle
        var pressed: Boolean = false
    )

    // All buttons
    private val buttons = mutableMapOf<ButtonType, ButtonRegion>()

    // For each pointerId, which button it's currently pressing
    private val pointerToButton = mutableMapOf<Int, ButtonType>()

    // Optional: callback for the "hide/show" toggle button
    var onToggleRequested: (() -> Unit)? = null

    // -----------------------------------------------------------------------
    // Layout
    // -----------------------------------------------------------------------

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)

        buttons.clear()

        val width = w.toFloat()
        val height = h.toFloat()
        val padding = dp(16f)

        // --- D-Pad on bottom-left ------------------------------------------
        val dpadRadius = height * 0.09f      // bigger than before
        val dpadCenterX = padding + dpadRadius * 2.0f
        val dpadCenterY = height - padding - dpadRadius * 2.0f
        val dpadOffset = dpadRadius * 1.3f   // spacing between arrows

        buttons[ButtonType.DPAD_UP] = ButtonRegion(
            ButtonType.DPAD_UP,
            dpadCenterX,
            dpadCenterY - dpadOffset,
            dpadRadius,
            KeyEvent.KEYCODE_DPAD_UP
        )
        buttons[ButtonType.DPAD_DOWN] = ButtonRegion(
            ButtonType.DPAD_DOWN,
            dpadCenterX,
            dpadCenterY + dpadOffset,
            dpadRadius,
            KeyEvent.KEYCODE_DPAD_DOWN
        )
        buttons[ButtonType.DPAD_LEFT] = ButtonRegion(
            ButtonType.DPAD_LEFT,
            dpadCenterX - dpadOffset,
            dpadCenterY,
            dpadRadius,
            KeyEvent.KEYCODE_DPAD_LEFT
        )
        buttons[ButtonType.DPAD_RIGHT] = ButtonRegion(
            ButtonType.DPAD_RIGHT,
            dpadCenterX + dpadOffset,
            dpadCenterY,
            dpadRadius,
            KeyEvent.KEYCODE_DPAD_RIGHT
        )

        // --- Face buttons bottom-right -------------------------------------
        val faceRadius = height * 0.085f      // larger action buttons
        val faceCenterX = width - padding - faceRadius * 2.0f
        val faceCenterY = height - padding - faceRadius * 1.8f
        val faceOffset = faceRadius * 1.5f

        // Map to Ikemen keyboard defaults: Z, X, C, A
        buttons[ButtonType.BUTTON_A] = ButtonRegion(
            ButtonType.BUTTON_A,
            faceCenterX + faceOffset,
            faceCenterY,
            faceRadius,
            KeyEvent.KEYCODE_Z
        )
        buttons[ButtonType.BUTTON_B] = ButtonRegion(
            ButtonType.BUTTON_B,
            faceCenterX,
            faceCenterY - faceOffset,
            faceRadius,
            KeyEvent.KEYCODE_X
        )
        buttons[ButtonType.BUTTON_C] = ButtonRegion(
            ButtonType.BUTTON_C,
            faceCenterX - faceOffset,
            faceCenterY,
            faceRadius,
            KeyEvent.KEYCODE_C
        )
        buttons[ButtonType.BUTTON_D] = ButtonRegion(
            ButtonType.BUTTON_D,
            faceCenterX,
            faceCenterY + faceOffset,
            faceRadius,
            KeyEvent.KEYCODE_A
        )

        // --- Start button (small, near center bottom) ----------------------
        val startRadius = height * 0.045f
        buttons[ButtonType.BUTTON_START] = ButtonRegion(
            ButtonType.BUTTON_START,
            width * 0.5f,
            height - padding - startRadius * 1.5f,
            startRadius,
            KeyEvent.KEYCODE_ENTER
        )

        // --- Toggle button (small, left side) ------------------------------
        val toggleRadius = height * 0.04f
        buttons[ButtonType.BUTTON_TOGGLE] = ButtonRegion(
            ButtonType.BUTTON_TOGGLE,
            padding + toggleRadius * 1.2f,
            height * 0.5f,
            toggleRadius,
            null // no key event, just UI toggle
        )
    }

    // -----------------------------------------------------------------------
    // Drawing
    // -----------------------------------------------------------------------

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        buttons.values.forEach { btn ->
            val paint = if (btn.pressed) pressedPaint else basePaint
            canvas.drawCircle(btn.cx, btn.cy, btn.radius, paint)
            canvas.drawCircle(btn.cx, btn.cy, btn.radius, strokePaint)

            val label = when (btn.type) {
                ButtonType.DPAD_UP -> "↑"
                ButtonType.DPAD_DOWN -> "↓"
                ButtonType.DPAD_LEFT -> "←"
                ButtonType.DPAD_RIGHT -> "→"
                ButtonType.BUTTON_A -> "A"
                ButtonType.BUTTON_B -> "B"
                ButtonType.BUTTON_C -> "C"
                ButtonType.BUTTON_D -> "D"
                ButtonType.BUTTON_START -> "START"
                ButtonType.BUTTON_TOGGLE -> "☰"
            }

            val textY = btn.cy - ((textPaint.descent() + textPaint.ascent()) / 2)
            canvas.drawText(label, btn.cx, textY, textPaint)
        }
    }

    // -----------------------------------------------------------------------
    // Touch handling (press/hold/release, sweeps)
    // -----------------------------------------------------------------------

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val action = event.actionMasked
        val index = event.actionIndex

        when (action) {
            MotionEvent.ACTION_DOWN,
            MotionEvent.ACTION_POINTER_DOWN -> {
                val pointerId = event.getPointerId(index)
                handleDown(pointerId, event.getX(index), event.getY(index))
            }

            MotionEvent.ACTION_MOVE -> {
                // Handle all pointers for sweeps
                for (i in 0 until event.pointerCount) {
                    val pointerId = event.getPointerId(i)
                    handleMove(pointerId, event.getX(i), event.getY(i))
                }
            }

            MotionEvent.ACTION_UP,
            MotionEvent.ACTION_POINTER_UP,
            MotionEvent.ACTION_CANCEL -> {
                val pointerId = event.getPointerId(index)
                handleUp(pointerId)
            }
        }

        return true
    }

    private fun handleDown(pointerId: Int, x: Float, y: Float) {
        val hit = hitTest(x, y) ?: return

        if (hit.type == ButtonType.BUTTON_TOGGLE) {
            // Just UI toggle – no key events
            onToggleRequested?.invoke()
            return
        }

        pointerToButton[pointerId] = hit.type
        setButtonPressed(hit.type, true)
        sendKeyDown(hit)
    }

    private fun handleMove(pointerId: Int, x: Float, y: Float) {
        val currentType = pointerToButton[pointerId]
        val newHit = hitTest(x, y)

        // If pointer left its old button, release it
        if (currentType != null && (newHit == null || newHit.type != currentType)) {
            val oldBtn = buttons[currentType]
            if (oldBtn != null) {
                setButtonPressed(currentType, false)
                sendKeyUp(oldBtn)
            }
            pointerToButton.remove(pointerId)
        }

        // If pointer moved onto a new button, press it
        if (newHit != null && newHit.type != ButtonType.BUTTON_TOGGLE) {
            if (pointerToButton[pointerId] != newHit.type) {
                pointerToButton[pointerId] = newHit.type
                setButtonPressed(newHit.type, true)
                sendKeyDown(newHit)
            }
        }
    }

    private fun handleUp(pointerId: Int) {
        val type = pointerToButton.remove(pointerId) ?: return
        val btn = buttons[type] ?: return
        setButtonPressed(type, false)
        sendKeyUp(btn)
    }

    private fun hitTest(x: Float, y: Float): ButtonRegion? {
        // Simple circular hit test
        // Closest button wins if overlaps
        var best: ButtonRegion? = null
        var bestDist = Float.MAX_VALUE

        for (btn in buttons.values) {
            val d = hypot(x - btn.cx, y - btn.cy)
            if (d <= btn.radius) {
                if (d < bestDist) {
                    bestDist = d
                    best = btn
                }
            }
        }
        return best
    }

    private fun setButtonPressed(type: ButtonType, pressed: Boolean) {
        val btn = buttons[type] ?: return
        if (btn.pressed == pressed) return
        btn.pressed = pressed
        invalidate()
    }

    // -----------------------------------------------------------------------
    // Key injection
    // -----------------------------------------------------------------------

    private fun sendKeyDown(btn: ButtonRegion) {
        val keyCode = btn.keyCode ?: return
        Log.d(tagLog, "Key DOWN: $keyCode")

        val now = SystemClock.uptimeMillis()
        val event = KeyEvent(
            now,
            now,
            KeyEvent.ACTION_DOWN,
            keyCode,
            0
        )
        (context as? Activity)?.dispatchKeyEvent(event)
    }

    private fun sendKeyUp(btn: ButtonRegion) {
        val keyCode = btn.keyCode ?: return
        Log.d(tagLog, "Key UP  : $keyCode")

        val now = SystemClock.uptimeMillis()
        val event = KeyEvent(
            now,
            now,
            KeyEvent.ACTION_UP,
            keyCode,
            0
        )
        (context as? Activity)?.dispatchKeyEvent(event)
    }

    // -----------------------------------------------------------------------

    private fun dp(v: Float): Float {
        return v * resources.displayMetrics.density
    }
}