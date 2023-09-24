import 'package:async/async.dart';
import 'package:logging/logging.dart';
import 'package:oidc_android/oidc_android.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';
//This file represents a global state, which is bad
//in a production app (since you can't test it).

//usually you would use a dependency injection library
//and put these in a service.
final exampleLogger = Logger('oidc.example');

///===========================

final initMemoizer = AsyncMemoizer<OidcAndroid>();
Future<OidcAndroid> initApp() {
  return initMemoizer.runOnce(() async {
    final androidPlatform = OidcPlatform.instance;
    return androidPlatform as OidcAndroid;
  });
}
