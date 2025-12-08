package com.ikemenmobile

import android.app.Activity
import android.content.Context
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.AttributeSet
import android.view.KeyCharacterMap
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout

class VirtualGamepadLayout @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : FrameLayout(context, attrs) {

    // ------------------------------------------------------------------------
    // Configuration
    // ------------------------------------------------------------------------
    
    // Map view -> keycode
    private val viewKeyMap = mutableMapOf<View, Int>()
    // Set of views that should auto-repeat (D-pad)
    private val dpadViews = mutableSetOf<View>()

    // ------------------------------------------------------------------------
    // State Tracking
    // ------------------------------------------------------------------------

    // Active Pointers: Map<PointerID, ViewPressedByThisPointer>
    // We track which view each specific finger is currently touching.
    private val activePointers = mutableMapOf<Int, View>()

    // Reusable objects to avoid Garbage Collection lags during gameplay
    private val tempLocation = IntArray(2)
    private val tempRect = Rect()

    // ------------------------------------------------------------------------
    // Auto-Repeat Logic (D-pad)
    // ------------------------------------------------------------------------
    private val repeatHandler = Handler(Looper.getMainLooper())
    private val repeatRunnables = mutableMapOf<View, Runnable>()
    private val repeatInitialDelay = 150L
    private val repeatInterval = 50L

    init {
        // Inflate the XML you provided
        LayoutInflater.from(context).inflate(R.layout.virtual_gamepad_overlay, this, true)

        // Important: This layout must capture touches, not the children.
        // We will disable 'clickable' on children so touches pass through to onTouchEvent below.
        setupButtons()
    }

    private fun setupButtons() {
        // D-pad
        registerButton(findViewById(R.id.btn_dpad_up),    KeyEvent.KEYCODE_DPAD_UP,    isDpad = true)
        registerButton(findViewById(R.id.btn_dpad_down),  KeyEvent.KEYCODE_DPAD_DOWN,  isDpad = true)
        registerButton(findViewById(R.id.btn_dpad_left),  KeyEvent.KEYCODE_DPAD_LEFT,  isDpad = true)
        registerButton(findViewById(R.id.btn_dpad_right), KeyEvent.KEYCODE_DPAD_RIGHT, isDpad = true)

        // Face buttons (Ikemen defaults)
        registerButton(findViewById(R.id.btn_action_a), KeyEvent.KEYCODE_Z, isDpad = false)
        registerButton(findViewById(R.id.btn_action_b), KeyEvent.KEYCODE_X, isDpad = false)
        registerButton(findViewById(R.id.btn_action_c), KeyEvent.KEYCODE_C, isDpad = false)
        registerButton(findViewById(R.id.btn_action_x), KeyEvent.KEYCODE_A, isDpad = false)
        registerButton(findViewById(R.id.btn_action_y), KeyEvent.KEYCODE_S, isDpad = false)
        registerButton(findViewById(R.id.btn_action_z), KeyEvent.KEYCODE_D, isDpad = false)

        // Start Button
        registerButton(findViewById(R.id.btn_start), KeyEvent.KEYCODE_ESCAPE, isDpad = false)
    }

    private fun registerButton(view: View?, keyCode: Int, isDpad: Boolean) {
        if (view == null) return
        viewKeyMap[view] = keyCode
        if (isDpad) dpadViews.add(view)
        
        // We disable click handling on the individual buttons so the parent (this class)
        // receives the raw MotionEvents for swipe detection.
        view.isClickable = false
        view.isFocusable = false
    }

    // ------------------------------------------------------------------------
    // Global Touch Handling (Solves Sweeping & Stuck Buttons)
    // ------------------------------------------------------------------------

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val action = event.actionMasked
        
        when (action) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> {
                val index = event.actionIndex
                val id = event.getPointerId(index)
                // Check which button this specific finger landed on
                val touchedView = findButtonAt(event.getX(index), event.getY(index))
                if (touchedView != null) {
                    activePointers[id] = touchedView
                }
            }
            
