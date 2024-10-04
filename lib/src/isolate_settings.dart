import 'dart:async';

import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager/src/base/contactor/models/isolate_port.dart';
import 'package:isolate_manager/src/base/isolate_contactor.dart';

enum SettingsType {
  futureOr,
  futureOrCustom,
  stream,
}

class IsolateSettings<R, P> {
  const IsolateSettings({
    required IsolateFunction<R, P> isolateFunction,
    this.converter,
    this.workerConverter,
    this.workerName = '',
    this.isDebug = false,
  })  : _isolateFunction = isolateFunction,
        type = SettingsType.futureOr,
        initialParams = null;

  const IsolateSettings.stream({
    required IsolateStream<R, P> isolateFunction,
    this.converter,
    this.workerConverter,
    this.workerName = '',
    this.isDebug = false,
  })  : _isolateFunction = isolateFunction,
        type = SettingsType.stream,
        initialParams = null;

  const IsolateSettings.custom({
    required IsolateCustomFunction isolateFunction,
    this.converter,
    this.workerConverter,
    this.workerName = '',
    this.initialParams,
    this.isDebug = false,
  })  : _isolateFunction = isolateFunction,
        type = SettingsType.futureOrCustom;

  static dynamic Function(P) _function<R, P>(dynamic params) {
    if (params is IsolateFunction<R, P>) {
      return params;
    } else if (params is IsolateStream<R, P>) {
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
        assert(function is IsolateFunction<R, P>, 'Invalid function type');
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
        assert(function is IsolateStream<R, P>, 'Invalid function type');
        controller.sendState(TaskState.started);

        final stream = function.call(message) as Stream<R>;
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
      },
    );
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

  Future<IsolateContactor<R, P>> createIsolateContactor() async {
    final (isolateFunctionData, paramsData) = switch (type) {
      SettingsType.futureOr => (
          _defaultIsolateFunction<R, P>,
          this._isolateFunction,
        ),
      SettingsType.futureOrCustom => (
          _isolateFunction as IsolateCustomFunction,
          initialParams,
        ),
      SettingsType.stream => (
          _defaultStreamFunction<R, P>,
          this._isolateFunction,
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
