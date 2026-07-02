import AuthenticationServices
import Foundation

#if os(iOS)
  import Flutter
  import UIKit
#elseif os(macOS)
  import AppKit
  import FlutterMacOS
#endif

/// First-party iOS + macOS ("darwin") implementation of the oidc browser
/// primitive.
///
/// Opens the authorization / end-session URL (already fully built by Dart
/// `oidc_core`, including PKCE/state/nonce) in an `ASWebAuthenticationSession`
/// and returns the captured redirect URI string back to Dart, which parses it.
/// No OIDC logic lives here — this replaces the `flutter_appauth` dependency.
///
/// A single platform-guarded source serves both Apple platforms (the Flutter
/// `sharedDarwinSource` layout). The only genuine platform differences are the
/// module imports, the registrar messenger accessor, the iOS 17.4 / macOS 14.4
/// availability gates, and the UIKit-vs-AppKit presentation anchor.
///
/// The Dart<->native transport is the Pigeon-generated `OidcAppleHostApi` plus
/// a Pigeon event channel for observability events.
public class OidcPlugin: NSObject, FlutterPlugin, OidcAppleHostApi {
  private var session: ASWebAuthenticationSession?
  // A strong reference to the presentation-context provider is required: if it
  // is deallocated while the session is in flight the app crashes with
  // EXC_BAD_ACCESS (#213).
  private var contextProvider: OidcPresentationContextProvider?
  // Held so an in-flight flow can be resolved exactly once — by the session
  // completion handler, an explicit `cancel`, or being superseded by a new
  // flow.
  private var pendingCompletion: ((Result<String?, Error>) -> Void)?
  private let eventStreamHandler = OidcEventStreamHandler()
  private var flowId: String?
  private var flowCounter = 0

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = OidcPlugin()
    #if os(iOS)
      let messenger = registrar.messenger()
    #elseif os(macOS)
      let messenger = registrar.messenger
    #endif
    // Pigeon host API (replaces the hand-rolled FlutterMethodChannel).
    OidcAppleHostApiSetup.setUp(binaryMessenger: messenger, api: instance)
    // Observability event channel.
    StreamNativeEventsStreamHandler.register(
      with: messenger, streamHandler: instance.eventStreamHandler)
  }

  /// Emits an observability event to Dart on the main thread.
  private func emit(_ type: String, _ extra: [String: Any?] = [:]) {
    guard let sink = eventStreamHandler.sink else { return }
    var event: [String: Any?] = [
      "type": type,
      "flowId": flowId as Any?,
      "timestampMs": Int(Date().timeIntervalSince1970 * 1000),
    ]
    for (k, v) in extra { event[k] = v }
    onMain { sink.success(event) }
  }

  // region OidcAppleHostApi — both flows are identical natively: open a URL,
  // capture the redirect. Pigeon guarantees `url` is non-null.
  public func authorizeApple(
    url: String, redirectUri: String?, callbackScheme: String?,
    preferEphemeral: Bool, options: [String: Any?],
    completion: @escaping (Result<String?, Error>) -> Void
  ) {
    startSession(
      url: url, redirectUri: redirectUri, callbackScheme: callbackScheme,
      preferEphemeral: preferEphemeral, options: options, completion: completion)
  }

  public func endSessionApple(
    url: String, redirectUri: String?, callbackScheme: String?,
    preferEphemeral: Bool, options: [String: Any?],
    completion: @escaping (Result<String?, Error>) -> Void
  ) {
    startSession(
      url: url, redirectUri: redirectUri, callbackScheme: callbackScheme,
      preferEphemeral: preferEphemeral, options: options, completion: completion)
  }

  public func cancelApple() throws {
    cancelInFlight()
  }
  // endregion

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
      if let pending = self.pendingCompletion {
        self.pendingCompletion = nil
        self.emit("cancelled")
        pending(.failure(OidcPlugin.cancelledError()))
      }
      self.session = nil
      self.contextProvider = nil
    }
  }

  /// Mirrors Android's `flowTimeoutSeconds` (OidcPlugin.kt `scheduleFlowTimeout`):
  /// when the caller set `OidcNativeOptionsApple.flowTimeoutSeconds`, arm a
  /// main-queue deadline that cancels a still-in-flight flow. On headless CI
  /// simulators the `ASWebAuthenticationSession` redirect can never arrive (no
  /// user can interact — and the iOS-26 simulator no longer auto-completes the
  /// programmatic conformance redirect that the iOS-18 simulator did), so without
  /// this the Dart Future never resolves and `loginAuthorizationCodeFlow` hangs
  /// to the test/job timeout. `flowId` guards against cancelling a newer flow
  /// that has already superseded this one.
  private func scheduleFlowTimeout(_ opts: [String: Any]) {
    guard let seconds = (opts["flowTimeoutSeconds"] as? NSNumber)?.intValue,
      seconds > 0
    else { return }
    let expectedFlowId = flowId
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(seconds)) {
      [weak self] in
      guard let self = self, self.pendingCompletion != nil,
        self.flowId == expectedFlowId
      else { return }
      self.emit("timeout", ["afterSeconds": seconds])
      self.cancelInFlight()
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
    url urlString: String, redirectUri redirectUriString: String?,
    callbackScheme: String?, preferEphemeral: Bool, options: [String: Any?],
    completion: @escaping (Result<String?, Error>) -> Void
  ) {
    guard let url = URL(string: urlString) else {
      completion(
        .failure(
          PigeonError(
            code: "BAD_ARGS", message: "Invalid `url` argument", details: nil)))
      return
    }
    // Drop nil values so the option reads below match the previous
    // `[String: Any]` shape.
    let opts = options.compactMapValues { $0 }
    let callbackMode = (opts["callbackMode"] as? String) ?? "auto"
    let additionalHeaders = opts["additionalHeaderFields"] as? [String: String]

    // Supersede any flow still in flight (resolving its Future as cancelled)
    // before starting a new one, so we never silently leak a pending session.
    cancelInFlight()

    flowCounter += 1
    flowId = String(flowCounter)
    emit("opening")

    // All `pendingCompletion`/session/provider mutation + the reply stay on the
    // main thread; the completion handler carries no documented thread
    // guarantee and may run off it.
    let onComplete: (URL?, Error?) -> Void = { [weak self] callbackURL, error in
      guard let self = self else { return }
      self.onMain {
        guard let pending = self.pendingCompletion else { return }
        self.pendingCompletion = nil
        self.session = nil
        self.contextProvider = nil
        if let error = error as NSError? {
          self.emitError(error)
          pending(.failure(OidcPlugin.mapError(error)))
        } else {
          self.emitRedirect(callbackURL)
          pending(.success(callbackURL?.absoluteString))
        }
      }
    }

    let newSession: ASWebAuthenticationSession
    // `init(url:callbackURLScheme:)` is deprecated on iOS 17.4 / macOS 14.4; the
    // newer `init(url:callback:)` additionally supports https / Universal-Link
    // redirects via `Callback.https(host:path:)`. One combined availability
    // check covers both platforms.
    if #available(iOS 17.4, macOS 14.4, *), let scheme = callbackScheme {
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
        url: url, callback: callback, completionHandler: onComplete)
    } else {
      newSession = ASWebAuthenticationSession(
        url: url, callbackURLScheme: callbackScheme,
        completionHandler: onComplete)
    }

    // Extra headers on the initial request (iOS 17.4+ / macOS 14.4+); ignored
    // before that.
    if #available(iOS 17.4, macOS 14.4, *), let additionalHeaders {
      newSession.additionalHeaderFields = additionalHeaders
    }

    let provider = OidcPresentationContextProvider()
    contextProvider = provider
    newSession.presentationContextProvider = provider
    newSession.prefersEphemeralWebBrowserSession = preferEphemeral
    session = newSession
    pendingCompletion = completion

    if newSession.start() {
      emit(
        "opened",
        [
          "sessionType": preferEphemeral ? "ephemeral" : "standard",
          "captureMode": "asWebAuthenticationSession",
        ])
      scheduleFlowTimeout(opts)
    } else {
      pendingCompletion = nil
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
      completion(
        .failure(
          PigeonError(
            code: "START_FAILED",
            message: "ASWebAuthenticationSession.start() returned false",
            details: nil)))
    }
  }

  private static func cancelledError() -> PigeonError {
    return PigeonError(
      code: "USER_CANCELLED",
      message: "The flow was cancelled by the user", details: nil)
  }

  private static func mapError(_ error: NSError) -> PigeonError {
    if error.domain == ASWebAuthenticationSessionError.errorDomain {
      switch error.code {
      case ASWebAuthenticationSessionError.canceledLogin.rawValue:
        return cancelledError()
      case ASWebAuthenticationSessionError.presentationContextNotProvided.rawValue,
        ASWebAuthenticationSessionError.presentationContextInvalid.rawValue:
        return PigeonError(
          code: "PRESENTATION_CONTEXT_INVALID",
          message: error.localizedDescription,
          // Preserve the original numeric code for diagnosability.
          details: ["code": error.code])
      default:
        break
      }
    }
    return PigeonError(
      code: "PLATFORM_ERROR", message: error.localizedDescription,
      details: ["domain": error.domain, "code": String(error.code)])
  }
}

/// Captures the Pigeon event sink for the observability stream.
private final class OidcEventStreamHandler: StreamNativeEventsStreamHandler {
  var sink: PigeonEventSink<[String: Any?]>?

  override func onListen(
    withArguments arguments: Any?, sink: PigeonEventSink<[String: Any?]>
  ) {
    self.sink = sink
  }

  override func onCancel(withArguments arguments: Any?) {
    sink = nil
  }
}

/// Supplies the window to present the `ASWebAuthenticationSession` over. On iOS
/// this is the active `UIWindowScene`'s key window; on macOS it is the AppKit
/// key/main window.
private final class OidcPresentationContextProvider: NSObject,
  ASWebAuthenticationPresentationContextProviding
{
  func presentationAnchor(for session: ASWebAuthenticationSession)
    -> ASPresentationAnchor
  {
    #if os(iOS)
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
    #elseif os(macOS)
      return NSApplication.shared.keyWindow
        ?? NSApplication.shared.mainWindow
        ?? NSApplication.shared.windows.first
        ?? ASPresentationAnchor()
    #endif
  }
}
