import 'package:logging/logging.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_desktop/oidc_desktop.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

final _logger = Logger('Oidc.Linux');

/// The Linux implementation of [OidcPlatform].
class OidcLinux extends OidcPlatform with OidcDesktop {
  /// Registers this class as the default instance of [OidcPlatform]
  static void registerWith() {
    OidcPlatform.instance = OidcLinux();
  }

  @override
  OidcPlatformSpecificOptions_Native getNativeOptions(
    OidcPlatformSpecificOptions options,
  ) =>
      options.linux;

  @override
  Logger get logger => _logger;

  // @override
  // Future<bool> launchAuthUrl(
  //   Uri uri, {
  //   required String logRequestDesc,
  //   required OidcPlatformSpecificOptions_Native platformOpts,
  //   Completer<(Process process, int statusCode)>? exitCodeCompleter,
  // }) async {
  //   try {
  //     if (platformOpts.launchUrl case final urlLauncher?) {
  //       logger.info('Using custom URL launcher: $urlLauncher');
  //       return urlLauncher(uri);
  //     }
  //     final process = await Process.start(
  //       'google-chrome-stable',
  //       ['--enable-logging', '--v=1', '--headless', uri.toString()],
  //       runInShell: true,
  //     );

  //     final stderrSub = process.stderr.transform(utf8.decoder).listen((data) {
  //       logger.severe('Error from google-chrome-stable: $data');
  //     });
  //     final stdoutSub = process.stdout.transform(utf8.decoder).listen((data) {
  //       logger.info('Output from google-chrome-stable: $data');
  //     });

  //     final _ = process.exitCode.then((exitCode) {
  //       stderrSub.cancel();
  //       stdoutSub.cancel();
  //       if (exitCode != 0) {
  //         logger.severe('google-chrome-stable exited with code $exitCode');
  //       } else {
  //         logger.info('google-chrome-stable launched successfully');
  //       }
  //       exitCodeCompleter?.complete((process, exitCode));
  //     });
  //     logger.info('Launching URL (pid: ${process.pid}): $uri');
  //     return process.pid > 0; // Return true if the process started successfully
  //   } catch (e, st) {
  //     logger.severe('Failed to launch URL $uri', e, st);
  //     return false;
  //   }
  // }
}
