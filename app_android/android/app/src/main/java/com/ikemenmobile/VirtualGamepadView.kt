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

    // Darkish gray, semi-transparent – like common emulators
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
        BUTTON_X,
        BUTTON_Y,
        BUTTON_Z,

        BUTTON_START
    }

    private data class ButtonRegion(
        val type: ButtonType,
        var cx: Float = 0f,
        var cy: Float = 0f,
        var radius: Float = 0f,
        val keyCode: Int? = null,
        var pressed: Boolean = false
    )

    private val buttons = mutableMapOf<ButtonType, ButtonRegion>()
    private val pointerToButton = mutableMapOf<Int, ButtonType>()

    // -----------------------------------------------------------------------
    // Layout
    // -----------------------------------------------------------------------

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)

        buttons.clear()

        val width = w.toFloat()
        val height = h.toFloat()
        val padding = dp(16f)

        // --- D-Pad bottom-left, non-overlapping -----------------------------
        val dpadRadius = height * 0.09f
        val dpadCenterX = padding + dpadRadius * 2.0f
        val dpadCenterY = height - padding - dpadRadius * 2.0f
        // Slightly more than 2R so circles don't overlap
        val dpadOffset = dpadRadius * 2.1f

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

        // --- 6 face buttons, SNES/NES style 3×2 grid -----------------------
        val faceRadius = height * 0.075f
        val faceCenterX = width - padding - faceRadius * 2.0f
        val faceCenterY = height * 0.60f
        val faceOffsetX = faceRadius * 2.2f
        val faceOffsetY = faceRadius * 2.0f

        /*
            Mapping to Ikemen default keyboard (P1):
              A = z
              B = x
              C = c
              X = a
              Y = s
              Z = d
         */

        // Top row: X, Y, Z
        buttons[ButtonType.BUTTON_X] = ButtonRegion(
            ButtonType.BUTTON_X,
            faceCenterX - faceOffsetX,
            faceCenterY - faceOffsetY,
            faceRadius,
            KeyEvent.KEYCODE_A
        )
        buttons[ButtonType.BUTTON_Y] = ButtonRegion(
            ButtonType.BUTTON_Y,
            faceCenterX,
            faceCenterY - faceOffsetY,
            faceRadius,
            KeyEvent.KEYCODE_S
        )
        buttons[ButtonType.BUTTON_Z] = ButtonRegion(
            ButtonType.BUTTON_Z,
            faceCenterX + faceOffsetX,
            faceCenterY - faceOffsetY,
            faceRadius,
            KeyEvent.KEYCODE_D
        )

        // Bottom row: A, B, C (most commonly used)
        buttons[ButtonType.BUTTON_A] = ButtonRegion(
            ButtonType.BUTTON_A,
            faceCenterX - faceOffsetX,
            faceCenterY,
            faceRadius,
            KeyEvent.KEYCODE_Z
        )
        buttons[ButtonType.BUTTON_B] = ButtonRegion(
            ButtonType.BUTTON_B,
            faceCenterX,
            faceCenterY,
            faceRadius,
            KeyEvent.KEYCODE_X
        )
        buttons[ButtonType.BUTTON_C] = ButtonRegion(
            ButtonType.BUTTON_C,
            faceCenterX + faceOffsetX,
            faceCenterY,
            faceRadius,
            KeyEvent.KEYCODE_C
        )

        // --- Start button – top center-ish ---------------------------------
        val startRadius = height * 0.045f
        buttons[ButtonType.BUTTON_START] = ButtonRegion(
            ButtonType.BUTTON_START,
            width * 0.5f,
            padding + startRadius * 1.5f,
            startRadius,
            KeyEvent.KEYCODE_ENTER
        )
    }

    // -----------------------------------------------------------------------
    // Drawing
    // -----------------------------------------------------------------------

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        for (btn in buttons.values) {
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
                ButtonType.BUTTON_X -> "X"
                ButtonType.BUTTON_Y -> "Y"
                ButtonType.BUTTON_Z -> "Z"
                ButtonType.BUTTON_START -> "START"
            }

            val textY = btn.cy - ((textPaint.descent() + textPaint.ascent()) / 2f)
            canvas.drawText(label, btn.cx, textY, textPaint)
        }
    }

    // -----------------------------------------------------------------------
    // Touch handling with sweeps
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
        pointerToButton[pointerId] = hit.type
        setButtonPressed(hit.type, true)
        sendKeyDown(hit)
    }

    private fun handleMove(pointerId: Int, x: Float, y: Float) {
        val currentType = pointerToButton[pointerId]
        val newHit = hitTest(x, y)

        if (currentType != null && (newHit == null || newHit.type != currentType)) {
            val oldBtn = buttons[currentType]
            if (oldBtn != null) {
                setButtonPressed(currentType, false)
                sendKeyUp(oldBtn)
            }
            pointerToButton.remove(pointerId)
        }

        if (newHit != null) {
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
        var best: ButtonRegion? = null
        var bestDist = Float.MAX_VALUE

        for (btn in buttons.values) {
            val d = hypot(x - btn.cx, y - btn.cy)
            if (d <= btn.radius && d < bestDist) {
                bestDist = d
                best = btn
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
        Log.d(tagLog, "Key DOWN: $keyCode (${btn.type})")

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
        Log.d(tagLog, "Key UP  : $keyCode (${btn.type})")

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

    private fun dp(v: Float): Float =
        v * resources.displayMetrics.density
}