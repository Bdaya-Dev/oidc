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
  // Held so an in-flight flow can be resolved exactly once — by the session
  // completion handler, an explicit `cancel`, or being superseded by a new
  // flow.
  private var pendingResult: FlutterResult?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.bdayadev.oidc/ios", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(OidcPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    // Both flows are identical natively: open a URL, capture the redirect.
    case "authorize", "endSession":
      startSession(call, result)
    case "cancel":
      cancelInFlight()
      reply(result, nil)
    default:
      reply(result, FlutterMethodNotImplemented)
    }
  }

  /// Flutter requires every `FlutterResult` to be invoked on the platform
  /// (main) thread. `ASWebAuthenticationSession`'s completion handler carries
  /// no documented thread guarantee, so all replies are funneled through here.
  private func reply(_ result: @escaping FlutterResult, _ value: Any?) {
    onMain { result(value) }
  }

  private func onMain(_ work: @escaping () -> Void) {
    if Thread.isMainThread {
      work()
    } else {
      DispatchQueue.main.async(execute: work)
    }
  }

  /// Resolves an in-flight flow as cancelled and tears it down. Calling
  /// `cancel()` on the session does NOT invoke its completion handler, so the
  /// pending Dart Future must be resolved here explicitly. All session /
  /// provider state is UIKit-adjacent, so this runs on the main thread.
  private func cancelInFlight() {
    onMain {
      self.session?.cancel()
      if let pending = self.pendingResult {
        self.pendingResult = nil
        pending(OidcPlugin.cancelledError())
      }
      self.session = nil
      self.contextProvider = nil
    }
  }

  private func startSession(
    _ call: FlutterMethodCall, _ result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
      let urlString = args["url"] as? String,
      let url = URL(string: urlString)
    else {
      reply(
        result,
        FlutterError(
          code: "BAD_ARGS", message: "Missing or invalid `url` argument",
          details: nil))
      return
    }
    let callbackScheme = args["callbackScheme"] as? String
    let redirectUriString = args["redirectUri"] as? String
    let preferEphemeral = (args["preferEphemeral"] as? Bool) ?? false
    let options = args["options"] as? [String: Any]
    let callbackMode = (options?["callbackMode"] as? String) ?? "auto"
    let additionalHeaders = options?["additionalHeaderFields"] as? [String: String]

    // Supersede any flow still in flight (resolving its Future as cancelled)
    // before starting a new one, so we never silently leak a pending session.
    cancelInFlight()

    // All `pendingResult`/session/provider mutation + the reply stay on the
    // main thread; the completion handler carries no documented thread
    // guarantee and may run off it.
    let completion: (URL?, Error?) -> Void = { [weak self] callbackURL, error in
      guard let self = self else { return }
      self.onMain {
        guard let pending = self.pendingResult else { return }
        self.pendingResult = nil
        self.session = nil
        self.contextProvider = nil
        if let error = error as NSError? {
          pending(OidcPlugin.mapError(error))
        } else {
          pending(callbackURL?.absoluteString)
        }
      }
    }

    let newSession: ASWebAuthenticationSession
    // `init(url:callbackURLScheme:)` is deprecated on iOS 17.4; the newer
    // `init(url:callback:)` additionally supports https / Universal-Link
    // redirects via `Callback.https(host:path:)`.
    if #available(iOS 17.4, *), let scheme = callbackScheme {
      let callback: ASWebAuthenticationSession.Callback
      // Honor the explicit callbackMode; "auto" derives it from the scheme.
      let wantsHttps =
        callbackMode == "https"
        || (callbackMode == "auto"
          && scheme.caseInsensitiveCompare("https") == .orderedSame)
      if wantsHttps,
        let redirectUriString,
        let redirectUrl = URL(string: redirectUriString),
        let host = redirectUrl.host
      {
        // Universal-Link redirect. NOTE: this requires the consuming app to
        // declare an Associated Domains entitlement (`webcredentials:<host>`).
        callback = .https(host: host, path: redirectUrl.path)
      } else {
        callback = .customScheme(scheme)
      }
      newSession = ASWebAuthenticationSession(
        url: url, callback: callback, completionHandler: completion)
    } else {
      newSession = ASWebAuthenticationSession(
        url: url, callbackURLScheme: callbackScheme,
        completionHandler: completion)
    }

    // Extra headers on the initial request (iOS 17.4+); ignored before that.
    if #available(iOS 17.4, *), let additionalHeaders {
      newSession.additionalHeaderFields = additionalHeaders
    }

    let provider = OidcPresentationContextProvider()
    contextProvider = provider
    newSession.presentationContextProvider = provider
    newSession.prefersEphemeralWebBrowserSession = preferEphemeral
    session = newSession
    pendingResult = result

    if !newSession.start() {
      pendingResult = nil
      session = nil
      contextProvider = nil
      reply(
        result,
        FlutterError(
          code: "START_FAILED",
          message: "ASWebAuthenticationSession.start() returned false",
          details: nil))
    }
  }

  private static func cancelledError() -> FlutterError {
    return FlutterError(
      code: "USER_CANCELLED",
      message: "The flow was cancelled by the user", details: nil)
  }

  private static func mapError(_ error: NSError) -> FlutterError {
    if error.domain == ASWebAuthenticationSessionError.errorDomain {
      switch error.code {
      case ASWebAuthenticationSessionError.canceledLogin.rawValue:
        return cancelledError()
      case ASWebAuthenticationSessionError.presentationContextNotProvided.rawValue,
        ASWebAuthenticationSessionError.presentationContextInvalid.rawValue:
        return FlutterError(
          code: "PRESENTATION_CONTEXT_INVALID",
          message: error.localizedDescription,
          // Preserve the original numeric code for diagnosability.
          details: ["code": error.code])
      default:
        break
      }
    }
    return FlutterError(
      code: "PLATFORM_ERROR", message: error.localizedDescription,
      details: ["domain": error.domain, "code": error.code])
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
    if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
      return keyWindow
    }
    // Fall back to any window of the first connected scene rather than a bare,
    // unattached anchor (which iOS rejects with presentationContextInvalid).
    let anyWindow =
      UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first
    return anyWindow ?? ASPresentationAnchor()
  }
}
