import 'dart:async';
import 'dart:js_interop';

import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager/src/base/isolate_contactor.dart';
import 'package:web/web.dart';

/// This method only use to create a custom isolate.
///
/// The [params] is a default parameter of a custom isolate function.
/// `onDispose` will be called when the controller is disposed.
class IsolateManagerControllerImpl<R, P>
    implements IsolateManagerController<R, P> {
  /// This method only use to create a custom isolate.
  ///
  /// The [params] is a default parameter of a custom isolate function.
  /// `onDispose` will be called when the controller is disposed.
  IsolateManagerControllerImpl(
    dynamic params, {
    void Function()? onDispose,
  }) : _delegate = params.runtimeType == DedicatedWorkerGlobalScope
            ? _IsolateManagerWorkerController<R, P>(
                params as DedicatedWorkerGlobalScope,
              )
            : IsolateContactorController<R, P>(params, onDispose: onDispose);

  /// Delegation of IsolateContactor.
  final IsolateContactorController<R, P> _delegate;

  /// Mark the isolate as initialized.
  ///
  /// This method is automatically applied when using `IsolateManagerFunction.customFunction`
  /// and `IsolateManagerFunction.workerFunction`.
  @override
  void initialized() => _delegate.initialized();

  /// Close this `IsolateManagerController`.
  @override
  Future<void> close() => _delegate.close();

  /// Get initial parameters when you create the IsolateManager.
  @override
  dynamic get initialParams => _delegate.initialParams;

  /// This parameter is only used for Isolate. Use to listen for values from the main application.
  @override
  Stream<Msg<P>> get onIsolateMessage => _delegate.onIsolateMessage;

  /// Send values from Isolate to the main application (to `onMessage`).
  @override
  void sendResult(Msg<R> result) => _delegate.sendResult(result);

  /// Send the `Exception` to the main app.
  @override
  void sendResultError(IsolateException exception) =>
      _delegate.sendResultError(exception);
}

class _IsolateManagerWorkerController<R, P>
    implements IsolateContactorController<R, P> {
  _IsolateManagerWorkerController(this.self) {
    self.onmessage = (MessageEvent event) {
      _streamController.sink.add(event.data as dynamic);
    }.toJS;
  }

  final DedicatedWorkerGlobalScope self;
  final _streamController = StreamController<Msg<P>>.broadcast();

  @override
  Stream<Msg<P>> get onIsolateMessage => _streamController.stream;

  @override
  Object? get initialParams => null;

  /// Send result to the main app
  @override
  void sendResult(dynamic m) {
    self.postMessage(m);
  }

  /// Send error to the main app
  @override
  void sendResultError(IsolateException exception) {
    sendResult(exception.toJson());
  }

  /// Mark the Worker as initialized
  @override
  void initialized() {
    sendResult(IsolateState.initialized.toJson());
  }

  /// Close this `IsolateManagerWorkerController`.
  @override
  Future<void> close() async {
    self.close();
  }

  @override
  Completer<void> get ensureInitialized => throw UnimplementedError();

  @override
  Stream<Msg<R>> get onMessage => throw UnimplementedError();

  @override
  void sendIsolate(Msg<P> message) => throw UnimplementedError();

  @override
  void sendIsolateState(IsolateState state) => throw UnimplementedError();
}
