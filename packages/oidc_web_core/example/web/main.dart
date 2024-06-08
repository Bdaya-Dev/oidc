import 'package:oidc_web_core/oidc_web_core.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:web/web.dart' as web;

final duendeManager = OidcUserManagerWeb.lazy(
  discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
    Uri.parse('https://demo.duendesoftware.com'),
  ),
  // this is a public client,
  // so we use [OidcClientAuthentication.none] constructor.
  clientCredentials: const OidcClientAuthentication.none(
    clientId: 'interactive.public.short',
  ),
  store: const OidcWebStore(),

  // keyStore: JsonWebKeyStore(),
  settings: OidcUserManagerSettings(
    frontChannelLogoutUri: Uri(path: 'redirect.html'),
    uiLocales: ['ar'],
    refreshBefore: (token) {
      return const Duration(seconds: 1);
    },

    // scopes supported by the provider and needed by the client.
    scope: ['openid', 'profile', 'email', 'offline_access'],
    postLogoutRedirectUri: Uri.parse('http://127.0.0.1:22433/redirect.html'),
    redirectUri:
        // this url must be an actual html page.
        // see the file in /web/redirect.html for an example.
        //
        // you must run this app with port 22433
        Uri.parse('http://127.0.0.1:22433/redirect.html'),
  ),
);

void main() async {
  await init();
  registerButton();
  registerUserOutput();
}

Future<void> init() async {
  final element = web.document.querySelector('#output') as web.HTMLDivElement;
  element.text = "initializing user manager...";
  await duendeManager.init();
  element.textContent = null;
  element.appendChild(
    web.document.createElement('span')..text = 'User manager is initialized!',
  );
  element.appendChild(web.document.createElement('br'));
  element.appendChild(
    web.document.createElement('span')
      ..text = duendeManager.discoveryDocument.src.toString(),
  );
}

void registerButton() {
  final element =
      web.document.querySelector('#loginButton') as web.HTMLButtonElement;
  element.onClick.listen((event) {
    if (duendeManager.currentUser == null) {
      login();
    } else {
      logout();
    }
  });
  duendeManager.userChanges().listen((user) {
    if (user == null) {
      element.textContent = "login";
    } else {
      element.textContent = "logout";
    }
  });
}

void registerUserOutput() {
  final element =
      web.document.querySelector('#userOutput') as web.HTMLDivElement;
  duendeManager.userChanges().listen((user) {
    print('user changed!');
    element.innerHTML = "";
    if (user == null) {
      return;
    }
    element.appendChild(
      web.document.createElement('span')..text = 'User logged in! claims:',
    );
    element.appendChild(web.document.createElement('br'));
    element.appendChild(
      web.document.createElement('span')
        ..text = user.aggregatedClaims.toString(),
    );
  });
}

Future<void> login() async {
  await duendeManager.loginAuthorizationCodeFlow();
}

Future<void> logout() async {
  await duendeManager.logout();
}
