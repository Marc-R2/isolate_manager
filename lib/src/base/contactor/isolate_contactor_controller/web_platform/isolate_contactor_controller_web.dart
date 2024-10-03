import 'dart:async';

import 'package:isolate_manager/src/base/contactor/isolate_contactor.dart';
import 'package:isolate_manager/src/base/contactor/isolate_contactor_controller/isolate_contactor_controller_web.dart';
import 'package:isolate_manager/src/base/contactor/isolate_contactor_controller/streams.dart';
import 'package:isolate_manager/src/base/contactor/models/exception.dart';
import 'package:isolate_manager/src/base/contactor/models/isolate_port.dart';
import 'package:isolate_manager/src/base/contactor/models/isolate_state.dart';
import 'package:isolate_manager/src/isolate_manager.dart';

class IsolateContactorControllerImplFuture<R, P>
    with Streams<R, P>
    implements IsolateContactorControllerImpl<R, P> {
  IsolateContactorControllerImplFuture(
    dynamic params, {
    required this.onDispose,
    required this.converter,
    // required IsolateConverter<R> workerConverter,
  })  : _delegate = params is List<IsolateContactorControllerImplFuture>
            ? params.last.controller
            : params as StreamController<(IsolatePort, dynamic)>,
        _initialParams = params is List ? params.first : null {
    _delegateSubscription = _delegate.stream.listen(handleDelegate);
  }

  final StreamController<(IsolatePort, dynamic)> _delegate;
  late final StreamSubscription<(IsolatePort, dynamic)> _delegateSubscription;

  @override
  final void Function()? onDispose;

  final IsolateConverter<R> converter;

  final dynamic _initialParams;

  @override
  R useConverter(dynamic value) => converter.call(value);

  /// Get this StreamController
  @override
  StreamController<(IsolatePort, dynamic)> get controller => _delegate;

  /// Get initial params for `createCustom`
  @override
  dynamic get initialParams => _initialParams;

  @override
  void initialized() =>
      _delegate.sink.add((IsolatePort.main, IsolateState.initialized));

  @override
  void sendIsolate(Msg<P> message) =>
      _delegate.sink.add((IsolatePort.isolate, message));

  @override
  void sendIsolateState(IsolateState state) =>
      _delegate.sink.add((IsolatePort.isolate, state));

  @override
  void sendResult(R message) => _delegate.sink.add((IsolatePort.main, message));

  @override
  void sendResultError(IsolateException exception) =>
      _delegate.sink.add((IsolatePort.main, exception));

  @override
  Future<void> close() async => Future.wait([
        _delegate.close(),
        _delegateSubscription.cancel(),
        closeStream(),
      ]);
}
