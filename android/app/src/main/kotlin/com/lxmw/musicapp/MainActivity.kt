package com.lxmw.musicapp

import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.View
import android.view.WindowManager
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import com.pichillilorenzo.flutter_inappwebview_android.InAppWebViewFlutterPlugin
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {

    private var youtubeWebView: WebView? = null
    private var overlayWindow: View? = null
    private var youtubeChannel: MethodChannel? = null
    // Keeps CPU alive when screen is off so the WebView renderer keeps running
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(InAppWebViewFlutterPlugin())

        // === Battery MethodChannel (existing) ===
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.lxmw.musicapp/battery")
            .setMethodCallHandler { call, result ->
                if (call.method == "requestIgnoreBatteryOptimizations") {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                            val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        }
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }

        // === Install MethodChannel (existing) ===
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.lxmw.musicapp/install")
            .setMethodCallHandler { call, result ->
                if (call.method == "installApk") {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        val file = File(path)
                        val uri = FileProvider.getUriForFile(this, "${applicationContext.packageName}.fileprovider", file)
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(null)
                    } else {
                        result.error("INVALID_PATH", "APK path is null", null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // === YouTube Surface MethodChannel (new) ===
        youtubeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.lxmw.musicapp/youtube_surface")
        youtubeChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "ensureReady" -> {
                    runOnUiThread {
                        ensureWebView()
                        result.success(null)
                    }
                }
                "moveToOverlay" -> {
                    runOnUiThread {
                        moveToOverlay()
                        result.success(null)
                    }
                }
                "cmd" -> {
                    val command = call.argument<String>("command")
                    runOnUiThread {
                        sendCommand(command, call.arguments as Map<*, *>)
                        result.success(null)
                    }
                }
                "hasOverlayPermission" -> {
                    result.success(hasOverlayPermission())
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(null)
                }
                "releaseWakeLock" -> {
                    runOnUiThread { releaseWakeLock() }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // === YouTube WebView ===

    private fun ensureWebView() {
        if (youtubeWebView != null) return

        val webView = WebView(this).apply {
            settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                mediaPlaybackRequiresUserGesture = false
                cacheMode = WebSettings.LOAD_DEFAULT
                allowFileAccess = false
                allowContentAccess = false
                // Identify as a desktop browser so YouTube serves embeds not app redirects
                userAgentString = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
                // Allow third-party cookies for YouTube embeds
                mixedContentMode = android.webkit.WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
            }
            webViewClient = object : WebViewClient() {
                // Keep ALL navigation inside the WebView — never open external browser.
                // YouTube embeds sometimes try to navigate to youtube.com or consent
                // pages; those must stay in-frame or playback breaks.
                @Deprecated("Deprecated in Java")
                override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
                    return false // always load in WebView
                }

                override fun shouldOverrideUrlLoading(
                    view: WebView?,
                    request: android.webkit.WebResourceRequest?
                ): Boolean {
                    return false // always load in WebView
                }

                override fun onReceivedError(
                    view: WebView?,
                    request: android.webkit.WebResourceRequest?,
                    error: android.webkit.WebResourceError?
                ) {
                    // Only fall back for the main frame failing to load the remote player page
                    if (request?.isForMainFrame == true &&
                        view?.url?.contains("/player") == true) {
                        runOnUiThread {
                            val html = loadAssetFromFlutter("assets/youtube_player.html")
                            view.loadDataWithBaseURL(
                                "https://music-app-server-950104611859.us-central1.run.app/",
                                html,
                                "text/html",
                                "utf-8",
                                null
                            )
                        }
                    }
                    super.onReceivedError(view, request, error)
                }
            }
            webChromeClient = WebChromeClient()
            // JS → Android bridge
            addJavascriptInterface(JsBridge(), "AndroidBridge")
        }

        youtubeWebView = webView

        // Enable third-party cookies (required for YouTube embeds)
        android.webkit.CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true)

        // Load the player page from the remote server so the WebView has a real
        // HTTPS origin. YouTube's IFrame embed system checks the Referer/Origin
        // of the page hosting the embed; loading via loadDataWithBaseURL() does
        // not produce a genuine remote origin and YouTube rejects it with error 152.
        webView.loadUrl("https://music-app-server-950104611859.us-central1.run.app/player")

        // Park in a TYPE_APPLICATION_OVERLAY window so YouTube's visibility check
        // passes and playback continues past ~40s. If permission is granted, do it
        // now; otherwise fall back to a small visible corner widget in the activity.
        if (hasOverlayPermission()) {
            moveToOverlay()
        } else {
            // No overlay permission — add a visible corner widget to the decor view.
            // 1×1 or tiny sizes fail YouTube's visibility check; use 200×112dp.
            val rootView = window.decorView as android.view.ViewGroup
            val density = resources.displayMetrics.density
            val params = android.widget.FrameLayout.LayoutParams(
                (200 * density).toInt(), (112 * density).toInt()
            ).apply {
                gravity = android.view.Gravity.TOP or android.view.Gravity.START
                topMargin = (24 * density).toInt()
            }
            rootView.addView(webView, params)
            webView.bringToFront()
            webView.elevation = 100f
        }
    }

    private fun loadAssetFromFlutter(assetPath: String): String {
        // Use Flutter asset lookup via asset manager
        val key = FlutterUtils.getLookupKeyForAsset(assetPath)
        return assets.open(key).bufferedReader().use { it.readText() }
    }

    private fun sendCommand(command: String?, args: Map<*, *>) {
        if (youtubeWebView == null || command == null) return

        // Build JS positional arguments matching the HTML __cmd(command, arg1, arg2, ...)
        val jsArgs = StringBuilder()
        when (command) {
            "load" -> {
                val videoId = args["videoId"] as? String ?: ""
                val startMs = (args["startMs"] as? Number)?.toLong() ?: 0L
                jsArgs.append("\"$videoId\", ${(startMs / 1000.0)}")
            }
            "crossfade" -> {
                val videoId = args["videoId"] as? String ?: ""
                val startMs = (args["startMs"] as? Number)?.toLong() ?: 0L
                jsArgs.append("\"$videoId\", ${startMs / 1000.0}")
            }
            "seek" -> {
                val positionMs = (args["positionMs"] as? Number)?.toLong() ?: 0L
                jsArgs.append("${positionMs / 1000.0}")
            }
            "setVolume" -> {
                val volume = (args["volume"] as? Number)?.toDouble() ?: 1.0
                jsArgs.append("${(volume * 100).toInt()}")
            }
            "play", "pause", "stop" -> { /* no args */ }
            else -> {
                // Pass remaining args as JSON for unknown commands
                args.filterKeys { it != "command" }.values.forEachIndexed { i, v ->
                    if (i > 0) jsArgs.append(", ")
                    jsArgs.append(when (v) {
                        is String -> "\"${v.replace("\\", "\\\\").replace("\"", "\\\"")}\""
                        is Number -> v.toString()
                        is Boolean -> v.toString()
                        else -> "null"
                    })
                }
            }
        }

        val js = "window.__cmd(\"$command\"${if (jsArgs.isNotEmpty()) ", $jsArgs" else ""})"
        youtubeWebView?.evaluateJavascript(js, null)
    }

    // === Overlay Window ===

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        }
    }

    private fun moveToOverlay() {
        if (youtubeWebView == null) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        if (!Settings.canDrawOverlays(this)) return
        if (overlayWindow != null) return // already in overlay

        val webView = youtubeWebView!!

        // Remove from activity view if attached
        (webView.parent as? android.view.ViewGroup)?.removeView(webView)

        // Full-size player (YouTube's visibility check fails on tiny windows —
        // a 1×1px overlay paused playback at ~40s again), but positioned mostly
        // OFF-SCREEN: only a ~64px corner sliver remains visible. NOT_TOUCHABLE
        // so the sliver never intercepts input.
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
            gravity = android.view.Gravity.TOP or android.view.Gravity.START
            // Shift so only a 64px square shows in the top-left corner
            x = -(widthPx - 64)
            y = 0
        }

        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        try {
            wm.addView(webView, params)
            overlayWindow = webView
            acquireWakeLock()
        } catch (e: Exception) {
            // Fallback: 200×112dp corner widget in the activity decor view
            overlayWindow = null
            val rootView = window.decorView as android.view.ViewGroup
            if (webView.parent == null) {
                val density = resources.displayMetrics.density
                val fallbackParams = android.widget.FrameLayout.LayoutParams(
                    (200 * density).toInt(), (112 * density).toInt()
                ).apply {
                    gravity = android.view.Gravity.TOP or android.view.Gravity.START
                    topMargin = (24 * density).toInt()
                }
                rootView.addView(webView, fallbackParams)
                webView.bringToFront()
                webView.elevation = 100f
            }
        }
    }

    // === Wake Lock ===

    /** Acquire a PARTIAL_WAKE_LOCK so the CPU stays on when the screen locks.
     *  Without this the WebView renderer is throttled and audio stops. */
    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "MusicApp:YouTubeWebView"
        ).also {
            it.setReferenceCounted(false)
            it.acquire(6 * 60 * 60 * 1000L) // max 6 h, released on stop
        }
    }

    fun releaseWakeLock() {
        if (wakeLock?.isHeld == true) {
            wakeLock?.release()
        }
        wakeLock = null
    }

    // === JS Bridge ===

    private inner class JsBridge {
        @JavascriptInterface
        fun onEvent(json: String) {
            runOnUiThread {
                youtubeChannel?.invokeMethod("onEvent", json)
            }
        }
    }

    // === Lifecycle ===

    override fun onResume() {
        super.onResume()
        youtubeWebView?.onResume()
        // If the overlay was lost (e.g. permission revoked), re-add to activity
        if (overlayWindow == null && youtubeWebView != null) {
            val webView = youtubeWebView!!
            if (webView.parent == null) {
                if (hasOverlayPermission()) {
                    moveToOverlay()
                } else {
                    val rootView = window.decorView as android.view.ViewGroup
                    val density = resources.displayMetrics.density
                    val params = android.widget.FrameLayout.LayoutParams(
                        (200 * density).toInt(), (112 * density).toInt()
                    ).apply {
                        gravity = android.view.Gravity.TOP or android.view.Gravity.START
                        topMargin = (24 * density).toInt()
                    }
                    rootView.addView(webView, params)
                    webView.bringToFront()
                    webView.elevation = 100f
                }
            }
        }
    }

    override fun onPause() {
        super.onPause()
        // Do NOT call youtubeWebView?.onPause() — that throttles JS timers
        // and would stop audio. The WebView keeps running in the overlay window.
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isFinishing) {
            releaseWakeLock()
            youtubeWebView?.let { webView ->
                (webView.parent as? android.view.ViewGroup)?.removeView(webView)
                if (overlayWindow != null) {
                    val wm = getSystemService(WINDOW_SERVICE) as WindowManager
                    try { wm.removeView(webView) } catch (e: Exception) {}
                    overlayWindow = null
                }
                webView.destroy()
                youtubeWebView = null
            }
        }
    }

    // === Helper to access Flutter asset lookup ===
    private object FlutterUtils {
        fun getLookupKeyForAsset(assetPath: String): String {
            return FlutterInjector.instance().flutterLoader()
                .getLookupKeyForAsset(assetPath)
        }
    }
}
