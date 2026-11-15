package com.nexauren.adm

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Environment
import android.webkit.CookieManager
import android.webkit.DownloadListener
import android.webkit.URLUtil
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class MainActivity : FlutterActivity() {
    private val preferenceFile = "adm_preferences"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "adm/webview",
            AdmWebViewFactory(flutterEngine.dartExecutor.binaryMessenger) { url, agent, disposition, mime ->
                enqueueFromWeb(url, agent, disposition, mime)
            }
        )
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "adm/app")
            .setMethodCallHandler { call, result -> handleCall(call, result) }
    }

    private fun prefs() = getSharedPreferences(preferenceFile, Context.MODE_PRIVATE)
    private fun manager() = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getDownloads" -> result.success(readDownloads())
                "enqueueDownload" -> {
                    val url = call.argument<String>("url") ?: throw IllegalArgumentException("Link em falta.")
                    val name = call.argument<String>("name") ?: ""
                    result.success(enqueue(url, name, null, null, null))
                }
                "removeDownload" -> {
                    manager().remove(call.argument<Number>("id")?.toLong() ?: 0L)
                    result.success(true)
                }
                "openDownload" -> openDownload(call.argument<Number>("id")?.toLong() ?: 0L, result)
                "getSettings" -> result.success(prefs().all.filterKeys { it.startsWith("setting_") }
                    .mapKeys { it.key.removePrefix("setting_") })
                "setSetting" -> {
                    val key = call.argument<String>("key") ?: throw IllegalArgumentException("Chave inválida.")
                    val value = call.argument<Any>("value") ?: false
                    val editor = prefs().edit()
                    when (value) {
                        is Boolean -> editor.putBoolean("setting_" + key, value)
                        is Int -> editor.putInt("setting_" + key, value)
                        is Long -> editor.putLong("setting_" + key, value)
                        is Float -> editor.putFloat("setting_" + key, value)
                        is String -> editor.putString("setting_" + key, value)
                        else -> throw IllegalArgumentException("Tipo de preferência não suportado.")
                    }
                    editor.apply()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("ADM_NATIVE", error.message ?: "Erro nativo.", null)
        }
    }

    private fun enqueueFromWeb(url: String, agent: String, disposition: String, mime: String) {
        try { enqueue(url, "", agent, disposition, mime) }
        catch (error: Exception) { android.util.Log.e("ADM", "Falha ao iniciar download", error) }
    }

    private fun enqueue(rawUrl: String, customName: String, agent: String?, disposition: String?, mime: String?): Long {
        val uri = Uri.parse(rawUrl)
        require((uri.scheme == "https" || uri.scheme == "http") && uri.host != null) {
            "Só são permitidos links HTTP e HTTPS."
        }
        val guessed = if (customName.isNotBlank()) customName else URLUtil.guessFileName(rawUrl, disposition, mime)
        val name = sanitizeName(guessed)
        val request = DownloadManager.Request(uri)
            .setTitle(name)
            .setDescription(uri.host ?: "ADM Download")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setAllowedOverRoaming(false)
            .setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, "ADM/" + name)
        if (!mime.isNullOrBlank()) request.setMimeType(mime)
        if (!agent.isNullOrBlank()) request.addRequestHeader("User-Agent", agent)
        val cookie = CookieManager.getInstance().getCookie(rawUrl)
        if (!cookie.isNullOrBlank()) request.addRequestHeader("Cookie", cookie)
        val wifiOnly = prefs().getBoolean("setting_wifiOnly", false)
        request.setAllowedNetworkTypes(
            if (wifiOnly) DownloadManager.Request.NETWORK_WIFI
            else DownloadManager.Request.NETWORK_WIFI or DownloadManager.Request.NETWORK_MOBILE
        )
        return manager().enqueue(request)
    }

    private fun sanitizeName(value: String): String {
        val illegal = charArrayOf('/', '\\', ':', '*', '?', '"', '<', '>', '|')
        val clean = value.filterNot { it in illegal || it.code < 32 }.trim().take(180)
        return if (clean.isBlank() || clean == "." || clean == "..") "download.bin" else clean
    }

    private fun readDownloads(): List<Map<String, Any?>> {
        val cursor: Cursor = manager().query(DownloadManager.Query())
        val items = mutableListOf<Map<String, Any?>>()
        cursor.use {
            val idCol = it.getColumnIndex(DownloadManager.COLUMN_ID)
            val titleCol = it.getColumnIndex(DownloadManager.COLUMN_TITLE)
            val statusCol = it.getColumnIndex(DownloadManager.COLUMN_STATUS)
            val bytesCol = it.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
            val totalCol = it.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
            while (it.moveToNext()) {
                items.add(mapOf(
                    "id" to it.getLong(idCol),
                    "title" to it.getString(titleCol),
                    "status" to it.getInt(statusCol),
                    "downloaded" to it.getLong(bytesCol),
                    "total" to it.getLong(totalCol)
                ))
            }
        }
        return items
    }

    private fun openDownload(id: Long, result: MethodChannel.Result) {
        val uri = manager().getUriForDownloadedFile(id)
        if (uri == null) {
            result.error("NOT_READY", "O ficheiro ainda não está disponível.", null)
            return
        }
        val mime = manager().getMimeTypeForDownloadedFile(id) ?: "*/*"
        try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, "Abrir ficheiro"))
            result.success(true)
        } catch (error: Exception) {
            result.error("NO_APP", "Não existe uma aplicação compatível para abrir este ficheiro.", null)
        }
    }
}

