package com.lxmw.musicapp

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import com.pichillilorenzo.flutter_inappwebview_android.InAppWebViewFlutterPlugin
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {

    private var youtubeChannel: MethodChannel? = null

    companion object {
        @Volatile private var eventChannel: MethodChannel? = null

        fun forwardWebEvent(context: Context, json: String) {
            val ch = eventChannel ?: return
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                ch.invokeMethod("onEvent", json)
            }
        }

        fun setEventChannel(ch: MethodChannel?) { eventChannel = ch }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(InAppWebViewFlutterPlugin())

        // === Battery ===
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.lxmw.musicapp/battery")
            .setMethodCallHandler { call, result ->
                if (call.method == "requestIgnoreBatteryOptimizations") {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                            startActivity(Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            })
                        }
                    }
                    result.success(null)
                } else result.notImplemented()
            }

        // === Install APK ===
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.lxmw.musicapp/install")
            .setMethodCallHandler { call, result ->
                if (call.method == "installApk") {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        val uri = FileProvider.getUriForFile(this, "${applicationContext.packageName}.fileprovider", File(path))
                        startActivity(Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                        })
                        result.success(null)
                    } else result.error("INVALID_PATH", "APK path is null", null)
                } else result.notImplemented()
            }

        // === YouTube Surface ===
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.lxmw.musicapp/youtube_surface")
        youtubeChannel = ch
        setEventChannel(ch)

        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "ensureReady" -> {
                    startWebViewService()
                    result.success(null)
                }
                "moveToOverlay" -> {
                    WebViewPlayerService.instance?.ensureOverlayWindow()
                    result.success(null)
                }
                "cmd" -> {
                    val command = call.argument<String>("command") ?: ""
                    val args = call.arguments as Map<*, *>
                    val svc = WebViewPlayerService.instance
                    if (svc != null) {
                        svc.sendCommand(buildJs(command, args))
                        when (command) {
                            "load", "play" -> {
                                // resumeTimers re-enables JS setInterval paused by Android
                                svc.webView?.resumeTimers()
                                svc.acquireWakeLock()
                            }
                            "stop" -> svc.releaseWakeLock()
                        }
                    }
                    result.success(null)
                }
                "hasOverlayPermission" -> result.success(hasOverlayPermission())
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(null)
                }
                "releaseWakeLock" -> {
                    WebViewPlayerService.instance?.releaseWakeLock()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ── Service ───────────────────────────────────────────────────────────

    private fun startWebViewService() {
        val intent = Intent(this, WebViewPlayerService::class.java).apply {
            action = WebViewPlayerService.ACTION_START
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
        else startService(intent)
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            WebViewPlayerService.instance?.ensureOverlayWindow()
        }, 500)
    }

    // ── JS builder ────────────────────────────────────────────────────────

    private fun buildJs(command: String, args: Map<*, *>): String {
        val jsArgs = when (command) {
            "load" -> {
                val videoId = args["videoId"] as? String ?: ""
                val startMs = (args["startMs"] as? Number)?.toLong() ?: 0L
                "\"$videoId\", ${startMs / 1000.0}"
            }
            "crossfade" -> {
                val videoId = args["videoId"] as? String ?: ""
                val startMs = (args["startMs"] as? Number)?.toLong() ?: 0L
                "\"$videoId\", ${startMs / 1000.0}"
            }
            "seek" -> "${(args["positionMs"] as? Number)?.toLong()?.div(1000.0) ?: 0.0}"
            "setVolume" -> "${((args["volume"] as? Number)?.toDouble()?.times(100))?.toInt() ?: 100}"
            "play", "pause", "stop" -> ""
            else -> args.filterKeys { it != "command" }.values.joinToString(", ") { v ->
                when (v) {
                    is String -> "\"${v.replace("\\", "\\\\").replace("\"", "\\\"")}\""
                    is Number, is Boolean -> v.toString()
                    else -> "null"
                }
            }
        }
        return "window.__cmd(\"$command\"${if (jsArgs.isNotEmpty()) ", $jsArgs" else ""})"
    }

    // ── Overlay permission ────────────────────────────────────────────────

    private fun hasOverlayPermission() =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) Settings.canDrawOverlays(this) else true

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
        }
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────

    override fun onResume() {
        super.onResume()
        setEventChannel(youtubeChannel)
        WebViewPlayerService.instance?.webView?.resumeTimers()
    }

    override fun onPause() {
        super.onPause()
        // WebView lives in WebViewPlayerService — do not pause it here
    }

    override fun onDestroy() {
        setEventChannel(null)
        super.onDestroy()
    }
}
