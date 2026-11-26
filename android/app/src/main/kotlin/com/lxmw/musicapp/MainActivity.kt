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
            }
            webChromeClient = WebChromeClient()
            // JS → Android bridge
            addJavascriptInterface(JsBridge(), "AndroidBridge")
        }

        youtubeWebView = webView

        // Enable third-party cookies (required for YouTube embeds)
        android.webkit.CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true)

        // Load the HTML asset from Flutter assets
        val html = loadAssetFromFlutter("assets/youtube_player.html")
        webView.loadDataWithBaseURL(
            "https://www.youtube.com/",
            html,
            "text/html",
            "utf-8",
            null
        )

        // Add to activity's root view so it's available immediately
        val rootView = window.decorView as android.view.ViewGroup
        if (rootView.findViewById<WebView>(android.R.id.content) == null) {
            // Small visible WebView (mini-player) — YouTube requires the embed
            // to be rendered on-screen for autoplay. Mini-player in the top-right
            // corner, controlled by the app's player buttons.
            webView.setBackgroundColor(0x00000000)
            val params = android.widget.FrameLayout.LayoutParams(
                200,
                112
            ).apply {
                leftMargin = rootView.width - 210
                topMargin = 40
            }
            rootView.addView(webView, params)
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

        val webView = youtubeWebView!!

        // Remove from activity view
        (webView.parent as? android.view.ViewGroup)?.removeView(webView)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )

        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        try {
            wm.addView(webView, params)
            overlayWindow = webView
        } catch (e: Exception) {
            // Fallback: re-add to activity root view
            val rootView = window.decorView as android.view.ViewGroup
            rootView.addView(webView, WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT
            ))
        }
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
        // Reattach WebView from overlay to activity if needed
        if (overlayWindow != null && youtubeWebView != null) {
            runOnUiThread {
                val webView = youtubeWebView!!
                val wm = getSystemService(WINDOW_SERVICE) as WindowManager
                try {
                    wm.removeView(webView)
                } catch (e: Exception) {
                    // Already removed or not attached to WM
                }
                overlayWindow = null
                val rootView = window.decorView as android.view.ViewGroup
                if (webView.parent == null) {
                    rootView.addView(webView, WindowManager.LayoutParams(
                        WindowManager.LayoutParams.MATCH_PARENT,
                        WindowManager.LayoutParams.MATCH_PARENT
                    ))
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Keep WebView alive unless the activity is finishing
        if (isFinishing) {
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
