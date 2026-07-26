package com.bdayadev.oidc

import android.app.Activity
import android.content.Intent
import android.net.Uri
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
 * Opens the authorization / end-session URL (already fully built by Dart
 * `oidc_core`, including PKCE/state/nonce) and returns the captured redirect
 * URI string back to Dart, which parses it. No OIDC logic lives here.
 *
 * Redirect capture is dual-path because [AuthTabIntent] performs no capability
 * detection: `launch()` only sets extras on an Intent, and `Builder.build()`
 * attaches a null EXTRA_SESSION so browsers without Auth Tab support treat it
 * as an ordinary Custom Tab.
 *
 *  1. Auth Tab (Chrome 137+): the redirect returns through the Activity Result
 *     API, which survives process death. Preferred when available.
 *  2. [OidcRedirectActivity]: every other browser degrades to a plain Custom
 *     Tab, which navigates to the redirect rather than intercepting it. The
 *     plugin-owned intent-filter catches that navigation. Without it the
 *     redirect resolves to no app at all.
 *
 * Whichever path fires first wins; [finishPending] resolves the Dart callback
 * exactly once.
 *
 * Path 2 requires the consuming app to declare its redirect scheme via the
 * `oidcRedirectScheme` manifest placeholder. Path 1 additionally requires a
 * [ComponentActivity] host such as `FlutterFragmentActivity`; on a plain
 * `FlutterActivity` the plugin opens a Custom Tab directly and relies on
 * path 2.
 *
 * The Dart<->native transport is the Pigeon-generated [OidcAndroidHostApi]
 * (compiler-enforced method/argument types) plus a Pigeon event channel
 * ([StreamNativeEventsStreamHandler]) for observability events.
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
    private val mainHandler = Handler(Looper.getMainLooper())

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
        val host = activity
        if (host == null) {
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
        // Must be set before the browser opens so OidcRedirectActivity can
        // reach this instance.
        activeInstance = this

        val ephemeral = options["ephemeralBrowsing"] as? Boolean == true
        emit("opening")

        // Auth Tab where the host supports it; the same intent degrades to a
        // plain Custom Tab elsewhere, where OidcRedirectActivity completes the
        // flow instead. A plain FlutterActivity has no ActivityResultLauncher,
        // so open a Custom Tab directly and rely on the intent-filter.
        //
        // `useAuthTab` overrides that default: `never` pins the Custom Tabs +
        // intent-filter path even on a ComponentActivity host, and `force`
        // refuses to silently downgrade when Auth Tab is unavailable.
        val launcher = authLauncher
        when (options["useAuthTab"] as? String ?: "auto") {
            "never" -> launchCustomTab(host, url, ephemeral, options)
            "force" -> {
                if (launcher == null) {
                    finishPending(
                        Result.failure(
                            FlutterError(
                                "NO_COMPONENT_ACTIVITY",
                                "useAuthTab: force requires a ComponentActivity host " +
                                    "(e.g. FlutterFragmentActivity) to receive the Auth Tab " +
                                    "result. Use OidcAuthTabMode.auto to allow the Custom Tabs " +
                                    "fallback.",
                                null,
                            ),
                        ),
                    )
                    return
                }
                launchAuthTab(launcher, url, ephemeral)
            }
            else -> if (launcher != null) {
                launchAuthTab(launcher, url, ephemeral)
            } else {
                launchCustomTab(host, url, ephemeral, options)
            }
        }
        scheduleFlowTimeout(options)
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

    /**
     * Opens a plain Custom Tab for hosts that are not a [ComponentActivity] and
     * therefore have no [ActivityResultLauncher]. The redirect can only return
     * through [OidcRedirectActivity] on this path.
     */
    private fun launchCustomTab(
        host: Activity,
        url: String,
        ephemeral: Boolean,
        options: Map<String, Any?>,
    ) {
        val builder = CustomTabsIntent.Builder()
            .setEphemeralBrowsingEnabled(ephemeral)
        applyCustomTabsOptions(builder, options)
        val intent = builder.build()
        applyRawIntentExtras(intent.intent, options)
        intent.launchUrl(host, Uri.parse(url))
        emit(
            "opened",
            mapOf(
                "sessionType" to if (ephemeral) "ephemeral" else "standard",
                "captureMode" to "customTabsRedirectActivity",
            ),
        )
    }

    /**
     * Delivers a redirect URI captured by the intent-filter. Returns true when
     * the in-flight flow consumed it. Runs on the main thread.
     *
     * Only a redirect matching the flow's own `redirect_uri` is accepted, so an
     * unrelated deep link cannot resolve an in-flight login.
     */
    private fun onRedirect(data: Uri): Boolean {
        if (pendingCallback == null || redirectHandled) return false
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
                "captureMode" to "customTabsRedirectActivity",
            ),
        )
        finishPending(Result.success(data.toString()))
        dismissBrowser()
        return true
    }

    /**
     * Applies the declarative `OidcNativeOptionsAndroid` fields to the builder.
     *
     * Every option here is public, documented API. Each was previously
     * serialized across the Pigeon boundary and dropped, so the Dart side
     * round-tripped a value that changed nothing.
     *
     * Unset (`null`) leaves the browser default; the model's own defaults are
     * chosen to match those, so a caller who sets nothing gets the same Intent
     * as before.
     */
    private fun applyCustomTabsOptions(
        builder: CustomTabsIntent.Builder,
        options: Map<String, Any?>,
    ) {
        (options["showTitle"] as? Boolean)?.let(builder::setShowTitle)
        (options["urlBarHidingEnabled"] as? Boolean)?.let(builder::setUrlBarHidingEnabled)

        when (options["shareState"] as? String) {
            "on" -> builder.setShareState(CustomTabsIntent.SHARE_STATE_ON)
            "off" -> builder.setShareState(CustomTabsIntent.SHARE_STATE_OFF)
            // browserDefault, or absent: leave SHARE_STATE_DEFAULT.
            else -> Unit
        }

        when (options["closeButtonPosition"] as? String) {
            "start" -> builder.setCloseButtonPosition(
                CustomTabsIntent.CLOSE_BUTTON_POSITION_START,
            )
            "end" -> builder.setCloseButtonPosition(
                CustomTabsIntent.CLOSE_BUTTON_POSITION_END,
            )
            else -> Unit
        }

        applyColorSchemes(builder, options["colorSchemes"] as? Map<*, *>)
        applyPartialCustomTabs(builder, options["partialCustomTabs"] as? Map<*, *>)
    }

    /** Maps `OidcCustomTabsColorSchemes` onto the builder. Colors are ARGB ints. */
    private fun applyColorSchemes(builder: CustomTabsIntent.Builder, schemes: Map<*, *>?) {
        if (schemes == null) return
        when (schemes["colorScheme"] as? String) {
            "light" -> builder.setColorScheme(CustomTabsIntent.COLOR_SCHEME_LIGHT)
            "dark" -> builder.setColorScheme(CustomTabsIntent.COLOR_SCHEME_DARK)
            "system" -> builder.setColorScheme(CustomTabsIntent.COLOR_SCHEME_SYSTEM)
            else -> Unit
        }
        colorParams(schemes["defaultParams"] as? Map<*, *>)?.let(
            builder::setDefaultColorSchemeParams,
        )
        colorParams(schemes["lightParams"] as? Map<*, *>)?.let {
            builder.setColorSchemeParams(CustomTabsIntent.COLOR_SCHEME_LIGHT, it)
        }
        colorParams(schemes["darkParams"] as? Map<*, *>)?.let {
            builder.setColorSchemeParams(CustomTabsIntent.COLOR_SCHEME_DARK, it)
        }
    }

    /** Builds `CustomTabColorSchemeParams`, or null when no color was supplied. */
    private fun colorParams(src: Map<*, *>?): CustomTabColorSchemeParams? {
        if (src == null) return null
        val params = CustomTabColorSchemeParams.Builder()
        var any = false
        (src["toolbarColor"] as? Number)?.let { params.setToolbarColor(it.toInt()); any = true }
        (src["secondaryToolbarColor"] as? Number)?.let {
            params.setSecondaryToolbarColor(it.toInt()); any = true
        }
        (src["navigationBarColor"] as? Number)?.let {
            params.setNavigationBarColor(it.toInt()); any = true
        }
        (src["navigationBarDividerColor"] as? Number)?.let {
            params.setNavigationBarDividerColor(it.toInt()); any = true
        }
        return if (any) params.build() else null
    }

    /**
     * Maps `OidcPartialCustomTabs` onto the builder.
     *
     * `setInitialActivityHeightPx` throws on a non-positive height, so a
     * caller's zero or negative value is dropped rather than crashing the flow.
     */
    private fun applyPartialCustomTabs(
        builder: CustomTabsIntent.Builder,
        partial: Map<*, *>?,
    ) {
        if (partial == null) return
        val height = (partial["initialHeightPx"] as? Number)?.toInt()
        if (height != null && height > 0) {
            val behavior = when (partial["resizeBehavior"] as? String) {
                "adjustable" -> CustomTabsIntent.ACTIVITY_HEIGHT_ADJUSTABLE
                "fixed" -> CustomTabsIntent.ACTIVITY_HEIGHT_FIXED
                else -> CustomTabsIntent.ACTIVITY_HEIGHT_DEFAULT
            }
            builder.setInitialActivityHeightPx(height, behavior)
        }
        (partial["toolbarCornerRadiusDp"] as? Number)?.let {
            builder.setToolbarCornerRadiusDp(it.toInt())
        }
        (partial["backgroundInteractionEnabled"] as? Boolean)?.let(
            builder::setBackgroundInteractionEnabled,
        )
    }

    /**
     * Forwards `rawIntentExtras` verbatim onto the built Intent.
     *
     * The Dart API restricts these to serializable primitives / List / Map, so
     * anything the Pigeon codec delivered is already a supported extra type.
     * Applied after `build()` so a caller cannot overwrite a builder-managed
     * extra by accident.
     */
    private fun applyRawIntentExtras(intent: Intent, options: Map<String, Any?>) {
        val extras = options["rawIntentExtras"] as? Map<*, *> ?: return
        for ((key, value) in extras) {
            val name = key as? String ?: continue
            when (value) {
                null -> Unit
                is String -> intent.putExtra(name, value)
                is Boolean -> intent.putExtra(name, value)
                is Int -> intent.putExtra(name, value)
                is Long -> intent.putExtra(name, value)
                is Double -> intent.putExtra(name, value)
                is ArrayList<*> -> intent.putExtra(name, value)
                else -> emit(
                    "rawIntentExtraSkipped",
                    mapOf("key" to name, "type" to value.javaClass.simpleName),
                )
            }
        }
    }

    /**
     * Brings the host Activity back to the front, popping the browser with it.
     *
     * `CustomTabsIntent.launchUrl` starts the browser with no
     * `FLAG_ACTIVITY_NEW_TASK`, so the Custom Tab lives in the host app's OWN
     * task: host -> CustomTab -> OidcRedirectActivity. Finishing the transparent
     * receiver pops only itself and leaves the user looking at the browser, which
     * they then have to close by hand.
     *
     * `CLEAR_TOP` pops everything above the host, taking the Custom Tab with it.
     * `SINGLE_TOP` delivers to the existing instance through `onNewIntent`
     * instead of recreating it, so the Flutter engine and its widget state
     * survive.
     *
     * Only the intent-filter path needs this. Auth Tab closes its own tab when
     * it returns the Activity Result.
     */
    private fun dismissBrowser() {
        val host = activity ?: return
        host.startActivity(
            Intent(host, host.javaClass).addFlags(
                Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP,
            ),
        )
    }

    /** Handles the Auth Tab [AuthTabIntent.AuthResult] on the main thread. */
    private fun handleAuthResult(authResult: AuthTabIntent.AuthResult) {
        // The intent-filter path may have already resolved this flow; the tab
        // then reports RESULT_CANCELED as it closes. Never override a success.
        if (pendingCallback == null || redirectHandled) return
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

    private fun cleanup() {
        pendingCallback = null
        expectedRedirect = null
        if (activeInstance === this) activeInstance = null
    }

    private fun scheduleFlowTimeout(options: Map<String, Any?>) {
        val seconds = (options["flowTimeoutSeconds"] as? Number)?.toLong() ?: return
        if (seconds <= 0) return
        val expectedFlowId = flowId
        mainHandler.postDelayed({
            if (pendingCallback != null && flowId == expectedFlowId) {
                emit("timeout", mapOf("afterSeconds" to seconds))
                finishWithCancel()
            }
        }, seconds * 1000)
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

    companion object {
        // The plugin instance currently awaiting a redirect. Set while a flow
        // is in flight so OidcRedirectActivity can deliver the captured URI
        // without needing an Activity/Binding reference.
        @Volatile
        private var activeInstance: OidcPlugin? = null

        /**
         * Delivers a redirect URI captured by [OidcRedirectActivity] to the
         * in-flight flow. Returns true if a flow consumed it. Invoked on the
         * main (UI) thread from the Activity lifecycle.
         */
        @JvmStatic
        fun handleRedirect(data: Uri): Boolean = activeInstance?.onRedirect(data) ?: false
    }
}