            MotionEvent.ACTION_MOVE -> {
                // Update positions for ALL active fingers
                val pointerCount = event.pointerCount
                for (i in 0 until pointerCount) {
                    val id = event.getPointerId(i)
                    val touchedView = findButtonAt(event.getX(i), event.getY(i))
                    
                    if (touchedView != null) {
                        // Finger is over a button, update the map
                        activePointers[id] = touchedView
                    } else {
                        // Finger slid off into empty space -> Remove from map
                        activePointers.remove(id)
                    }
                }
            }
            
            MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP, MotionEvent.ACTION_CANCEL -> {
                val index = event.actionIndex
                val id = event.getPointerId(index)
                activePointers.remove(id)
            }
        }

        // Apply state changes
        updateButtonStates()
        
        return true
    }

    private fun updateButtonStates() {
        // 1. Determine which views SHOULD be pressed right now based on all fingers
        val viewsShouldBePressed = activePointers.values.toSet()

        // 2. Sync the actual views to match that state
        for ((view, _) in viewKeyMap) {
            val shouldPress = viewsShouldBePressed.contains(view)
            
            if (shouldPress && !view.isPressed) {
                // It wasn't pressed, but now it is -> Press it
                pressButton(view)
            } else if (!shouldPress && view.isPressed) {
                // It was pressed, but finger moved away/lifted -> Release it
                releaseButton(view)
            }
        }
    }

    // Checks if the touch coordinates (local to this Layout) are inside a specific child view
    private fun findButtonAt(localX: Float, localY: Float): View? {
        // Convert local coordinates to screen coordinates
        this.getLocationOnScreen(tempLocation)
        val screenX = tempLocation[0] + localX
        val screenY = tempLocation[1] + localY

        // Check all registered buttons
        for (view in viewKeyMap.keys) {
            if (isPointInsideView(screenX, screenY, view)) {
                return view
            }
        }
        return null
    }

    private fun isPointInsideView(screenX: Float, screenY: Float, view: View): Boolean {
        // Get the button's actual screen bounds (handles nested layouts correctly)
        if (!view.getGlobalVisibleRect(tempRect)) return false
        return tempRect.contains(screenX.toInt(), screenY.toInt())
    }

    // ------------------------------------------------------------------------
    // Button Logic
    // ------------------------------------------------------------------------

    private fun pressButton(view: View) {
        view.isPressed = true
        val keyCode = viewKeyMap[view] ?: return
        
        sendKey(keyCode, KeyEvent.ACTION_DOWN)
        if (dpadViews.contains(view)) {
            startRepeat(view, keyCode)
        }
    }

    private fun releaseButton(view: View) {
        view.isPressed = false
        val keyCode = viewKeyMap[view] ?: return
        
        if (dpadViews.contains(view)) {
            stopRepeat(view)
        }
        sendKey(keyCode, KeyEvent.ACTION_UP)
    }

    // ------------------------------------------------------------------------
    // Helper: Key Injection
    // ------------------------------------------------------------------------

    private fun sendKey(keyCode: Int, action: Int) {
        val activity = context as? Activity ?: return
        val now = SystemClock.uptimeMillis()
        val event = KeyEvent(now, now, action, keyCode, 0)
        activity.dispatchKeyEvent(event)
    }

    // ------------------------------------------------------------------------
    // Helper: Auto-Repeat
    // ------------------------------------------------------------------------

    private fun startRepeat(view: View, keyCode: Int) {
        stopRepeat(view)
        val runnable = object : Runnable {
            override fun run() {
                if (!view.isPressed) return
                
                val activity = context as? Activity ?: return
                val now = SystemClock.uptimeMillis()
                val event = KeyEvent(
                    now, now, KeyEvent.ACTION_DOWN, keyCode,
                    1, 0, KeyCharacterMap.VIRTUAL_KEYBOARD, 0, KeyEvent.FLAG_LONG_PRESS
                )
                activity.dispatchKeyEvent(event)
                repeatHandler.postDelayed(this, repeatInterval)
            }
        }
        repeatRunnables[view] = runnable
        repeatHandler.postDelayed(runnable, repeatInitialDelay)
    }

    private fun stopRepeat(view: View) {
        val r = repeatRunnables.remove(view) ?: return
        repeatHandler.removeCallbacks(r)
    }
}
