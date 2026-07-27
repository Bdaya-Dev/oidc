package com.bdayadev.oidc

import android.app.Activity
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
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
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Asserts that `OidcNativeOptionsAndroid` reaches the launched Intent.
 *
 * `platform_options_serialization_test.dart` already pins each option's JSON
 * shape and round-trip, and every one of them passed while the native side read
 * only two keys out of the map. A shape assertion cannot distinguish an option
 * that works from one that is discarded on arrival, so these assert the EFFECT:
 * the extras actually present on the Intent handed to the browser.
 *
 * `native_option_wiring_test.dart` (Dart) is the companion guard — it fails when
 * an option is declared and never referenced natively at all. This file proves
 * the reference is correct.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class OidcPluginOptionsTest {

    private lateinit var plugin: OidcPlugin
    private lateinit var activity: Activity

    /** A non-ComponentActivity host, so every flow takes the Custom Tabs path. */
    @Before
    fun setUp() {
        plugin = OidcPlugin()
        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val binding = mock(ActivityPluginBinding::class.java)
        `when`(binding.activity).thenReturn(activity)
        plugin.onAttachedToActivity(binding)
    }

    /** Starts a flow with [options] and returns the Intent handed to the browser. */
    private fun launchWith(options: Map<String, Any?>): android.content.Intent {
        plugin.authorize(
            "https://op.example.com/authorize",
            "com.example.app://callback",
            "com.example.app",
            options,
        ) { }
        val intent = shadowOf(activity).nextStartedActivity
        assertNotNull(intent, "a browser Intent must have been launched")
        return intent
    }

    @Test
    fun `showTitle reaches the intent`() {
        assertEquals(
            CustomTabsIntent.NO_TITLE,
            launchWith(mapOf("showTitle" to false))
                .getIntExtra(CustomTabsIntent.EXTRA_TITLE_VISIBILITY_STATE, -1),
        )
        assertEquals(
            CustomTabsIntent.SHOW_PAGE_TITLE,
            launchWith(mapOf("showTitle" to true))
                .getIntExtra(CustomTabsIntent.EXTRA_TITLE_VISIBILITY_STATE, -1),
        )
    }

    @Test
    fun `urlBarHidingEnabled reaches the intent`() {
        assertTrue(
            launchWith(mapOf("urlBarHidingEnabled" to true))
                .getBooleanExtra(CustomTabsIntent.EXTRA_ENABLE_URLBAR_HIDING, false),
        )
    }

    @Test
    fun `shareState maps onto the intent, and browserDefault leaves it alone`() {
        assertEquals(
            CustomTabsIntent.SHARE_STATE_ON,
            launchWith(mapOf("shareState" to "on"))
                .getIntExtra(CustomTabsIntent.EXTRA_SHARE_STATE, -1),
        )
        assertEquals(
            CustomTabsIntent.SHARE_STATE_OFF,
            launchWith(mapOf("shareState" to "off"))
                .getIntExtra(CustomTabsIntent.EXTRA_SHARE_STATE, -1),
        )
        // browserDefault must not pin a value; the browser decides.
        assertEquals(
            CustomTabsIntent.SHARE_STATE_DEFAULT,
            launchWith(mapOf("shareState" to "browserDefault"))
                .getIntExtra(CustomTabsIntent.EXTRA_SHARE_STATE, -1),
        )
    }

    @Test
    fun `closeButtonPosition reaches the intent`() {
        assertEquals(
            CustomTabsIntent.CLOSE_BUTTON_POSITION_END,
            launchWith(mapOf("closeButtonPosition" to "end"))
                .getIntExtra(CustomTabsIntent.EXTRA_CLOSE_BUTTON_POSITION, -1),
        )
        assertEquals(
            CustomTabsIntent.CLOSE_BUTTON_POSITION_START,
            launchWith(mapOf("closeButtonPosition" to "start"))
                .getIntExtra(CustomTabsIntent.EXTRA_CLOSE_BUTTON_POSITION, -1),
        )
    }

    @Test
    fun `colorSchemes reaches the intent, nested params included`() {
        val intent = launchWith(
            mapOf(
                "colorSchemes" to mapOf(
                    "colorScheme" to "dark",
                    "defaultParams" to mapOf("toolbarColor" to 0xFF112233.toInt()),
                ),
            ),
        )
        assertEquals(
            CustomTabsIntent.COLOR_SCHEME_DARK,
            intent.getIntExtra(CustomTabsIntent.EXTRA_COLOR_SCHEME, -1),
        )
        // The default params are folded into the top-level toolbar-color extra.
        assertEquals(
            0xFF112233.toInt(),
            intent.getIntExtra("android.support.customtabs.extra.TOOLBAR_COLOR", 0),
        )
    }

    @Test
    fun `partialCustomTabs reaches the intent`() {
        val intent = launchWith(
            mapOf(
                "partialCustomTabs" to mapOf(
                    "initialHeightPx" to 500,
                    "resizeBehavior" to "fixed",
                    "toolbarCornerRadiusDp" to 8,
                ),
            ),
        )
        assertEquals(
            500,
            intent.getIntExtra(CustomTabsIntent.EXTRA_INITIAL_ACTIVITY_HEIGHT_PX, -1),
        )
        assertEquals(
            CustomTabsIntent.ACTIVITY_HEIGHT_FIXED,
            intent.getIntExtra(CustomTabsIntent.EXTRA_ACTIVITY_HEIGHT_RESIZE_BEHAVIOR, -1),
        )
        assertEquals(
            8,
            intent.getIntExtra(CustomTabsIntent.EXTRA_TOOLBAR_CORNER_RADIUS_DP, -1),
        )
    }

    @Test
    fun `a non-positive partial height is dropped rather than crashing the flow`() {
        // setInitialActivityHeightPx throws on <= 0; a caller's bad value must
        // not take the whole login down.
        val intent = launchWith(
            mapOf("partialCustomTabs" to mapOf("initialHeightPx" to 0)),
        )
        assertEquals(
            -1,
            intent.getIntExtra(CustomTabsIntent.EXTRA_INITIAL_ACTIVITY_HEIGHT_PX, -1),
        )
    }

    @Test
    fun `rawIntentExtras are forwarded verbatim`() {
        val intent = launchWith(
            mapOf(
                "rawIntentExtras" to mapOf(
                    "com.example.STRING" to "hello",
                    "com.example.BOOL" to true,
                    "com.example.INT" to 7,
                ),
            ),
        )
        assertEquals("hello", intent.getStringExtra("com.example.STRING"))
        assertTrue(intent.getBooleanExtra("com.example.BOOL", false))
        assertEquals(7, intent.getIntExtra("com.example.INT", -1))
    }

    @Test
    fun `a Map-valued raw extra is forwarded, not dropped`() {
        // The doc comment on applyRawIntentExtras claims "primitives / List /
        // Map", but the `when` had no Map branch, so Maps fell through to
        // `else` and were emitted as rawIntentExtraSkipped. The test above
        // covered String/Bool/Int only, so it stayed green while a documented
        // type was discarded on arrival -- the same defect this whole file
        // exists to catch, reintroduced in the fix for it.
        val intent = launchWith(
            mapOf("rawIntentExtras" to mapOf("com.example.MAP" to mapOf("a" to 1))),
        )
        @Suppress("UNCHECKED_CAST")
        val received = intent.getSerializableExtra("com.example.MAP") as? Map<String, Any?>
        assertNotNull(received, "a Map extra must reach the Intent")
        assertEquals(1, received["a"])
    }

    @Test
    fun `ephemeralBrowsing still reaches the intent`() {
        // Regression: this one already worked, and must survive the refactor
        // that introduced the option-application helpers.
        assertTrue(
            launchWith(mapOf("ephemeralBrowsing" to true))
                .getBooleanExtra(CustomTabsIntent.EXTRA_ENABLE_EPHEMERAL_BROWSING, false),
        )
    }

    @Test
    fun `defaults produce a bare intent, so an unset option changes nothing`() {
        val intent = launchWith(emptyMap())
        assertEquals(-1, intent.getIntExtra(CustomTabsIntent.EXTRA_COLOR_SCHEME, -1))
        assertEquals(-1, intent.getIntExtra(CustomTabsIntent.EXTRA_CLOSE_BUTTON_POSITION, -1))
        assertEquals(
            -1,
            intent.getIntExtra(CustomTabsIntent.EXTRA_INITIAL_ACTIVITY_HEIGHT_PX, -1),
        )
    }
}
