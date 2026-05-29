package com.bdayadev.oidc

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Transparent receiver for the OAuth/OIDC redirect.
 *
 * Declared in this package's `AndroidManifest.xml` with an `<intent-filter>`
 * whose `<data android:scheme="${oidcRedirectScheme}"/>` is driven by a single
 * manifest placeholder the consuming app sets in its `app/build.gradle`. When
 * the Custom Tab redirects to the app's `redirect_uri`, Android routes the
 * `ACTION_VIEW` here; we hand the URI to [OidcPlugin] in-memory and finish
 * immediately.
 *
 * The activity keeps the app's DEFAULT task affinity (it does NOT set
 * `taskAffinity=""` or `singleTask`): a custom-scheme redirect resolved to an
 * activity with the app's affinity brings the app's existing task to the
 * foreground, so finishing this transparent activity returns the user straight
 * to the host `FlutterActivity` — the same proven approach used by
 * `flutter_web_auth_2`'s `CallbackActivity`. If the host process was killed
 * while the browser was open there is no in-flight flow to deliver to
 * ([OidcPlugin.handleRedirect] returns false); this mirrors the in-memory
 * limitation of comparable plugins and is documented in the README.
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
