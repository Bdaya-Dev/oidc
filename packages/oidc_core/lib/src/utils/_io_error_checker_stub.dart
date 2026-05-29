/// Stub implementation for platforms where `dart:io` is not available (web).
///
/// These always return `false` because `SocketException` and
/// `HandshakeException` cannot exist on web.
bool isSocketException(Object error) => false;
bool isHandshakeException(Object error) => false;
