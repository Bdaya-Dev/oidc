import 'dart:async';

/// {@template oidc_value_stream}
/// A minimal value-caching broadcast stream.
///
/// It stores the latest [value], exposes it synchronously, and replays it to
/// every new subscriber before forwarding live updates — the same contract
/// `oidc` previously relied on from `rxdart`'s `BehaviorSubject`, but with no
/// third-party reactive-streams dependency.
///
/// Replay is gap-free: a new listener's subscription to the underlying
/// broadcast controller is established synchronously inside `onListen`, right
/// after the current value is queued, so no concurrent [add] can be missed.
/// {@endtemplate}
class OidcValueStream<T> {
  /// {@macro oidc_value_stream}
  ///
  /// Seeds the stream with [value], which becomes the initial [value] replayed
  /// to listeners until the next [add].
  OidcValueStream(this._value);

  T _value;
  final StreamController<T> _controller = StreamController<T>.broadcast();

  /// The latest value (synchronous), equivalent to `BehaviorSubject.value`.
  T get value => _value;

  /// Whether [close] has been called on the underlying controller.
  bool get isClosed => _controller.isClosed;

  /// Updates [value] and emits it to all current listeners.
  ///
  /// A no-op emit after [close] is ignored rather than throwing.
  void add(T newValue) {
    _value = newValue;
    if (!_controller.isClosed) {
      _controller.add(newValue);
    }
  }

  /// A stream that replays the current [value] on listen, then emits every
  /// subsequent [add]. Multi-subscription: each listener gets its own
  /// independent, gap-free replay (the current value is added synchronously
  /// before the live subscription is established, so no [add] is missed).
  Stream<T> get stream => Stream<T>.multi((controller) {
    controller.add(_value);
    final sub = _controller.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = sub.cancel;
  });

  /// Subscribes to [stream]; mirrors `BehaviorSubject.listen`.
  StreamSubscription<T> listen(
    void Function(T value)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  /// Closes the underlying broadcast controller.
  Future<void> close() => _controller.close();
}
