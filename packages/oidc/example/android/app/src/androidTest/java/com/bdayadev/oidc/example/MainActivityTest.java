package com.bdayadev.oidc.example;

import androidx.test.platform.app.InstrumentationRegistry;
import io.flutter.embedding.android.FlutterFragmentActivity;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import org.junit.runners.Parameterized.Parameters;
import pl.leancode.patrol.PatrolJUnitRunner;

/**
 * Android instrumentation entrypoint for the Patrol suite.
 *
 * <p>Without this class the app has no {@code androidTest} source set at all, so
 * {@code connectedDebugAndroidTest} enumerates zero JUnit classes, Patrol's
 * Dart-side {@code listDartTests()} RPC is never reached, and the CI job prints
 * {@code Total: 0} in ~7s while reporting success. That is exactly what the
 * Android job did for its entire life, which is why it could not catch the
 * issue-#418 Android redirect regression: it had never executed a single test.
 *
 * <p>iOS already had the analogue ({@code ios/RunnerUITests/RunnerUITests.m}) and
 * correctly reported 3-4 tests, which is what made the Android gap visible.
 *
 * <p>Patrol's CLI does NOT generate this file — it only references it in a
 * comment. It has to live in the repo.
 *
 * <p>{@link FlutterFragmentActivity} is passed because this example declares no
 * custom MainActivity; {@code AndroidManifest.xml} launches the Flutter activity
 * directly. It is only the fallback anyway: {@code PatrolJUnitRunner.setUp} tries
 * {@code getLaunchIntentForPackage} first, and the manifest does declare a
 * LAUNCHER intent-filter, so the launcher path wins.
 */
@RunWith(Parameterized.class)
public class MainActivityTest {
    @Parameters(name = "{0}")
    public static Object[] testCases() {
        PatrolJUnitRunner instrumentation =
                (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.setUp(FlutterFragmentActivity.class);
        instrumentation.waitForPatrolAppService();
        return instrumentation.listDartTests();
    }

    private final String dartTestName;

    public MainActivityTest(String dartTestName) {
        this.dartTestName = dartTestName;
    }

    @Test
    public void runDartTest() {
        PatrolJUnitRunner instrumentation =
                (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.runDartTest(dartTestName);
    }
}
