import AuthenticationServices
import Flutter
import UIKit

/// First-party iOS implementation of the oidc browser primitive.
///
/// Opens the authorization / end-session URL (already fully built by Dart
/// `oidc_core`, including PKCE/state/nonce) in an `ASWebAuthenticationSession`
/// and returns the captured redirect URI string back to Dart, which parses it.
/// No OIDC logic lives here — this replaces the `flutter_appauth` dependency.
public class OidcPlugin: NSObject, FlutterPlugin {
  private var session: ASWebAuthenticationSession?
  // A strong reference to the presentation-context provider is required: if it
  // is deallocated while the session is in flight the app crashes with
  // EXC_BAD_ACCESS (#213).
  private var contextProvider: OidcPresentationContextProvider?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "oidc_ios", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(OidcPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    // Both flows are identical natively: open a URL, capture the redirect.
    case "authorize", "endSession":
      startSession(call, result)
    case "cancel":
      session?.cancel()
      session = nil
      contextProvider = nil
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startSession(
    _ call: FlutterMethodCall, _ result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
      let urlString = args["url"] as? String,
      let url = URL(string: urlString)
    else {
      result(
        FlutterError(
          code: "BAD_ARGS", message: "Missing or invalid `url` argument",
          details: nil))
      return
    }
    let callbackScheme = args["callbackScheme"] as? String
    let preferEphemeral = (args["preferEphemeral"] as? Bool) ?? false

    let newSession = ASWebAuthenticationSession(
      url: url, callbackURLScheme: callbackScheme
    ) { [weak self] callbackURL, error in
      self?.session = nil
      self?.contextProvider = nil
      if let error = error as NSError? {
        result(OidcPlugin.mapError(error))
        return
      }
      result(callbackURL?.absoluteString)
    }

    let provider = OidcPresentationContextProvider()
    contextProvider = provider
    newSession.presentationContextProvider = provider
    newSession.prefersEphemeralWebBrowserSession = preferEphemeral
    session = newSession

    if !newSession.start() {
      session = nil
      contextProvider = nil
      result(
        FlutterError(
          code: "START_FAILED",
          message: "ASWebAuthenticationSession.start() returned false",
          details: nil))
    }
  }

  private static func mapError(_ error: NSError) -> FlutterError {
    if error.domain == ASWebAuthenticationSessionError.errorDomain {
      switch error.code {
      case ASWebAuthenticationSessionError.canceledLogin.rawValue:
        return FlutterError(
          code: "USER_CANCELLED",
          message: "The flow was cancelled by the user", details: nil)
      case ASWebAuthenticationSessionError.presentationContextNotProvided.rawValue,
        ASWebAuthenticationSessionError.presentationContextInvalid.rawValue:
        return FlutterError(
          code: "PRESENTATION_CONTEXT_INVALID",
          message: error.localizedDescription, details: nil)
      default:
        break
      }
    }
    return FlutterError(
      code: "PLATFORM_ERROR", message: error.localizedDescription, details: nil)
  }
}

/// Supplies the window to present the `ASWebAuthenticationSession` over, using
/// the active `UIWindowScene` (UIScene lifecycle, default on Flutter 3.44+).
private final class OidcPresentationContextProvider: NSObject,
  ASWebAuthenticationPresentationContextProviding
{
  func presentationAnchor(for session: ASWebAuthenticationSession)
    -> ASPresentationAnchor
  {
    if #available(iOS 15.0, *) {
      let keyWindow =
        UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }?
        .keyWindow
      if let keyWindow = keyWindow {
        return keyWindow
      }
    }
    return UIApplication.shared.windows.first { $0.isKeyWindow }
      ?? ASPresentationAnchor()
  }
}
