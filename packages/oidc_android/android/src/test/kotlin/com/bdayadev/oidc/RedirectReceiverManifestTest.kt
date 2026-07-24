package com.bdayadev.oidc

import java.io.File
import kotlin.test.Test
import kotlin.test.assertTrue

/**
 * Structural guard on the library manifest.
 *
 * Issue #418 was a wholesale deletion: the `OidcRedirectActivity` declaration
 * and its `<intent-filter>` were removed on the assumption that Auth Tab's
 * Custom Tabs fallback also carried redirect capture. It does not — it only
 * degrades the UI. Nothing in the suite noticed, because no test read the
 * manifest and no test exercised native capture.
 *
 * This asserts the receiver stays wired. It is deliberately a plain file
 * assertion rather than a Robolectric package-manager query so it fails loudly
 * and instantly on the exact edit that caused the regression.
 */
class RedirectReceiverManifestTest {

    private val manifest: String by lazy {
        val file = File("src/main/AndroidManifest.xml")
        assertTrue(file.exists(), "library AndroidManifest.xml not found at ${file.absolutePath}")
        file.readText()
    }

    @Test
    fun `the redirect receiver is declared and exported`() {
        assertTrue(
            manifest.contains("com.bdayadev.oidc.OidcRedirectActivity"),
            "OidcRedirectActivity must stay declared — without it every browser " +
                "that lacks Auth Tab support (Firefox, Samsung Internet, older " +
                "Chrome) drops the redirect on the floor. See issue #418.",
        )
        assertTrue(
            manifest.contains("android:exported=\"true\""),
            "the receiver must be exported for the browser to resolve the redirect",
        )
    }

    @Test
    fun `the redirect intent-filter is driven by the oidcRedirectScheme placeholder`() {
        assertTrue(
            manifest.contains("android.intent.action.VIEW"),
            "the receiver needs an ACTION_VIEW intent-filter",
        )
        assertTrue(
            manifest.contains("android.intent.category.BROWSABLE"),
            "the receiver needs the BROWSABLE category for a browser redirect",
        )
        assertTrue(
            manifest.contains("\${oidcRedirectScheme}"),
            "the scheme must stay driven by the documented manifest placeholder",
        )
    }

    /**
     * The `captureMode` strings the plugin emits are parsed by a `switch` in
     * `oidc_platform_interface`'s `_captureMode()`; an unrecognised value maps
     * silently to `OidcRedirectCaptureMode.unknown` rather than failing. Both
     * sides must agree, and nothing else enforces it across the language
     * boundary.
     */
    @Test
    fun `emitted captureMode values match the Dart OidcRedirectCaptureMode parser`() {
        val plugin = File("src/main/kotlin/com/bdayadev/oidc/OidcPlugin.kt")
        assertTrue(plugin.exists(), "OidcPlugin.kt not found at ${plugin.absolutePath}")
        val emitted = Regex("\"captureMode\" to \"([A-Za-z]+)\"")
            .findAll(plugin.readText())
            .map { it.groupValues[1] }
            .toSet()
        assertTrue(emitted.isNotEmpty(), "expected the plugin to emit a captureMode")

        val dart = File("../../oidc_platform_interface/lib/src/native_events.dart")
        assertTrue(dart.exists(), "native_events.dart not found at ${dart.absolutePath}")
        val dartText = dart.readText()
        for (mode in emitted) {
            assertTrue(
                dartText.contains("'$mode' =>"),
                "captureMode \"$mode\" is emitted by OidcPlugin.kt but is not a case in " +
                    "_captureMode() in oidc_platform_interface — it would silently decode " +
                    "as OidcRedirectCaptureMode.unknown",
            )
        }
    }

    /**
     * A `manifestPlaceholders` entry declared in THIS library module is
     * substituted into the library manifest before the app merge, which
     * shadows the consuming app's own value. Verified by building the example:
     * with a library default of `com.bdayadev.oidc.unset`, the merged app
     * manifest registered `android:scheme="com.bdayadev.oidc.unset"` instead of
     * the app's `com.bdayadev.oidc.example`, so the redirect still resolved to
     * nothing — issue #418 would have survived the fix.
     */
    @Test
    fun `the library declares no default that would shadow the app's scheme`() {
        val gradle = File("build.gradle")
        assertTrue(gradle.exists(), "build.gradle not found at ${gradle.absolutePath}")
        val lines = gradle.readLines().map { it.substringBefore("//") }
        val offenders = lines.indices.filter { i ->
            lines[i].contains("manifestPlaceholders") && lines[i].contains("oidcRedirectScheme")
        }.filterNot { i ->
            // Permitted only inside the -PoidcNativeTests gate, which is never
            // set when a consuming app builds this plugin.
            (maxOf(0, i - 4) until i).any { lines[it].contains("oidcNativeTests") }
        }
        assertTrue(
            offenders.isEmpty(),
            "this library must NOT set an ungated oidcRedirectScheme placeholder default " +
                "(build.gradle line(s) ${offenders.map { it + 1 }}): it is substituted into the " +
                "library manifest before the app merge and silently overrides the consuming " +
                "app's scheme, reintroducing #418",
        )
    }
}
