import AppKit
import AuthenticationServices
import FlutterMacOS
import Foundation

/// First-party macOS implementation of the oidc browser primitive.
///
/// Opens the authorization / end-session URL (already fully built by Dart
/// `oidc_core`, including PKCE/state/nonce) in an `ASWebAuthenticationSession`
/// and returns the captured redirect URI string back to Dart, which parses it.
/// No OIDC logic lives here — this replaces the `flutter_appauth` dependency.
///
/// Mirrors `oidc_ios`'s implementation; the only platform difference is the
/// presentation anchor, which is an AppKit `NSWindow` instead of a UIKit
/// `UIWindow`.
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
      name: "com.bdayadev.oidc/macos", binaryMessenger: registrar.messenger)
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
  /// pending Dart Future must be resolved here explicitly.
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
    let preferEphemeral = (args["preferEphemeral"] as? Bool) ?? false

    // Supersede any flow still in flight (resolving its Future as cancelled)
    // before starting a new one, so we never silently leak a pending session.
    cancelInFlight()

    let newSession = ASWebAuthenticationSession(
      url: url, callbackURLScheme: callbackScheme
    ) { [weak self] callbackURL, error in
      guard let self = self else { return }
      // All `pendingResult`/session/provider mutation + the reply stay on the
      // main thread; the completion handler may run off it.
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

/// Supplies the window to present the `ASWebAuthenticationSession` over. On
/// macOS the `ASPresentationAnchor` is an AppKit `NSWindow`.
private final class OidcPresentationContextProvider: NSObject,
  ASWebAuthenticationPresentationContextProviding
{
  func presentationAnchor(for session: ASWebAuthenticationSession)
    -> ASPresentationAnchor
  {
    return NSApplication.shared.keyWindow
      ?? NSApplication.shared.mainWindow
      ?? NSApplication.shared.windows.first
      ?? ASPresentationAnchor()
  }
}
