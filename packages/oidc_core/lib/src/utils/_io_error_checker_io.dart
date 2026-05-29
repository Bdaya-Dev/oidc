import 'dart:io';

/// Native implementation using actual `dart:io` types.
bool isSocketException(Object error) => error is SocketException;
bool isHandshakeException(Object error) =>
    error is HandshakeException || error is TlsException;
