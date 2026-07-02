package com.bdayadev.oidc

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.browser.auth.AuthTabIntent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/**
 * First-party Android implementation of the oidc browser primitive.
 *
 * Opens the authorization / end-session URL (already fully built by Dart
 * `oidc_core`, including PKCE/state/nonce) via [AuthTabIntent] and returns
 * the captured redirect URI string back to Dart, which parses it. No OIDC
 * logic lives here — this replaces the `flutter_appauth` dependency with a
 * thin, dependency-light native primitive.
 *
 * Auth Tab (Chrome 137+) captures the redirect via the Activity Result API,
 * which survives process death. On older browsers it falls back to Custom
 * Tabs automatically (built into [AuthTabIntent] via a null EXTRA_SESSION).
 * No intent-filter, no manifest placeholder, and no separate redirect
 * Activity is needed — the host must be a [ComponentActivity] (e.g.
 * `FlutterFragmentActivity`).
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
        if (activity == null) {
            callback(
                Result.failure(
                    FlutterError("NO_ACTIVITY", "Plugin is not attached to an Activity", null),
                ),
            )
            return
        }
        val launcher = authLauncher
        if (launcher == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "NO_COMPONENT_ACTIVITY",
                        "Auth Tab requires a ComponentActivity host (e.g. FlutterFragmentActivity). " +
                            "Change your MainActivity to extend FlutterFragmentActivity.",
                        null,
                    ),
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
        emit("opening")

        // Always use Auth Tab. On Chrome 137+ it uses the native Auth Tab API
        // (redirect captured via the Activity Result API, which survives process
        // death). On older browsers it falls back to Custom Tabs automatically
        // (built into AuthTabIntent via a null EXTRA_SESSION). Either way the
        // redirect is returned through the ActivityResultLauncher callback
        // (handleAuthResult), NOT through an intent-filter / OidcRedirectActivity.
        launchAuthTab(launcher, url, ephemeral)
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

    private fun cleanup() {
        pendingCallback = null
        expectedRedirect = null
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
}
