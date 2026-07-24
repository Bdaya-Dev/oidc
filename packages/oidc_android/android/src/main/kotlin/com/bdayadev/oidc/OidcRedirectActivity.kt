package com.bdayadev.oidc

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Transparent receiver for the OAuth/OIDC redirect.
 *
 * Declared in this package's `AndroidManifest.xml` with an `<intent-filter>`
 * whose `<data android:scheme="${oidcRedirectScheme}"/>` is driven by a single
 * manifest placeholder the consuming app sets in its `app/build.gradle`.
 *
 * This is the FALLBACK capture path. Auth Tab (Chrome 137+) returns the
 * redirect through the Activity Result API and never reaches here. Every other
 * browser — Firefox, Samsung Internet, older Chrome, AOSP WebView-only images —
 * silently degrades to a plain Custom Tab, which does NOT intercept the
 * redirect: it simply navigates to it. Without this receiver that navigation
 * resolves to no app at all and the user is left staring at a blank tab
 * (issue #418).
 *
 * The activity keeps the app's DEFAULT task affinity (it does NOT set
 * `taskAffinity=""` or `singleTask`): a custom-scheme redirect resolved to an
 * activity with the app's affinity brings the app's existing task to the
 * foreground, so finishing this transparent activity returns the user straight
 * to the host `FlutterActivity` — the same proven approach used by
 * `flutter_web_auth_2`'s `CallbackActivity`. If the host process was killed
 * while the browser was open there is no in-flight flow to deliver to
 * ([OidcPlugin.handleRedirect] returns false); Auth Tab's result API does
 * survive process death, which is why it stays the preferred path.
 */
class OidcRedirectActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        deliver(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        deliver(intent)
    }

    private fun deliver(intent: Intent?) {
        intent?.data?.let { OidcPlugin.handleRedirect(it) }
        finish()
    }
}
