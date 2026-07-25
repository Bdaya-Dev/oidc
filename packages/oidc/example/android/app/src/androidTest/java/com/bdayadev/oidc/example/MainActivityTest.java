package com.bdayadev.oidc.example;

import androidx.test.platform.app.InstrumentationRegistry;
import io.flutter.embedding.android.FlutterFragmentActivity;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import org.junit.runners.Parameterized.Parameters;
import pl.leancode.patrol.PatrolJUnitRunner;

/**
 * Android instrumentation entrypoint for the Patrol suite, and the counterpart
 * of {@code ios/RunnerUITests/RunnerUITests.m}.
 *
 * <p>Patrol's CLI does not generate this file, so it has to live in the repo.
 * Without it the app has no {@code androidTest} source set,
 * {@code connectedDebugAndroidTest} enumerates zero JUnit classes, and the Dart
 * {@code listDartTests()} RPC is never reached: the run then reports success
 * having executed nothing.
 *
 * <p>{@link FlutterFragmentActivity} is passed because this example declares no
 * custom MainActivity and the manifest launches the Flutter activity directly.
 * It is only a fallback: {@code PatrolJUnitRunner.setUp} prefers
 * {@code getLaunchIntentForPackage}, and the manifest declares a LAUNCHER
 * intent-filter.
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
