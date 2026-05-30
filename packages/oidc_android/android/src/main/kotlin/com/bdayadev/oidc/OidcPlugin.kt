package com.bdayadev.oidc

import android.app.Activity
import android.app.Application
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.browser.customtabs.CustomTabColorSchemeParams
import androidx.browser.customtabs.CustomTabsIntent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * First-party Android implementation of the oidc browser primitive.
 *
 * It opens the authorization / end-session URL (already fully built by Dart
 * `oidc_core`, including PKCE/state/nonce) in a Chrome Custom Tab and returns
 * the captured redirect URI string back to Dart, which parses it. No OIDC
 * logic lives here — this replaces the `flutter_appauth` dependency with a
 * thin, dependency-light native primitive.
 *
 * The redirect is captured by the plugin-owned [OidcRedirectActivity], declared
 * in this package's `AndroidManifest.xml` with an intent-filter whose
 * `<data android:scheme="${oidcRedirectScheme}"/>` is driven by a single
 * manifest placeholder. The consuming app sets ONE line in its
 * `app/build.gradle` (`manifestPlaceholders += ['oidcRedirectScheme': ...]`) —
 * no `<intent-filter>` and no `launchMode`/`taskAffinity` changes on its own
 * Activity (which closes the #174 class of misconfiguration at the root).
 */
class OidcPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var binding: ActivityPluginBinding? = null
    private var activity: Activity? = null

    private var pendingResult: MethodChannel.Result? = null
    private var expectedRedirect: Uri? = null
    private var redirectHandled = false
    private var lifecycleCallbacks: Application.ActivityLifecycleCallbacks? = null

    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var flowId: String? = null
    private var flowCounter = 0

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Must match `OidcNativeChannels.android` in oidc_platform_interface.
        channel = MethodChannel(binding.binaryMessenger, "com.bdayadev.oidc/android")
        channel.setMethodCallHandler(this)

        // Observability event channel (OidcNativeChannels.androidEvents).
        eventChannel = EventChannel(binding.binaryMessenger, "com.bdayadev.oidc/android/events")
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        eventSink = null
    }

    /** Emits an observability event to Dart on the main thread. */
    private fun emit(type: String, extra: Map<String, Any?> = emptyMap()) {
        val sink = eventSink ?: return
        val event = HashMap<String, Any?>()
        event["type"] = type
        event["flowId"] = flowId
        event["timestampMs"] = System.currentTimeMillis()
        event.putAll(extra)
        mainHandler.post { sink.success(event) }
    }

    // region ActivityAware — we only need the Activity to launch the Custom Tab
    // and to observe its lifecycle for cancellation; the redirect itself is
    // captured by OidcRedirectActivity, not by an Activity intent-filter.
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        this.activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()

    override fun onDetachedFromActivity() = detachActivity()

    private fun detachActivity() {
        unregisterLifecycle()
        binding = null
        activity = null
    }
    // endregion

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // Both flows are identical natively: open a URL, capture the redirect.
            "authorize", "endSession" -> startFlow(call, result)
            "cancel" -> {
                finishWithCancel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startFlow(call: MethodCall, result: MethodChannel.Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Plugin is not attached to an Activity", null)
            return
        }
        val url = call.argument<String>("url")
        if (url == null) {
            result.error("BAD_ARGS", "Missing `url` argument", null)
            return
        }
        // Supersede any in-flight request so we never leak a pending result.
        finishWithCancel()

        pendingResult = result
        expectedRedirect = call.argument<String>("redirectUri")?.let(Uri::parse)
        redirectHandled = false
        flowId = (++flowCounter).toString()
        activeInstance = this
        registerLifecycle(currentActivity)

        val options = call.argument<Map<String, Any?>>("options")
        val ephemeral = options?.get("ephemeralBrowsing") as? Boolean == true
        emit("opening")

        try {
            val customTabs = buildCustomTabsIntent(options)
            // launchUrl issues an ACTION_VIEW intent, which already falls back
            // to the default browser when no Custom Tabs provider is present;
            // the only un-handled case is "no browser installed at all".
            customTabs.launchUrl(currentActivity, Uri.parse(url))
            emit(
                "opened",
                mapOf(
                    "sessionType" to if (ephemeral) "ephemeral" else "standard",
                    "captureMode" to "customTabsRedirectActivity",
                ),
            )
        } catch (e: ActivityNotFoundException) {
            cleanup()
            emit(
                "failed",
                mapOf(
                    "error" to mapOf(
                        "kind" to "noBrowserAvailable",
                        "message" to e.message,
                    ),
                ),
            )
            result.error("START_FAILED", "No browser available to launch: ${e.message}", null)
        }
    }

    /**
     * Called by [OidcRedirectActivity] with the captured redirect URI. Returns
     * true if the in-flight flow consumed it. Runs on the main thread.
     */
    private fun onRedirect(data: Uri): Boolean {
        val expected = expectedRedirect ?: return false
        if (!data.scheme.equals(expected.scheme, ignoreCase = true)) return false
        // Custom-scheme redirects may omit a host; match host only when present.
        if (!expected.host.isNullOrEmpty() &&
            !data.host.equals(expected.host, ignoreCase = true)
        ) {
            return false
        }
        redirectHandled = true
        emit(
            "redirectReceived",
            mapOf(
                "scheme" to data.scheme,
                "host" to data.host,
                "hasCode" to (data.getQueryParameter("code") != null),
                "hasState" to (data.getQueryParameter("state") != null),
                "hasError" to (data.getQueryParameter("error") != null),
            ),
        )
        val result = pendingResult
        cleanup()
        result?.success(data.toString())
        return true
    }

    /**
     * Detects user cancellation: if the host Activity is paused (Custom Tab in
     * front) and then resumed WITHOUT a redirect arriving, the user dismissed
     * the tab.
     */
    private fun registerLifecycle(host: Activity) {
        unregisterLifecycle()
        val callbacks = object : Application.ActivityLifecycleCallbacks {
            private var sawPause = false

            override fun onActivityPaused(a: Activity) {
                if (a === host) sawPause = true
            }

            override fun onActivityResumed(a: Activity) {
                if (a === host && sawPause && !redirectHandled && pendingResult != null) {
                    finishWithCancel()
                }
            }

            override fun onActivityCreated(a: Activity, b: Bundle?) {}
            override fun onActivityStarted(a: Activity) {}
            override fun onActivityStopped(a: Activity) {}
            override fun onActivitySaveInstanceState(a: Activity, b: Bundle) {}
            override fun onActivityDestroyed(a: Activity) {}
        }
        lifecycleCallbacks = callbacks
        host.application.registerActivityLifecycleCallbacks(callbacks)
    }

    private fun unregisterLifecycle() {
        val callbacks = lifecycleCallbacks ?: return
        activity?.application?.unregisterActivityLifecycleCallbacks(callbacks)
        lifecycleCallbacks = null
    }

    private fun cleanup() {
        pendingResult = null
        expectedRedirect = null
        unregisterLifecycle()
        if (activeInstance === this) activeInstance = null
    }

    private fun finishWithCancel() {
        val result = pendingResult ?: return
        emit("cancelled")
        cleanup()
        result.error("USER_CANCELLED", "The flow was cancelled by the user", null)
    }

    /**
     * Builds a [CustomTabsIntent] from the serialized `OidcNativeOptionsAndroid`
     * map forwarded by Dart. Unknown / unsupported keys are ignored. The
     * service-bound options (preferred browser package, warmup, Auth Tab) are
     * handled elsewhere; non-serializable decorations (RemoteViews, Bitmap,
     * PendingIntent, animation resources) go through a native builder hook.
     */
    private fun buildCustomTabsIntent(options: Map<*, *>?): CustomTabsIntent {
        val b = CustomTabsIntent.Builder()
        if (options == null) return b.build()

        (options["showTitle"] as? Boolean)?.let { b.setShowTitle(it) }
        (options["urlBarHidingEnabled"] as? Boolean)?.let { b.setUrlBarHidingEnabled(it) }
        if (options["ephemeralBrowsing"] as? Boolean == true) {
            // Best-effort incognito hint; the browser decides if it honors it.
            b.setEphemeralBrowsingEnabled(true)
        }

        when (options["shareState"] as? String) {
            "on" -> b.setShareState(CustomTabsIntent.SHARE_STATE_ON)
            "off" -> b.setShareState(CustomTabsIntent.SHARE_STATE_OFF)
            "browserDefault" -> b.setShareState(CustomTabsIntent.SHARE_STATE_DEFAULT)
        }
        when (options["closeButtonPosition"] as? String) {
            "start" -> b.setCloseButtonPosition(CustomTabsIntent.CLOSE_BUTTON_POSITION_START)
            "end" -> b.setCloseButtonPosition(CustomTabsIntent.CLOSE_BUTTON_POSITION_END)
            "defaultPosition" ->
                b.setCloseButtonPosition(CustomTabsIntent.CLOSE_BUTTON_POSITION_DEFAULT)
        }

        (options["colorSchemes"] as? Map<*, *>)?.let { cs ->
            when (cs["colorScheme"] as? String) {
                "light" -> b.setColorScheme(CustomTabsIntent.COLOR_SCHEME_LIGHT)
                "dark" -> b.setColorScheme(CustomTabsIntent.COLOR_SCHEME_DARK)
                "system" -> b.setColorScheme(CustomTabsIntent.COLOR_SCHEME_SYSTEM)
            }
            colorParams(cs["defaultParams"])?.let { b.setDefaultColorSchemeParams(it) }
            colorParams(cs["lightParams"])?.let {
                b.setColorSchemeParams(CustomTabsIntent.COLOR_SCHEME_LIGHT, it)
            }
            colorParams(cs["darkParams"])?.let {
                b.setColorSchemeParams(CustomTabsIntent.COLOR_SCHEME_DARK, it)
            }
        }

        (options["partialCustomTabs"] as? Map<*, *>)?.let { p ->
            (p["initialHeightPx"] as? Number)?.toInt()?.let { h ->
                val behavior = when (p["resizeBehavior"] as? String) {
                    "adjustable" -> CustomTabsIntent.ACTIVITY_HEIGHT_ADJUSTABLE
                    "fixed" -> CustomTabsIntent.ACTIVITY_HEIGHT_FIXED
                    else -> CustomTabsIntent.ACTIVITY_HEIGHT_DEFAULT
                }
                b.setInitialActivityHeightPx(h, behavior)
            }
            (p["toolbarCornerRadiusDp"] as? Number)?.toInt()?.let {
                b.setToolbarCornerRadiusDp(it)
            }
            (p["backgroundInteractionEnabled"] as? Boolean)?.let {
                b.setBackgroundInteractionEnabled(it)
            }
        }

        val customTabs = b.build()
        // Raw, serializable passthrough extras (primitives only).
        (options["rawIntentExtras"] as? Map<*, *>)?.forEach { (k, v) ->
            if (k is String) putExtra(customTabs.intent, k, v)
        }
        return customTabs
    }

    private fun colorParams(raw: Any?): CustomTabColorSchemeParams? {
        val m = raw as? Map<*, *> ?: return null
        val cb = CustomTabColorSchemeParams.Builder()
        // Colors arrive as ARGB; channel ints > 0x7FFFFFFF arrive as Long, so
        // read as Number and narrow to the signed 32-bit ARGB value.
        (m["toolbarColor"] as? Number)?.toInt()?.let { cb.setToolbarColor(it) }
        (m["secondaryToolbarColor"] as? Number)?.toInt()?.let {
            cb.setSecondaryToolbarColor(it)
        }
        (m["navigationBarColor"] as? Number)?.toInt()?.let { cb.setNavigationBarColor(it) }
        (m["navigationBarDividerColor"] as? Number)?.toInt()?.let {
            cb.setNavigationBarDividerColor(it)
        }
        return cb.build()
    }

    private fun putExtra(intent: Intent, key: String, value: Any?) {
        when (value) {
            is String -> intent.putExtra(key, value)
            is Boolean -> intent.putExtra(key, value)
            is Int -> intent.putExtra(key, value)
            is Long -> intent.putExtra(key, value)
            is Double -> intent.putExtra(key, value)
            // Non-primitive extras can't be set here; use the native hook.
        }
    }

    companion object {
        // The plugin instance currently awaiting a redirect. Set while a flow
        // is in flight so OidcRedirectActivity can deliver the captured URI
        // without needing an Activity/Binding reference.
        @Volatile
        private var activeInstance: OidcPlugin? = null

        /**
         * Delivers a captured redirect URI from [OidcRedirectActivity] to the
         * in-flight flow. Returns true if a flow consumed it. Invoked on the
         * main (UI) thread from the Activity lifecycle.
         */
        @JvmStatic
        fun handleRedirect(data: Uri): Boolean = activeInstance?.onRedirect(data) ?: false
    }
}
