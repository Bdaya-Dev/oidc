import AuthenticationServices
import Flutter
import UIKit

/// First-party iOS implementation of the oidc browser primitive.
///
/// Opens the authorization / end-session URL (already fully built by Dart
/// `oidc_core`, including PKCE/state/nonce) in an `ASWebAuthenticationSession`
/// and returns the captured redirect URI string back to Dart, which parses it.
/// No OIDC logic lives here — this replaces the `flutter_appauth` dependency.
public class OidcPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var session: ASWebAuthenticationSession?
  // A strong reference to the presentation-context provider is required: if it
  // is deallocated while the session is in flight the app crashes with
  // EXC_BAD_ACCESS (#213).
  private var contextProvider: OidcPresentationContextProvider?
  // Held so an in-flight flow can be resolved exactly once — by the session
  // completion handler, an explicit `cancel`, or being superseded by a new
  // flow.
  private var pendingResult: FlutterResult?
  private var eventSink: FlutterEventSink?
  private var flowId: String?
  private var flowCounter = 0

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.bdayadev.oidc/ios", binaryMessenger: registrar.messenger())
    let instance = OidcPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    // Observability event channel (OidcNativeChannels.iosEvents).
    let events = FlutterEventChannel(
      name: "com.bdayadev.oidc/ios/events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  /// Emits an observability event to Dart on the main thread.
  private func emit(_ type: String, _ extra: [String: Any?] = [:]) {
    guard let sink = eventSink else { return }
    var event: [String: Any?] = [
      "type": type,
      "flowId": flowId as Any?,
      "timestampMs": Int(Date().timeIntervalSince1970 * 1000),
    ]
    for (k, v) in extra { event[k] = v }
    onMain { sink(event) }
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
        self.emit("cancelled")
        pending(OidcPlugin.cancelledError())
      }
      self.session = nil
      self.contextProvider = nil
    }
  }

  /// Emits a redacted `redirectReceived` event (no raw URI / secrets).
  private func emitRedirect(_ url: URL?) {
    guard let url = url else { return }
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    func has(_ name: String) -> Bool { items.contains { $0.name == name } }
    emit(
      "redirectReceived",
      [
        "scheme": url.scheme as Any?,
        "host": url.host as Any?,
        "hasCode": has("code"),
        "hasState": has("state"),
        "hasError": has("error"),
      ])
  }

  /// Emits a `cancelled` or structured `failed` event from a session error.
  private func emitError(_ error: NSError) {
    if error.domain == ASWebAuthenticationSessionError.errorDomain,
      error.code == ASWebAuthenticationSessionError.canceledLogin.rawValue
    {
      emit("cancelled")
      return
    }
    var kind = "platformError"
    if error.domain == ASWebAuthenticationSessionError.errorDomain {
      switch error.code {
      case ASWebAuthenticationSessionError.presentationContextNotProvided.rawValue:
        kind = "presentationContextNotProvided"
      case ASWebAuthenticationSessionError.presentationContextInvalid.rawValue:
        kind = "presentationContextInvalid"
      default:
        break
      }
    }
    emit(
      "failed",
      [
        "error": [
          "kind": kind,
          "nativeDomain": error.domain,
          "nativeCode": error.code,
          "message": error.localizedDescription,
        ] as [String: Any?]
      ])
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

    flowCounter += 1
    flowId = String(flowCounter)
    emit("opening")

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
          self.emitError(error)
          pending(OidcPlugin.mapError(error))
        } else {
          self.emitRedirect(callbackURL)
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

    if newSession.start() {
      emit(
        "opened",
        [
          "sessionType": preferEphemeral ? "ephemeral" : "standard",
          "captureMode": "asWebAuthenticationSession",
        ])
    } else {
      pendingResult = nil
      session = nil
      contextProvider = nil
      emit(
        "failed",
        [
          "error": [
            "kind": "startFailed",
            "message": "ASWebAuthenticationSession.start() returned false",
          ] as [String: Any?]
        ])
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
