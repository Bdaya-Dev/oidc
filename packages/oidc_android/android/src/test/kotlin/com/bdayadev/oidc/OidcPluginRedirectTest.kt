package com.bdayadev.oidc

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Native redirect-capture tests for [OidcPlugin].
 *
 * These cover what the Dart suite structurally cannot: it mocks the Pigeon
 * channel and returns a canned redirect URI, so it asserts nothing about the
 * native side's ability to capture one.
 *
 * The scenario here is a browser without Auth Tab support, where [AuthTabIntent]
 * degrades to a plain Custom Tab, no Activity Result is delivered, and the flow
 * can only complete through [OidcRedirectActivity].
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class OidcPluginRedirectTest {

    private lateinit var plugin: OidcPlugin
    private lateinit var activity: Activity

    /** A non-ComponentActivity host, which is the Custom Tab path. */
    @Before
    fun setUp() {
        plugin = OidcPlugin()
        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val binding = mock(ActivityPluginBinding::class.java)
        `when`(binding.activity).thenReturn(activity)
        plugin.onAttachedToActivity(binding)
    }

    private fun startAuthorize(
        redirectUri: String = "com.example.app://callback",
    ): MutableList<Result<String?>> {
        val results = mutableListOf<Result<String?>>()
        plugin.authorize(
            "https://op.example.com/authorize?client_id=c&state=s",
            redirectUri,
            Uri.parse(redirectUri).scheme,
            emptyMap(),
        ) { results.add(it) }
        return results
    }

    @Test
    fun `intent-filter redirect completes a flow on a browser without Auth Tab`() {
        val results = startAuthorize()
        assertTrue(results.isEmpty(), "flow must stay pending until the redirect arrives")

        val consumed = OidcPlugin.handleRedirect(
            Uri.parse("com.example.app://callback?code=code-1&state=s"),
        )

        assertTrue(consumed, "the in-flight flow must consume its own redirect")
        assertEquals(1, results.size)
        assertEquals(
            "com.example.app://callback?code=code-1&state=s",
            results.single().getOrNull(),
        )
    }

    @Test
    fun `consuming the redirect brings the host forward and clears the Custom Tab`() {
        // CustomTabsIntent.launchUrl starts the browser with no
        // FLAG_ACTIVITY_NEW_TASK, so it sits in the host app's OWN task:
        //   host -> CustomTab -> OidcRedirectActivity
        // Finishing the transparent receiver pops only itself and leaves the
        // user looking at the browser, which they then have to close by hand.
        // Consuming the redirect must therefore re-launch the host with
        // CLEAR_TOP, which pops the Custom Tab off the task with it.
        startAuthorize()
        // Drain the browser Intent that starting the flow queued, so the
        // assertion below reads the redirect's own re-launch and not that.
        assertNotNull(shadowOf(activity).nextStartedActivity, "sanity: the browser was launched")

        assertTrue(OidcPlugin.handleRedirect(Uri.parse("com.example.app://callback?code=c")))

        val started = shadowOf(activity).nextStartedActivity
        assertNotNull(started, "the host must be re-launched to clear the browser above it")
        assertEquals(activity.javaClass.name, started.component?.className)
        assertTrue(
            started.flags and Intent.FLAG_ACTIVITY_CLEAR_TOP != 0,
            "FLAG_ACTIVITY_CLEAR_TOP is what pops the Custom Tab off the task",
        )
        assertTrue(
            started.flags and Intent.FLAG_ACTIVITY_SINGLE_TOP != 0,
            "SINGLE_TOP delivers to the existing host via onNewIntent instead of recreating it",
        )
    }

    @Test
    fun `a redirect for a different scheme is not consumed`() {
        val results = startAuthorize()

        val consumed = OidcPlugin.handleRedirect(Uri.parse("com.other.app://callback?code=x"))

        assertFalse(consumed, "an unrelated deep link must not resolve this flow")
        assertTrue(results.isEmpty(), "the flow must still be pending")
    }

    @Test
    fun `a redirect with no flow in flight is not consumed`() {
        assertFalse(OidcPlugin.handleRedirect(Uri.parse("com.example.app://callback?code=x")))
    }

    @Test
    fun `a host mismatch is rejected when the expected redirect declares one`() {
        val results = startAuthorize(redirectUri = "com.example.app://callback")

        // Same scheme, different host, so not this flow's redirect.
        val consumed = OidcPlugin.handleRedirect(
            Uri.parse("com.example.app://somewhere-else?code=x"),
        )

        assertFalse(consumed)
        assertTrue(results.isEmpty())
    }

    @Test
    fun `the redirect resolves the Dart callback exactly once`() {
        val results = startAuthorize()
        val redirect = Uri.parse("com.example.app://callback?code=code-1&state=s")

        assertTrue(OidcPlugin.handleRedirect(redirect))
        // A second delivery, whether onNewIntent re-entry or the Custom Tab
        // reporting RESULT_CANCELED as it closes, must not resolve the callback
        // again or overwrite the success.
        assertFalse(OidcPlugin.handleRedirect(redirect))

        assertEquals(1, results.size)
        assertTrue(results.single().isSuccess)
    }

    @Test
    fun `starting a new flow supersedes the previous one`() {
        val first = startAuthorize()
        val second = startAuthorize()

        assertEquals(1, first.size, "the superseded flow must be resolved, not leaked")
        assertTrue(first.single().isFailure)
        assertTrue(second.isEmpty())

        assertTrue(
            OidcPlugin.handleRedirect(Uri.parse("com.example.app://callback?code=code-2")),
        )
        assertEquals("com.example.app://callback?code=code-2", second.single().getOrNull())
    }

    @Test
    fun `a flow with no redirect_uri cannot be resolved by an arbitrary deep link`() {
        val results = mutableListOf<Result<String?>>()
        plugin.authorize(
            "https://op.example.com/authorize",
            null,
            null,
            emptyMap(),
        ) { results.add(it) }

        assertFalse(OidcPlugin.handleRedirect(Uri.parse("com.example.app://callback?code=x")))
        assertTrue(results.isEmpty())
    }

    @Test
    fun `a plain Activity host still opens a browser instead of failing`() {
        // A non-ComponentActivity host has no ActivityResultLauncher, so the
        // plugin must open a Custom Tab rather than reject the flow.
        val results = startAuthorize()

        val launched = org.robolectric.Shadows.shadowOf(activity).nextStartedActivity
        assertNull(results.firstOrNull(), "must not fail fast on a non-ComponentActivity")
        assertTrue(launched != null, "a browser Intent must have been launched")
        assertEquals(
            "https://op.example.com/authorize?client_id=c&state=s",
            launched!!.data.toString(),
        )
    }

    @Test
    fun `endSession is captured through the same fallback path`() {
        val results = mutableListOf<Result<String?>>()
        plugin.endSession(
            "https://op.example.com/logout",
            "com.example.app://logout",
            "com.example.app",
            emptyMap(),
        ) { results.add(it) }

        assertTrue(
            OidcPlugin.handleRedirect(Uri.parse("com.example.app://logout?state=logout-state")),
        )
        assertEquals(
            "com.example.app://logout?state=logout-state",
            results.single().getOrNull(),
        )
    }
}
