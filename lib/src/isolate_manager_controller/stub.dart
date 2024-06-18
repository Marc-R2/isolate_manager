import 'dart:async';

import 'package:isolate_manager/isolate_manager.dart';

import '../base/isolate_contactor.dart';

/// This method only use to create a custom isolate.
///
/// The [params] is a default parameter of a custom isolate function.
/// `onDispose` will be called when the controller is disposed.
class IsolateManagerControllerImpl<R, P>
    implements IsolateManagerController<R, P> {
  /// Delegation of IsolateContactor.
  final IsolateContactorController<R, P> _delegate;

  /// This method only use to create a custom isolate.
  ///
  /// The [params] is a default parameter of a custom isolate function.
  /// `onDispose` will be called when the controller is disposed.
  IsolateManagerControllerImpl(
    dynamic params, {
    void Function()? onDispose,
  }) : _delegate = IsolateContactorController<R, P>(
          params,
          onDispose: onDispose,
        );

  /// Get initial parameters when you create the IsolateManager.
  @override
  dynamic get initialParams => _delegate.initialParams;

  /// This parameter is only used for Isolate. Use to listen for values from the main application.
  @override
  Stream<P> get onIsolateMessage => _delegate.onIsolateMessage;

  /// Mark the isolate as initialized.
  ///
  /// This method is automatically applied when using `IsolateManagerFunction.customFunction`
  /// and `IsolateManagerFunction.workerFunction`.
  @override
  void initialized() => _delegate.initialized();

  /// Close this `IsolateManagerController`.
  @override
  Future<void> close() => _delegate.close();

  /// Send values from Isolate to the main application (to `onMessage`).
  @override
  void sendResult(dynamic result) => _delegate.sendResult(result);

  /// Send the `Exception` to the main app.
  @override
  void sendResultError(IsolateException exception) =>
      _delegate.sendResultError(exception);
}
