import 'dart:async';
import 'dart:isolate';

import 'package:isolate_manager/src/base/contactor/isolate_contactor.dart';
import 'package:isolate_manager/src/base/contactor/isolate_contactor_controller.dart';
import 'package:isolate_manager/src/base/contactor/isolate_contactor_controller/streams.dart';
import 'package:isolate_manager/src/base/contactor/models/exception.dart';
import 'package:isolate_manager/src/base/contactor/models/isolate_port.dart';
import 'package:isolate_manager/src/base/contactor/models/isolate_state.dart';
import 'package:stream_channel/isolate_channel.dart';

class IsolateContactorControllerImpl<R, P>
    with Streams<R, P>
    implements IsolateContactorController<R, P> {
  IsolateContactorControllerImpl(
    dynamic params, {
    required this.onDispose,
    required this.converter, // Converter for native
    required IsolateConverter<R>?
        workerConverter, // Converter for Worker (Web Only)
  })  : _delegate = params is List
            ? IsolateChannel.connectSend(
                (params as List<Object?>).last! as SendPort)
            : IsolateChannel.connectReceive(params as ReceivePort),
        _initialParams = params is List ? params.first : null {
    _delegateSubscription = _delegate.stream.listen(handleDelegate);
  }

  final IsolateChannel<(IsolatePort, dynamic)> _delegate;
  late final StreamSubscription<(IsolatePort, dynamic)> _delegateSubscription;

  @override
  final void Function()? onDispose;

  final IsolateConverter<R>? converter;

  final dynamic _initialParams;

  @override
  R useConverter(dynamic value) => converter?.call(value) ?? (value as R);

  /// Get initial params for `createCustom`
  @override
  dynamic get initialParams => _initialParams;

  @override
  void initialized() =>
      _delegate.sink.add((IsolatePort.main, IsolateState.initialized));

  @override
  void sendIsolate(P message) =>
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
        _delegateSubscription.cancel(),
        closeStream(),
      ]);
}
