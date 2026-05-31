package com.bdayadev.oidc

import android.app.Activity
import android.app.Application
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.browser.auth.AuthTabIntent
import androidx.browser.customtabs.CustomTabColorSchemeParams
import androidx.browser.customtabs.CustomTabsIntent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/**
 * First-party Android implementation of the oidc browser primitive.
 *
 * It opens the authorization / end-session URL (already fully built by Dart
 * `oidc_core`, including PKCE/state/nonce) in a Chrome Custom Tab and returns
 * the captured redirect URI string back to Dart, which parses it. No OIDC
 * logic lives here — this replaces the `flutter_appauth` dependency with a
 * thin, dependency-light native primitive.
 *
 * The Dart<->native transport is the Pigeon-generated [OidcAndroidHostApi]
 * (compiler-enforced method/argument types) plus a Pigeon event channel
 * ([StreamNativeEventsStreamHandler]) for observability events.
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
    OidcAndroidHostApi {

    private var binding: ActivityPluginBinding? = null
    private var activity: Activity? = null

    private var pendingCallback: ((Result<String?>) -> Unit)? = null
    private var expectedRedirect: Uri? = null
    private var redirectHandled = false
    private var lifecycleCallbacks: Application.ActivityLifecycleCallbacks? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var timeoutRunnable: Runnable? = null

    // Pigeon event sink for observability events; non-null while Dart listens.
    private var eventSink: PigeonEventSink<Map<String, Any?>>? = null
    private val eventHandler = object : StreamNativeEventsStreamHandler() {
        override fun onListen(p0: Any?, sink: PigeonEventSink<Map<String, Any?>>) {
            eventSink = sink
        }

        override fun onCancel(p0: Any?) {
            eventSink = null
        }
    }
    private val mainHandler = Handler(Looper.getMainLooper())
    private var flowId: String? = null
    private var flowCounter = 0

    // Auth Tab redirect-capture launcher; non-null only when the host Activity
    // is a ComponentActivity (e.g. FlutterFragmentActivity). Required for the
    // `useAuthTab: force` path.
    private var authLauncher: ActivityResultLauncher<Intent>? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Pigeon host API (replaces the hand-rolled MethodChannel). The channel
        // names live in the generated OidcNative.g.kt / oidc_native.g.dart.
        OidcAndroidHostApi.setUp(binding.binaryMessenger, this)
        // Observability event channel.
        StreamNativeEventsStreamHandler.register(binding.binaryMessenger, eventHandler)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        OidcAndroidHostApi.setUp(binding.binaryMessenger, null)
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
        registerAuthTabLauncher(binding.activity)
    }

    /**
     * Registers an Auth Tab result launcher when the host is a
     * [ComponentActivity] (e.g. `FlutterFragmentActivity`). Uses the
     * key-based `activityResultRegistry` so it can be registered after the
     * Activity is resumed (a plugin can't register in `onCreate`). Stays null
     * for a plain `FlutterActivity`, in which case the `useAuthTab: force`
     * path falls back to Custom Tabs.
     */
    private fun registerAuthTabLauncher(host: Activity) {
        authLauncher?.unregister()
        authLauncher = (host as? ComponentActivity)?.activityResultRegistry?.register(
            "com.bdayadev.oidc.authtab",
            AuthTabIntent.AuthenticateUserResultContract(),
        ) { result -> handleAuthResult(result) }
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()

    override fun onDetachedFromActivity() = detachActivity()

    private fun detachActivity() {
        unregisterLifecycle()
        authLauncher?.unregister()
        authLauncher = null
        binding = null
        activity = null
    }
    // endregion

    // region OidcAndroidHostApi — both flows are identical natively: open a URL
    // and capture the redirect. Pigeon guarantees `url` is non-null.
    override fun authorize(
        url: String,
        redirectUri: String?,
        callbackScheme: String?,
        options: Map<String, Any?>,
        callback: (Result<String?>) -> Unit,
    ) = startFlow(url, redirectUri, options, callback)

    override fun endSession(
        url: String,
        redirectUri: String?,
        callbackScheme: String?,
        options: Map<String, Any?>,
        callback: (Result<String?>) -> Unit,
    ) = startFlow(url, redirectUri, options, callback)

    override fun cancel() = finishWithCancel()
    // endregion

    private fun startFlow(
        url: String,
        redirectUri: String?,
        options: Map<String, Any?>,
        callback: (Result<String?>) -> Unit,
    ) {
        val currentActivity = activity
        if (currentActivity == null) {
            callback(
                Result.failure(
                    FlutterError("NO_ACTIVITY", "Plugin is not attached to an Activity", null),
                ),
            )
            return
        }
        // Supersede any in-flight request so we never leak a pending result.
        finishWithCancel()

        pendingCallback = callback
        expectedRedirect = redirectUri?.let(Uri::parse)
        redirectHandled = false
        flowId = (++flowCounter).toString()

        val ephemeral = options["ephemeralBrowsing"] as? Boolean == true
        val useAuthTab = options["useAuthTab"] as? String ?: "auto"
        emit("opening")

        // Auth Tab path (Chrome 137+): the browser captures the redirect and
        // returns it via the ActivityResult API — no OidcRedirectActivity / no
        // manifest placeholder. Opt-in via `useAuthTab: force`; requires a
        // ComponentActivity host (e.g. FlutterFragmentActivity).
        val launcher = authLauncher
        if (useAuthTab == "force" && launcher != null) {
            launchAuthTab(launcher, url, ephemeral)
            scheduleFlowTimeout(options)
            return
        }
        if (useAuthTab == "force" && launcher == null) {
            // Requested but unavailable (plain FlutterActivity) — fall back.
            emit("warning", mapOf("code" to "AUTH_TAB_REQUIRES_COMPONENT_ACTIVITY"))
        }

        // Default: Custom Tabs + plugin-owned OidcRedirectActivity.
        activeInstance = this
        registerLifecycle(currentActivity)
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
            scheduleFlowTimeout(options)
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
            finishPending(
                Result.failure(
                    FlutterError("START_FAILED", "No browser available to launch: ${e.message}", null),
                ),
            )
        }
    }

    private fun launchAuthTab(
        launcher: ActivityResultLauncher<Intent>,
        url: String,
        ephemeral: Boolean,
    ) {
        val authTab = AuthTabIntent.Builder()
            .setEphemeralBrowsingEnabled(ephemeral)
            .build()
        val redirect = expectedRedirect
        val host = redirect?.host
        if (redirect?.scheme.equals("https", ignoreCase = true) && host != null) {
            // https / App-Links variant.
            authTab.launch(launcher, Uri.parse(url), host, redirect?.path ?: "/")
        } else {
            authTab.launch(launcher, Uri.parse(url), redirect?.scheme ?: "")
        }
        emit(
            "opened",
            mapOf(
                "sessionType" to if (ephemeral) "ephemeral" else "standard",
                "captureMode" to "authTab",
            ),
        )
    }

    /** Handles the Auth Tab [AuthTabIntent.AuthResult] on the main thread. */
    private fun handleAuthResult(authResult: AuthTabIntent.AuthResult) {
        if (pendingCallback == null) return
        when (authResult.resultCode) {
            AuthTabIntent.RESULT_OK -> {
                val uri = authResult.resultUri
                redirectHandled = true
                if (uri != null) {
                    emit(
                        "redirectReceived",
                        mapOf(
                            "scheme" to uri.scheme,
                            "host" to uri.host,
                            "hasCode" to (uri.getQueryParameter("code") != null),
                            "hasState" to (uri.getQueryParameter("state") != null),
                            "hasError" to (uri.getQueryParameter("error") != null),
                        ),
                    )
                }
                finishPending(Result.success(uri?.toString()))
            }
            AuthTabIntent.RESULT_VERIFICATION_FAILED -> {
                emit("failed", mapOf("error" to mapOf("kind" to "verificationFailed")))
                finishPending(
                    Result.failure(
                        FlutterError("VERIFICATION_FAILED", "App Links verification failed", null),
                    ),
                )
            }
            AuthTabIntent.RESULT_VERIFICATION_TIMED_OUT -> {
                emit("failed", mapOf("error" to mapOf("kind" to "verificationTimedOut")))
                finishPending(
                    Result.failure(
                        FlutterError("VERIFICATION_TIMED_OUT", "App Links verification timed out", null),
                    ),
                )
            }
            else -> {
                // RESULT_CANCELED / RESULT_UNKNOWN_CODE.
                emit("cancelled")
                finishPending(
                    Result.failure(
                        FlutterError("USER_CANCELLED", "The flow was cancelled by the user", null),
                    ),
                )
            }
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
        finishPending(Result.success(data.toString()))
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
                if (a === host && sawPause && !redirectHandled && pendingCallback != null) {
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
        cancelFlowTimeout()
        pendingCallback = null
        expectedRedirect = null
        unregisterLifecycle()
        if (activeInstance === this) activeInstance = null
    }

    private fun scheduleFlowTimeout(options: Map<String, Any?>) {
        val seconds = (options["flowTimeoutSeconds"] as? Number)?.toLong() ?: return
        if (seconds <= 0) return
        val runnable = Runnable {
            if (pendingCallback != null) {
                emit("timeout", mapOf("afterSeconds" to seconds))
                finishWithCancel()
            }
        }
        timeoutRunnable = runnable
        mainHandler.postDelayed(runnable, seconds * 1000)
    }

    private fun cancelFlowTimeout() {
        timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        timeoutRunnable = null
    }

    /** Resolves and clears the in-flight callback exactly once. */
    private fun finishPending(result: Result<String?>) {
        val cb = pendingCallback ?: return
        cleanup()
        cb(result)
    }

    private fun finishWithCancel() {
        if (pendingCallback == null) return
        emit("cancelled")
        finishPending(
            Result.failure(
                FlutterError("USER_CANCELLED", "The flow was cancelled by the user", null),
            ),
        )
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
