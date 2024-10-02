import 'dart:async';
import 'dart:js_interop';

import 'package:isolate_manager/src/base/contactor/isolate_contactor.dart';
import 'package:isolate_manager/src/base/contactor/isolate_contactor_controller/isolate_contactor_controller_web.dart';
import 'package:isolate_manager/src/base/contactor/models/exception.dart';
import 'package:isolate_manager/src/base/contactor/models/isolate_state.dart';
import 'package:web/web.dart';

class IsolateContactorControllerImplWorker<R, P>
    implements IsolateContactorControllerImpl<R, P> {
  IsolateContactorControllerImplWorker(
    dynamic params, {
    required this.onDispose,
    // ignore: avoid_unused_constructor_parameters
    required IsolateConverter<R> converter, // Converter for native
    required this.workerConverter, // Converter for Worker (Web Only)
  })  : _delegate = params is List
            ? params.last.controller as Worker
            : params as Worker,
        _initialParams = params is List ? params.first : null {
    _delegate.onmessage = (MessageEvent event) {
      if (IsolateState.dispose.isValidJson(event.data)) {
        onDispose!();
        close();
        return;
      }

      if (IsolateState.initialized.isValidJson(event.data)) {
        if (!ensureInitialized.isCompleted) {
          ensureInitialized.complete();
        }
        return;
      }

      if (IsolateException.isValidObject(event.data)) {
        final exception = IsolateException.fromJson(event.data);
        _mainStreamController.addError(
          exception.error.toString(),
          StackTrace.empty,
        );
        return;
      }

      // Decode json from string which sent from isolate
      _mainStreamController.add(workerConverter(event.data));
    }.toJS;
  }

  final Worker _delegate;

  final StreamController<R> _mainStreamController =
      StreamController.broadcast();

  final void Function()? onDispose;
  final IsolateConverter<R> workerConverter;
  final dynamic _initialParams;

  @override
  Completer<void> ensureInitialized = Completer();

  /// Get this Worker
  @override
  Worker get controller => _delegate;

  /// Get initial params for `createCustom`
  @override
  dynamic get initialParams => _initialParams;

  @override
  Stream<R> get onMessage => _mainStreamController.stream;

  @override
  Stream<P> get onIsolateMessage => throw UnimplementedError();

  @override
  Future<void> initialized() => throw UnimplementedError();

  @override
  void sendIsolate(P message) {
    _delegate.postMessage(message as dynamic);
  }

  @override
  void sendIsolateState(IsolateState state) {
    _delegate.postMessage(state.toJson().toJS);
  }

  @override
  void sendResult(R message) => throw UnimplementedError();

  @override
  void sendResultError(IsolateException exception) =>
      throw UnimplementedError();

  @override
  Future<void> close() async {
    _delegate.terminate();
    await _mainStreamController.close();
  }
}
