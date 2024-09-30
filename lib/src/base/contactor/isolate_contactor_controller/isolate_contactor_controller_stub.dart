import 'dart:async';

import 'package:isolate_manager/src/base/contactor/isolate_contactor_controller/streams.dart';
import 'package:isolate_manager/src/base/contactor/models/isolate_port.dart';
import 'package:isolate_manager/src/base/contactor/models/isolate_state.dart';
import 'package:stream_channel/isolate_channel.dart';

import '../isolate_contactor.dart';
import '../isolate_contactor_controller.dart';
import '../models/exception.dart';

class IsolateContactorControllerImpl<R, P>
    with Streams<R, P>
    implements IsolateContactorController<R, P> {
  final IsolateChannel _delegate;
  late final StreamSubscription _delegateSubscription;

  final void Function()? onDispose;
  final IsolateConverter<R>? converter;
  final dynamic _initialParams;

  IsolateContactorControllerImpl(
    dynamic params, {
    required this.onDispose,
    required this.converter, // Converter for native
    required IsolateConverter<R>?
        workerConverter, // Converter for Worker (Web Only)
  })  : _delegate = params is List
            ? IsolateChannel.connectSend(params.last)
            : IsolateChannel.connectReceive(params),
        _initialParams = params is List ? params.first : null {
    _delegateSubscription = _delegate.stream.listen(handleDelegate);
  }

  @override
  dynamic useConverter(dynamic value) => converter?.call(value) ?? value;

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
  Future<void> close() async => await Future.wait([
        _delegateSubscription.cancel(),
        closeStream(),
      ]);
}