private class AdmWebViewFactory(
    private val messenger: BinaryMessenger,
    private val onDownload: (String, String, String, String) -> Unit
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val options = args as? Map<*, *>
        val initial = options?.get("initialUrl") as? String ?: "https://www.google.com"
        return AdmWebViewPlatformView(context, messenger, viewId, initial, onDownload)
    }
}

private class AdmWebViewPlatformView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    initialUrl: String,
    private val onDownload: (String, String, String, String) -> Unit
) : PlatformView {
    private val webView = WebView(context)
    private val channel = MethodChannel(messenger, "adm/webview/" + viewId)
    private var progress = 0
    private var loading = true

    init {
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = false
            allowFileAccess = false
            allowContentAccess = false
            javaScriptCanOpenWindowsAutomatically = false
            setSupportMultipleWindows(false)
            builtInZoomControls = true
            displayZoomControls = false
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            cacheMode = WebSettings.LOAD_DEFAULT
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) safeBrowsingEnabled = true
        }
        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val target = request.url
                return when (target.scheme?.lowercase()) {
                    "http", "https" -> false
                    "mailto", "tel" -> {
                        try { context.startActivity(Intent(Intent.ACTION_VIEW, target).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
                        catch (_: Exception) { }
                        true
                    }
                    else -> true
                }
            }
            override fun onPageStarted(view: WebView, url: String, favicon: android.graphics.Bitmap?) {
                loading = true
                publishState()
            }
            override fun onPageFinished(view: WebView, url: String) {
                loading = false
                progress = 100
                publishState()
            }
        }
        webView.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView, newProgress: Int) {
                progress = newProgress
                loading = newProgress < 100
                publishState()
            }
        }
        webView.setDownloadListener(DownloadListener { url, userAgent, contentDisposition, mimeType, _ ->
            onDownload(url, userAgent ?: "", contentDisposition ?: "", mimeType ?: "")
        })
        channel.setMethodCallHandler { call, result -> handleCall(call, result) }
        loadSafely(initialUrl)
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getState" -> result.success(state())
            "loadUrl" -> {
                val url = call.argument<String>("url") ?: ""
                if (allowed(url)) {
                    loadSafely(url)
                    result.success(true)
                } else result.error("BAD_URL", "Só são permitidos endereços HTTP e HTTPS.", null)
            }
            "goBack" -> { if (webView.canGoBack()) webView.goBack(); result.success(true) }
            "goForward" -> { if (webView.canGoForward()) webView.goForward(); result.success(true) }
            "reload" -> { webView.reload(); result.success(true) }
            "stopLoading" -> { webView.stopLoading(); loading = false; publishState(); result.success(true) }
            else -> result.notImplemented()
        }
    }

    private fun allowed(value: String): Boolean {
        val uri = Uri.parse(value)
        return (uri.scheme == "https" || uri.scheme == "http") && uri.host != null
    }
    private fun loadSafely(value: String) { if (allowed(value)) webView.loadUrl(value) }
    private fun state(): Map<String, Any?> = mapOf(
        "url" to (webView.url ?: ""), "title" to (webView.title ?: ""),
        "loading" to loading, "progress" to progress,
        "canGoBack" to webView.canGoBack(), "canGoForward" to webView.canGoForward()
    )
    private fun publishState() { channel.invokeMethod("pageState", state()) }
    override fun getView() = webView
    override fun dispose() {
        channel.setMethodCallHandler(null)
        webView.stopLoading()
        webView.loadUrl("about:blank")
        webView.removeAllViews()
        webView.destroy()
    }
}
