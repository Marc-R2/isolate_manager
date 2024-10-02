import 'dart:async';

import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager/src/base/isolate_contactor.dart';

class IsolateSettings<R, P> {
  const IsolateSettings({
    required IsolateFunction<R, P> isolateFunction,
    this.converter,
    this.workerConverter,
    this.workerName = '',
    this.isDebug = false,
  })  : _isolateFunction = isolateFunction,
        isCustomIsolate = false,
        initialParams = null;

  const IsolateSettings.custom({
    required IsolateCustomFunction isolateFunction,
    this.converter,
    this.workerConverter,
    this.workerName = '',
    this.initialParams,
    this.isDebug = false,
  })  : _isolateFunction = isolateFunction,
        isCustomIsolate = true;

  /// A default function for using the [IsolateSettings] method.
  static void _defaultIsolateFunction<R, P>(dynamic params) {
    IsolateManagerFunction.customFunction<R, P>(
      params,
      onEvent: (controller, message) {
        final function = controller.initialParams as IsolateFunction<R, P>;
        return function(message);
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
  final bool isCustomIsolate;

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
    final (isolateFunctionData, paramsData) = switch (isCustomIsolate) {
      true => (_isolateFunction as IsolateCustomFunction, initialParams),
      false => (_defaultIsolateFunction<R, P>, this._isolateFunction),
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
