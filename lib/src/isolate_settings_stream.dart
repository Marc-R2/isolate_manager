import 'dart:async';

import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager/src/base/contactor/models/isolate_port.dart';
import 'package:isolate_manager/src/base/isolate_contactor.dart';

dynamic Function(P) _function<R, P>(dynamic params) {
  if (params is IsolateFunctionStream<R, P>) {
    return params;
  } else if (params is IsolateFunctionIterable<R, P>) {
    return params;
  }
  throw ArgumentError('Invalid function type');
}

void _defaultStreamFunction<R, P>(dynamic params) {
  IsolateManagerFunction.customFunction<R, P>(
    params,
    autoSendState: false,
    autoHandleResult: false,
    onEvent: (controller, message) async {
      final function = _function<R, P>(controller.initialParams);
      assert(
        function is IsolateFunctionStream<R, P> ||
            function is IsolateFunctionIterable<R, P>,
        'Invalid function type',
      );
      controller.sendState(TaskState.started);

      final result = function.call(message);
      if (result is Stream<R>) {
        return _handleStream(result, controller);
      } else if (result is Iterable<R>) {
        return _handleStream(Stream.fromIterable(result), controller);
      } else {
        throw ArgumentError('Invalid function type');
      }
    },
  );
}

Future<R> _handleStream<R>(
  Stream<R> stream,
  IsolateRuntimeController<dynamic, dynamic> controller,
) {
  final completer = Completer<R>();

  late final StreamSubscription<R> sub;
  R? lastResult;
  sub = stream.listen(
    (event) {
      lastResult = event;
      controller.sendResult(event);
    },
    onError: (Object error, StackTrace stackTrace) {
      controller.sendResultError(error, stackTrace);
      sub.cancel();
    },
    onDone: () {
      sub.cancel();
      controller.sendState(TaskState.done);
      if (lastResult != null) {
        completer.complete(lastResult);
      } else {
        completer.completeError('Stream is empty');
      }
    },
  );

  return completer.future;
}

class IsolateSettingsIterable<R, P> extends IsolateSettingsSync<R, P> {
  const IsolateSettingsIterable({
    required this.isolateFunction,
    super.converter,
    super.workerConverter,
    super.workerName = '',
    super.customAsyncConcurrent,
    super.isDebug = false,
  }) : super(isolateFunction: isolateFunction);

  @override
  final IsolateFunctionIterable<R, P> isolateFunction;

  @override
  (void Function(dynamic), Object?) get typedIsolateFunction =>
      (_defaultStreamFunction<R, P>, isolateFunction);
}

class IsolateSettingsStream<R, P> extends IsolateSettingsAsync<R, P> {
  const IsolateSettingsStream({
    required this.isolateFunction,
    super.converter,
    super.workerConverter,
    super.workerName = '',
    super.customAsyncConcurrent,
    super.isDebug = false,
  }) : super(isolateFunction: isolateFunction);

  @override
  final IsolateFunctionStream<R, P> isolateFunction;

  @override
  (void Function(dynamic), Object?) get typedIsolateFunction =>
      (_defaultStreamFunction<R, P>, isolateFunction);
}
