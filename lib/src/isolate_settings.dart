import 'dart:async';

import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager/src/base/contactor/models/isolate_port.dart';
import 'package:isolate_manager/src/base/isolate_contactor.dart';
import 'package:isolate_manager/src/models/async_concurrent.dart';

enum SettingsType {
  sync(AsyncConcurrentSingle(), false),
  future(AsyncConcurrentOtherAsync(), true),
  custom(AsyncConcurrentSingle(), true),
  iterable(AsyncConcurrentSingle(), false),
  stream(AsyncConcurrentOtherAsync(), true);

  const SettingsType(this.defaultAsyncConcurrent, this.isAsync);

  final AsyncConcurrent defaultAsyncConcurrent;

  final bool isAsync;
}

class IsolateSettings<R, P> {
  /// TODO: disallow `Future` as return type of [isolateFunction]
  const IsolateSettings.sync({
    required IsolateSync<R, P> isolateFunction,
    this.converter,
    this.workerConverter,
    this.workerName = '',
    this.customAsyncConcurrent,
    this.isDebug = false,
  })  : _isolateFunction = isolateFunction,
        type = SettingsType.sync,
        initialParams = null;

  const IsolateSettings.future({
    required IsolateFuture<R, P> isolateFunction,
    this.converter,
    this.workerConverter,
    this.workerName = '',
    this.customAsyncConcurrent,
    this.isDebug = false,
  })  : _isolateFunction = isolateFunction,
        type = SettingsType.future,
        initialParams = null;

  const IsolateSettings.stream({
    required IsolateStream<R, P> isolateFunction,
    this.converter,
    this.workerConverter,
    this.workerName = '',
    this.customAsyncConcurrent,
    this.isDebug = false,
  })  : _isolateFunction = isolateFunction,
        type = SettingsType.stream,
        initialParams = null;

  const IsolateSettings.iterable({
    required IsolateIterable<R, P> isolateFunction,
    this.converter,
    this.workerConverter,
    this.workerName = '',
    this.customAsyncConcurrent,
    this.isDebug = false,
  })  : _isolateFunction = isolateFunction,
        type = SettingsType.iterable,
        initialParams = null;

  const IsolateSettings.custom({
    required IsolateCustomFunction isolateFunction,
    this.converter,
    this.workerConverter,
    this.workerName = '',
    this.initialParams,
    this.customAsyncConcurrent,
    this.isDebug = false,
  })  : _isolateFunction = isolateFunction,
        type = SettingsType.custom;

  static dynamic Function(P) _function<R, P>(dynamic params) {
    if (params is IsolateFuture<R, P>) {
      return params;
    } else if (params is IsolateStream<R, P>) {
      return params;
    } else if (params is IsolateIterable<R, P>) {
      return params;
    }
    throw ArgumentError('Invalid function type');
  }

  /// A default function for using the [IsolateSettings] method.
  static void _defaultIsolateFunction<R, P>(dynamic params) {
    IsolateManagerFunction.customFunction<R, P>(
      params,
      onEvent: (controller, message) {
        final function = _function<R, P>(controller.initialParams);
        assert(function is IsolateFuture<R, P>, 'Invalid function type');
        return function.call(message);
      },
    );
  }

  static void _defaultStreamFunction<R, P>(dynamic params) {
    IsolateManagerFunction.customFunction<R, P>(
      params,
      autoSendState: false,
      autoHandleResult: false,
      onEvent: (controller, message) async {
        final function = _function<R, P>(controller.initialParams);
        assert(
          function is IsolateStream<R, P> || function is IsolateIterable<R, P>,
          'Invalid function type',
        );
        controller.sendState(TaskState.started);

        final result = function.call(message);
        if (result is Stream<R>) {
          return _handleStream(result, controller);
        } else if (result is Iterable<R>) {
          return _handleStream(Stream.fromIterable(result), controller);
        } else {
          // controller.sendState(TaskState.error);
          throw ArgumentError('Invalid function type');
        }
      },
    );
  }

  static Future<R> _handleStream<R>(
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

  /// Isolate function.
  final Object _isolateFunction;

  /// Name of the `Worker` without the extension.
  ///
  /// Ex: Worker: `worker.js` => workerName: 'worker;
  ///     Worker: `workers/worker.js` => workerName: 'workers/worker'
  final String workerName;

  /// Initial parameters.
  final Object? initialParams;

  /// Is using your own isolate function.
  final SettingsType type;

  /// Allow print debug log.
  final bool isDebug;

  /// Convert the result received from the isolate before getting real result.
  /// This function useful when the result received from the isolate is different
  /// from the return type.
  final IsolateConverter<R>? converter;

  /// Convert the result received from the isolate before getting real result.
  /// This function useful when the result received from the isolate is different
  /// from the return type.
  ///
  /// This function only available in `Worker` mode on Web platform.
  final IsolateConverter<R>? workerConverter;

  final AsyncConcurrent? customAsyncConcurrent;

  Future<IsolateContactor<R, P>> createIsolateContactor() async {
    final iso = (_defaultIsolateFunction<R, P>, this._isolateFunction);
    final stream = (_defaultStreamFunction<R, P>, this._isolateFunction);

    final (isolateFunctionData, paramsData) = switch (type) {
      SettingsType.sync => iso,
      SettingsType.future => iso,
      SettingsType.stream => stream,
      SettingsType.iterable => stream,
      SettingsType.custom => (
          _isolateFunction as IsolateCustomFunction,
          initialParams,
        ),
    };

    return IsolateContactor.createCustom<R, P>(
      isolateFunctionData,
      workerName: workerName,
      initialParams: paramsData,
      converter: converter,
      workerConverter: workerConverter,
      debugMode: isDebug,
    );
  }
}
