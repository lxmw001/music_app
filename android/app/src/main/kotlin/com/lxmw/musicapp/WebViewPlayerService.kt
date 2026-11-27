package com.lxmw.musicapp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient

/**
 * Foreground service that owns the YouTube player WebView.
 *
 * The WebView must live in a Service (not the Activity) because Android
 * pauses WebView media playback when the host Activity is backgrounded —
 * screen lock killed audio even with a wake lock, audio focus, and
 * resumeTimers(). A foreground service is exempt from background
 * restrictions, so the WebView keeps playing when the screen is off.
 */
class WebViewPlayerService : Service() {

    companion object {
        const val CHANNEL_ID = "webview_player"
        const val NOTIFICATION_ID = 0x77 // distinct from audio_service's notification
        const val ACTION_START = "com.lxmw.musicapp.START"
        const val ACTION_STOP = "com.lxmw.musicapp.STOP"

        @Volatile var instance: WebViewPlayerService? = null
            private set

        /** Commands that arrived before the service finished starting. */
        val pendingJs = mutableListOf<String>()
    }

    private var _webView: WebView? = null
    val webView: WebView? get() = _webView
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }

        startAsForeground()

        if (_webView == null) {
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                createWebView()
                ensureOverlayWindow()
            }
        }
        return START_STICKY
    }

    private fun startAsForeground() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Background Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps YouTube playback alive when the screen is off"
                setShowBadge(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }
        return builder
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("Music")
            .setContentText("Playing in background")
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .build()
    }

    // ── WebView ────────────────────────────────────────────────────────────

    fun createWebView(): WebView {
        if (_webView != null) return _webView!!

        val wv = WebView(this).apply {
            settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                mediaPlaybackRequiresUserGesture = false
                cacheMode = WebSettings.LOAD_DEFAULT
                allowFileAccess = false
                allowContentAccess = false
                userAgentString = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
                mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
            }
            webViewClient = WebViewClient()
            webChromeClient = WebChromeClient()
            addJavascriptInterface(JsBridge(), "AndroidBridge")
        }

        android.webkit.CookieManager.getInstance().setAcceptThirdPartyCookies(wv, true)
        wv.loadUrl("https://music-app-server-950104611859.us-central1.run.app/player")

        _webView = wv

        // Flush any commands that arrived before the WebView was ready
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            pendingJs.forEach { wv.evaluateJavascript(it, null) }
            pendingJs.clear()
        }, 2000)

        return wv
    }

    fun ensureOverlayWindow() {
        val wv = _webView ?: return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        if (!Settings.canDrawOverlays(this)) return
        if (wv.parent != null) return // already attached

        val density = resources.displayMetrics.density
        val widthPx = (200 * density).toInt()
        val heightPx = (112 * density).toInt()

        val params = WindowManager.LayoutParams(
            widthPx, heightPx,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = -widthPx // fully off-screen left
            y = 0
        }

        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        try {
            wm.addView(wv, params)
        } catch (e: Exception) {
            // Window add failed — WebView stays unattached; playback may
            // pause on lock screen, but foreground service still helps.
        }
    }

    fun sendCommand(js: String) {
        val wv = _webView
        if (wv == null) {
            pendingJs.add(js)
        } else {
            wv.evaluateJavascript(js, null)
        }
    }

    fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "MusicApp:WebViewPlayer"
        ).also {
            it.setReferenceCounted(false)
            it.acquire(6 * 60 * 60 * 1000L)
        }
    }

    fun releaseWakeLock() {
        if (wakeLock?.isHeld == true) wakeLock?.release()
        wakeLock = null
    }

    // Events from JS land here — forwarded to MainActivity's channel if alive
    private inner class JsBridge {
        @JavascriptInterface
        fun onEvent(json: String) {
            MainActivity.forwardWebEvent(this@WebViewPlayerService, json)
        }
    }

    override fun onDestroy() {
        releaseWakeLock()
        _webView?.let { wv ->
            (wv.parent as? android.view.ViewGroup)?.removeView(wv)
            wv.destroy()
        }
        _webView = null
        instance = null
        super.onDestroy()
    }
}
