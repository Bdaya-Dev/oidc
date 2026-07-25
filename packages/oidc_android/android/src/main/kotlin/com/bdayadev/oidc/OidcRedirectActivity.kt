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
 * This is the fallback capture path. Auth Tab returns the redirect through the
 * Activity Result API and never reaches here. Browsers without Auth Tab support
 * degrade to a plain Custom Tab, which navigates to the redirect rather than
 * intercepting it; without this receiver that navigation resolves to no app.
 *
 * The activity keeps the app's default task affinity, and deliberately does not
 * set `taskAffinity=""` or `singleTask`: a custom-scheme redirect resolved to an
 * activity with the app's affinity brings the existing task to the foreground,
 * so finishing this transparent activity returns the user to the host
 * `FlutterActivity`.
 *
 * The redirect is delivered in-memory, so a host process killed while the
 * browser was open has no in-flight flow to receive it and
 * [OidcPlugin.handleRedirect] returns false. Auth Tab's result API survives
 * process death, which is why it remains the preferred path.
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
