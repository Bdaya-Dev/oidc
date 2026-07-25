package com.bdayadev.oidc

import java.io.File
import kotlin.test.Test
import kotlin.test.assertTrue

/**
 * Structural guard on the library manifest: the redirect receiver and its
 * intent-filter must stay declared, and the library must not declare a default
 * for the scheme placeholder.
 *
 * Deliberately plain file assertions rather than a Robolectric package-manager
 * query, so a removal fails immediately and without an emulator.
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
            "OidcRedirectActivity must stay declared; without it a browser that " +
                "lacks Auth Tab support has nowhere to deliver the redirect",
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
     * `oidc_platform_interface`'s `_captureMode()` maps an unrecognised value to
     * `OidcRedirectCaptureMode.unknown` rather than failing, so nothing else
     * enforces agreement across the language boundary.
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
                    "_captureMode() in oidc_platform_interface, so it would decode " +
                    "as OidcRedirectCaptureMode.unknown",
            )
        }
    }

    /**
     * A `manifestPlaceholders` entry declared in this library module is
     * substituted into the library manifest before the app-level merge, so it
     * overrides the consuming app's own value rather than acting as a fallback.
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
            "this library must not set an ungated oidcRedirectScheme default " +
                "(build.gradle line(s) ${offenders.map { it + 1 }}): it is substituted before " +
                "the app-level merge and overrides the consuming app's scheme",
        )
    }
}
