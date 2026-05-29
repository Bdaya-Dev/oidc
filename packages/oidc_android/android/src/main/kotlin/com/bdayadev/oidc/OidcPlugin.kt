package com.bdayadev.oidc

import android.app.Activity
import android.app.Application
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.browser.customtabs.CustomTabsIntent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * First-party Android implementation of the oidc browser primitive.
 *
 * It opens the authorization / end-session URL (already fully built by Dart
 * `oidc_core`, including PKCE/state/nonce) in a Chrome Custom Tab and returns
 * the captured redirect URI string back to Dart, which parses it. No OIDC
 * logic lives here — this replaces the `flutter_appauth` dependency with a
 * thin, dependency-light native primitive.
 *
 * The redirect is delivered back to the app's launcher Activity, so the
 * consuming app must declare an `intent-filter` for its `redirect_uri` scheme
 * on that Activity (see the package README).
 */
class OidcPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.NewIntentListener {

    private lateinit var channel: MethodChannel
    private var binding: ActivityPluginBinding? = null
    private var activity: Activity? = null

    private var pendingResult: MethodChannel.Result? = null
    private var expectedRedirect: Uri? = null
    private var redirectHandled = false
    private var lifecycleCallbacks: Application.ActivityLifecycleCallbacks? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "oidc_android")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // region ActivityAware
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        this.activity = binding.activity
        binding.addOnNewIntentListener(this)
        // Handle a redirect that (re)started the Activity on a cold start.
        binding.activity.intent?.let { handleRedirect(it) }
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()

    override fun onDetachedFromActivity() = detachActivity()

    private fun detachActivity() {
        binding?.removeOnNewIntentListener(this)
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
        // Cancel any in-flight request so we never leak a pending result.
        finishWithCancel()

        pendingResult = result
        expectedRedirect = call.argument<String>("redirectUri")?.let(Uri::parse)
        redirectHandled = false
        registerLifecycle(currentActivity)

        try {
            val customTabs = CustomTabsIntent.Builder().build()
            customTabs.launchUrl(currentActivity, Uri.parse(url))
        } catch (e: Exception) {
            // No Custom Tabs provider; fall back to the default browser.
            try {
                currentActivity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            } catch (e2: Exception) {
                pendingResult = null
                unregisterLifecycle()
                result.error("START_FAILED", "Could not launch a browser: ${e2.message}", null)
            }
        }
    }

    override fun onNewIntent(intent: Intent): Boolean {
        activity?.intent = intent
        return handleRedirect(intent)
    }

    private fun handleRedirect(intent: Intent): Boolean {
        // #128: a null data Intent is not a failure, just not our redirect.
        val data = intent.data ?: return false
        val expected = expectedRedirect ?: return false
        if (!data.scheme.equals(expected.scheme, ignoreCase = true)) return false
        // Custom-scheme redirects may omit a host; match host only when present.
        if (!expected.host.isNullOrEmpty() &&
            !data.host.equals(expected.host, ignoreCase = true)
        ) {
            return false
        }
        redirectHandled = true
        val result = pendingResult
        pendingResult = null
        unregisterLifecycle()
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

    private fun finishWithCancel() {
        val result = pendingResult ?: return
        pendingResult = null
        unregisterLifecycle()
        result.error("USER_CANCELLED", "The flow was cancelled by the user", null)
    }
}
