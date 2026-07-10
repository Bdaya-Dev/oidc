import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('OidcColorSchemeParams', () {
    test('fromJson reads all ARGB fields', () {
      final parsed = OidcColorSchemeParams.fromJson(const {
        'toolbarColor': 0xFF2196F3,
        'secondaryToolbarColor': 0xFF000000,
        'navigationBarColor': 0xFFFFFFFF,
        'navigationBarDividerColor': 0xFF808080,
      });
      expect(parsed.toolbarColor, 0xFF2196F3);
      expect(parsed.secondaryToolbarColor, 0xFF000000);
      expect(parsed.navigationBarColor, 0xFFFFFFFF);
      expect(parsed.navigationBarDividerColor, 0xFF808080);
    });

    test('toJson round-trips', () {
      const obj = OidcColorSchemeParams(
        toolbarColor: 1,
        secondaryToolbarColor: 2,
        navigationBarColor: 3,
        navigationBarDividerColor: 4,
      );
      final json = obj.toJson();
      expect(json, {
        'toolbarColor': 1,
        'secondaryToolbarColor': 2,
        'navigationBarColor': 3,
        'navigationBarDividerColor': 4,
      });
      final reparsed = OidcColorSchemeParams.fromJson(json);
      expect(reparsed.toolbarColor, 1);
      expect(reparsed.navigationBarDividerColor, 4);
    });

    test('absent fields decode to null', () {
      final parsed = OidcColorSchemeParams.fromJson(const {});
      expect(parsed.toolbarColor, isNull);
      expect(parsed.secondaryToolbarColor, isNull);
      expect(parsed.navigationBarColor, isNull);
      expect(parsed.navigationBarDividerColor, isNull);
    });
  });

  group('OidcCustomTabsColorSchemes', () {
    test('full round-trip preserves colorScheme + nested params', () {
      const obj = OidcCustomTabsColorSchemes(
        colorScheme: OidcColorScheme.dark,
        lightParams: OidcColorSchemeParams(toolbarColor: 10),
        darkParams: OidcColorSchemeParams(toolbarColor: 20),
        defaultParams: OidcColorSchemeParams(toolbarColor: 30),
      );
      final json = obj.toJson();
      expect(json['colorScheme'], 'dark');
      final reparsed = OidcCustomTabsColorSchemes.fromJson(json);
      expect(reparsed.colorScheme, OidcColorScheme.dark);
      expect(reparsed.lightParams?.toolbarColor, 10);
      expect(reparsed.darkParams?.toolbarColor, 20);
      expect(reparsed.defaultParams?.toolbarColor, 30);
    });

    test('defaults: system scheme, null params', () {
      final parsed = OidcCustomTabsColorSchemes.fromJson(const {});
      expect(parsed.colorScheme, OidcColorScheme.system);
      expect(parsed.lightParams, isNull);
      expect(parsed.darkParams, isNull);
      expect(parsed.defaultParams, isNull);
    });

    test('each OidcColorScheme value encodes to its wire name', () {
      for (final entry in {
        OidcColorScheme.system: 'system',
        OidcColorScheme.light: 'light',
        OidcColorScheme.dark: 'dark',
      }.entries) {
        final json = OidcCustomTabsColorSchemes(
          colorScheme: entry.key,
        ).toJson();
        expect(json['colorScheme'], entry.value);
        expect(
          OidcCustomTabsColorSchemes.fromJson(json).colorScheme,
          entry.key,
        );
      }
    });
  });

  group('OidcPartialCustomTabs', () {
    test('full round-trip', () {
      const obj = OidcPartialCustomTabs(
        initialHeightPx: 400,
        resizeBehavior: OidcPartialTabResizeBehavior.fixed,
        toolbarCornerRadiusDp: 16,
        backgroundInteractionEnabled: false,
      );
      final json = obj.toJson();
      expect(json['initialHeightPx'], 400);
      expect(json['resizeBehavior'], 'fixed');
      expect(json['toolbarCornerRadiusDp'], 16);
      expect(json['backgroundInteractionEnabled'], false);

      final reparsed = OidcPartialCustomTabs.fromJson(json);
      expect(reparsed.initialHeightPx, 400);
      expect(reparsed.resizeBehavior, OidcPartialTabResizeBehavior.fixed);
      expect(reparsed.toolbarCornerRadiusDp, 16);
      expect(reparsed.backgroundInteractionEnabled, isFalse);
    });

    test('defaults', () {
      final parsed = OidcPartialCustomTabs.fromJson(const {});
      expect(parsed.initialHeightPx, isNull);
      expect(
        parsed.resizeBehavior,
        OidcPartialTabResizeBehavior.defaultBehavior,
      );
      expect(parsed.toolbarCornerRadiusDp, isNull);
      expect(parsed.backgroundInteractionEnabled, isTrue);
    });

    test('all resize behaviors round-trip', () {
      for (final entry in {
        OidcPartialTabResizeBehavior.defaultBehavior: 'defaultBehavior',
        OidcPartialTabResizeBehavior.adjustable: 'adjustable',
        OidcPartialTabResizeBehavior.fixed: 'fixed',
      }.entries) {
        final json = OidcPartialCustomTabs(resizeBehavior: entry.key).toJson();
        expect(json['resizeBehavior'], entry.value);
        expect(
          OidcPartialCustomTabs.fromJson(json).resizeBehavior,
          entry.key,
        );
      }
    });
  });

  group('OidcNativeOptionsAndroid', () {
    test('fully-populated round-trip', () {
      const obj = OidcNativeOptionsAndroid(
        colorSchemes: OidcCustomTabsColorSchemes(
          colorScheme: OidcColorScheme.light,
        ),
        shareState: OidcCustomTabsShareState.on,
        showTitle: false,
        urlBarHidingEnabled: true,
        ephemeralBrowsing: true,
        closeButtonPosition: OidcCustomTabsCloseButtonPosition.end,
        preferredBrowserPackages: ['com.android.chrome'],
        useAuthTab: OidcAuthTabMode.force,
        partialCustomTabs: OidcPartialCustomTabs(initialHeightPx: 500),
        warmup: OidcCustomTabsWarmup.mayLaunch,
        rawIntentExtras: {'x': 1},
        allowInsecureConnections: true,
        flowTimeoutSeconds: 30,
      );
      final json = obj.toJson();
      expect(json['shareState'], 'on');
      expect(json['showTitle'], false);
      expect(json['urlBarHidingEnabled'], true);
      expect(json['ephemeralBrowsing'], true);
      expect(json['closeButtonPosition'], 'end');
      expect(json['preferredBrowserPackages'], ['com.android.chrome']);
      expect(json['useAuthTab'], 'force');
      expect(json['warmup'], 'mayLaunch');
      expect(json['rawIntentExtras'], {'x': 1});
      expect(json['allowInsecureConnections'], true);
      expect(json['flowTimeoutSeconds'], 30);

      final reparsed = OidcNativeOptionsAndroid.fromJson(json);
      expect(reparsed.colorSchemes?.colorScheme, OidcColorScheme.light);
      expect(reparsed.shareState, OidcCustomTabsShareState.on);
      expect(reparsed.showTitle, isFalse);
      expect(reparsed.urlBarHidingEnabled, isTrue);
      expect(reparsed.ephemeralBrowsing, isTrue);
      expect(
        reparsed.closeButtonPosition,
        OidcCustomTabsCloseButtonPosition.end,
      );
      expect(reparsed.preferredBrowserPackages, ['com.android.chrome']);
      expect(reparsed.useAuthTab, OidcAuthTabMode.force);
      expect(reparsed.partialCustomTabs?.initialHeightPx, 500);
      expect(reparsed.warmup, OidcCustomTabsWarmup.mayLaunch);
      expect(reparsed.rawIntentExtras, {'x': 1});
      expect(reparsed.allowInsecureConnections, isTrue);
      expect(reparsed.flowTimeoutSeconds, 30);
    });

    test('defaults from empty json', () {
      final parsed = OidcNativeOptionsAndroid.fromJson(const {});
      expect(parsed.colorSchemes, isNull);
      expect(parsed.shareState, OidcCustomTabsShareState.browserDefault);
      expect(parsed.showTitle, isTrue);
      expect(parsed.urlBarHidingEnabled, isFalse);
      expect(parsed.ephemeralBrowsing, isFalse);
      expect(parsed.closeButtonPosition, isNull);
      expect(parsed.preferredBrowserPackages, isEmpty);
      expect(parsed.useAuthTab, OidcAuthTabMode.auto);
      expect(parsed.partialCustomTabs, isNull);
      expect(parsed.warmup, OidcCustomTabsWarmup.none);
      expect(parsed.rawIntentExtras, isEmpty);
      expect(parsed.allowInsecureConnections, isFalse);
      expect(parsed.flowTimeoutSeconds, isNull);
    });

    test('implements the platform-options marker interface', () {
      expect(
        const OidcNativeOptionsAndroid(),
        isA<OidcPlatformOptionsMarker>(),
      );
    });

    test('every share state + close-button position + warmup encodes', () {
      for (final entry in {
        OidcCustomTabsShareState.browserDefault: 'browserDefault',
        OidcCustomTabsShareState.on: 'on',
        OidcCustomTabsShareState.off: 'off',
      }.entries) {
        expect(
          OidcNativeOptionsAndroid(
            shareState: entry.key,
          ).toJson()['shareState'],
          entry.value,
        );
      }
      for (final entry in {
        OidcCustomTabsCloseButtonPosition.defaultPosition: 'defaultPosition',
        OidcCustomTabsCloseButtonPosition.start: 'start',
        OidcCustomTabsCloseButtonPosition.end: 'end',
      }.entries) {
        expect(
          OidcNativeOptionsAndroid(
            closeButtonPosition: entry.key,
          ).toJson()['closeButtonPosition'],
          entry.value,
        );
      }
      for (final entry in {
        OidcAuthTabMode.auto: 'auto',
        OidcAuthTabMode.force: 'force',
        OidcAuthTabMode.never: 'never',
      }.entries) {
        expect(
          OidcNativeOptionsAndroid(
            useAuthTab: entry.key,
          ).toJson()['useAuthTab'],
          entry.value,
        );
      }
      for (final entry in {
        OidcCustomTabsWarmup.none: 'none',
        OidcCustomTabsWarmup.warmup: 'warmup',
        OidcCustomTabsWarmup.mayLaunch: 'mayLaunch',
      }.entries) {
        expect(
          OidcNativeOptionsAndroid(warmup: entry.key).toJson()['warmup'],
          entry.value,
        );
      }
    });
  });

  group('OidcNativeOptionsApple', () {
    test('fully-populated round-trip', () {
      const obj = OidcNativeOptionsApple(
        prefersEphemeralWebBrowserSession: true,
        additionalHeaderFields: {'X-A': 'b'},
        callbackMode: OidcAppleCallbackMode.https,
        rawSessionOptions: {'k': 'v'},
        flowTimeoutSeconds: 42,
      );
      final json = obj.toJson();
      expect(json['prefersEphemeralWebBrowserSession'], true);
      expect(json['additionalHeaderFields'], {'X-A': 'b'});
      expect(json['callbackMode'], 'https');
      expect(json['rawSessionOptions'], {'k': 'v'});
      expect(json['flowTimeoutSeconds'], 42);

      final reparsed = OidcNativeOptionsApple.fromJson(json);
      expect(reparsed.prefersEphemeralWebBrowserSession, isTrue);
      expect(reparsed.additionalHeaderFields, {'X-A': 'b'});
      expect(reparsed.callbackMode, OidcAppleCallbackMode.https);
      expect(reparsed.rawSessionOptions, {'k': 'v'});
      expect(reparsed.flowTimeoutSeconds, 42);
    });

    test('defaults from empty json + marker interface', () {
      final parsed = OidcNativeOptionsApple.fromJson(const {});
      expect(parsed.prefersEphemeralWebBrowserSession, isFalse);
      expect(parsed.additionalHeaderFields, isNull);
      expect(parsed.callbackMode, OidcAppleCallbackMode.auto);
      expect(parsed.rawSessionOptions, isEmpty);
      expect(parsed.flowTimeoutSeconds, isNull);
      expect(parsed, isA<OidcPlatformOptionsMarker>());
    });

    test('all callback modes round-trip', () {
      for (final entry in {
        OidcAppleCallbackMode.auto: 'auto',
        OidcAppleCallbackMode.customScheme: 'customScheme',
        OidcAppleCallbackMode.https: 'https',
      }.entries) {
        final json = OidcNativeOptionsApple(callbackMode: entry.key).toJson();
        expect(json['callbackMode'], entry.value);
        expect(
          OidcNativeOptionsApple.fromJson(json).callbackMode,
          entry.key,
        );
      }
    });
  });

  group('OidcPlatformSpecificOptions_Native', () {
    test('full round-trip (launchUrl excluded from json)', () {
      const obj = OidcPlatformSpecificOptions_Native(
        successfulPageResponse: 'ok',
        methodMismatchResponse: 'nope',
        notFoundResponse: '404',
        flowTimeoutSeconds: 12,
      );
      final json = obj.toJson();
      expect(json['successfulPageResponse'], 'ok');
      expect(json['methodMismatchResponse'], 'nope');
      expect(json['notFoundResponse'], '404');
      expect(json['flowTimeoutSeconds'], 12);
      expect(json.containsKey('launchUrl'), isFalse);

      final reparsed = OidcPlatformSpecificOptions_Native.fromJson(json);
      expect(reparsed.successfulPageResponse, 'ok');
      expect(reparsed.methodMismatchResponse, 'nope');
      expect(reparsed.notFoundResponse, '404');
      expect(reparsed.flowTimeoutSeconds, 12);
      expect(reparsed.launchUrl, isNull);
    });

    test('defaults', () {
      final parsed = OidcPlatformSpecificOptions_Native.fromJson(const {});
      expect(parsed.successfulPageResponse, isNull);
      expect(parsed.methodMismatchResponse, isNull);
      expect(parsed.notFoundResponse, isNull);
      expect(parsed.flowTimeoutSeconds, isNull);
    });
  });

  group('OidcPlatformSpecificOptions_Web', () {
    test('fully-populated round-trip', () {
      const obj = OidcPlatformSpecificOptions_Web(
        navigationMode: OidcPlatformSpecificOptions_Web_NavigationMode.popup,
        popupWidth: 800,
        popupHeight: 600,
        broadcastChannel: 'custom/channel',
        hiddenIframeTimeout: Duration(seconds: 5),
      );
      final json = obj.toJson();
      expect(json['navigationMode'], 'popup');
      expect(json['popupWidth'], 800);
      expect(json['popupHeight'], 600);
      expect(json['broadcastChannel'], 'custom/channel');
      expect(
        json['hiddenIframeTimeout'],
        const Duration(seconds: 5).inMicroseconds,
      );

      final reparsed = OidcPlatformSpecificOptions_Web.fromJson(json);
      expect(
        reparsed.navigationMode,
        OidcPlatformSpecificOptions_Web_NavigationMode.popup,
      );
      expect(reparsed.popupWidth, 800);
      expect(reparsed.popupHeight, 600);
      expect(reparsed.broadcastChannel, 'custom/channel');
      expect(reparsed.hiddenIframeTimeout, const Duration(seconds: 5));
    });

    test('defaults', () {
      final parsed = OidcPlatformSpecificOptions_Web.fromJson(const {});
      expect(
        parsed.navigationMode,
        OidcPlatformSpecificOptions_Web_NavigationMode.newPage,
      );
      expect(parsed.popupWidth, 700);
      expect(parsed.popupHeight, 750);
      expect(
        parsed.broadcastChannel,
        OidcPlatformSpecificOptions_Web.defaultBroadcastChannel,
      );
      expect(parsed.hiddenIframeTimeout, const Duration(seconds: 10));
    });

    test('all navigation modes round-trip', () {
      for (final entry in {
        OidcPlatformSpecificOptions_Web_NavigationMode.samePage: 'samePage',
        OidcPlatformSpecificOptions_Web_NavigationMode.newPage: 'newPage',
        OidcPlatformSpecificOptions_Web_NavigationMode.popup: 'popup',
        OidcPlatformSpecificOptions_Web_NavigationMode.hiddenIFrame:
            'hiddenIFrame',
      }.entries) {
        final json = OidcPlatformSpecificOptions_Web(
          navigationMode: entry.key,
        ).toJson();
        expect(json['navigationMode'], entry.value);
        expect(
          OidcPlatformSpecificOptions_Web.fromJson(json).navigationMode,
          entry.key,
        );
      }
    });
  });

  group('OidcPlatformSpecificOptions (top-level)', () {
    test('defaults populate every platform with its default object', () {
      const obj = OidcPlatformSpecificOptions();
      final json = obj.toJson();
      expect(
        json.keys,
        containsAll(<String>[
          'android',
          'ios',
          'macos',
          'web',
          'linux',
          'windows',
        ]),
      );

      final reparsed = OidcPlatformSpecificOptions.fromJson(json);
      expect(reparsed.android.showTitle, isTrue);
      expect(reparsed.ios.callbackMode, OidcAppleCallbackMode.auto);
      expect(reparsed.macos.callbackMode, OidcAppleCallbackMode.auto);
      expect(
        reparsed.web.navigationMode,
        OidcPlatformSpecificOptions_Web_NavigationMode.newPage,
      );
      expect(reparsed.linux.flowTimeoutSeconds, isNull);
      expect(reparsed.windows.flowTimeoutSeconds, isNull);
    });

    test('empty json falls back to defaults for every platform', () {
      final parsed = OidcPlatformSpecificOptions.fromJson(const {});
      expect(parsed.android, isA<OidcNativeOptionsAndroid>());
      expect(parsed.ios, isA<OidcNativeOptionsApple>());
      expect(parsed.macos, isA<OidcNativeOptionsApple>());
      expect(parsed.web, isA<OidcPlatformSpecificOptions_Web>());
      expect(parsed.linux, isA<OidcPlatformSpecificOptions_Native>());
      expect(parsed.windows, isA<OidcPlatformSpecificOptions_Native>());
    });

    test('nested custom values survive a full round-trip', () {
      const obj = OidcPlatformSpecificOptions(
        android: OidcNativeOptionsAndroid(flowTimeoutSeconds: 11),
        ios: OidcNativeOptionsApple(flowTimeoutSeconds: 22),
        macos: OidcNativeOptionsApple(flowTimeoutSeconds: 33),
        web: OidcPlatformSpecificOptions_Web(popupWidth: 1234),
        linux: OidcPlatformSpecificOptions_Native(flowTimeoutSeconds: 44),
        windows: OidcPlatformSpecificOptions_Native(flowTimeoutSeconds: 55),
      );
      final reparsed = OidcPlatformSpecificOptions.fromJson(obj.toJson());
      expect(reparsed.android.flowTimeoutSeconds, 11);
      expect(reparsed.ios.flowTimeoutSeconds, 22);
      expect(reparsed.macos.flowTimeoutSeconds, 33);
      expect(reparsed.web.popupWidth, 1234);
      expect(reparsed.linux.flowTimeoutSeconds, 44);
      expect(reparsed.windows.flowTimeoutSeconds, 55);
    });
  });
}
