import 'dart:async';

import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager/src/base/isolate_contactor.dart';
import 'package:isolate_manager/src/models/async_concurrent.dart';

abstract class IsolateSettings<R, P> {
  const IsolateSettings({
    required this.isolateFunction,
    this.converter,
    this.workerConverter,
    this.workerName = '',
    this.customAsyncConcurrent,
    this.initialParams,
    this.isDebug = false,
  });

  /// Isolate function.
  final Object isolateFunction;

  /// Name of the `Worker` without the extension.
  ///
  /// Ex: Worker: `worker.js` => workerName: 'worker;
  ///     Worker: `workers/worker.js` => workerName: 'workers/worker'
  final String workerName;

  /// Initial parameters.
  final Object? initialParams;

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

  (void Function(dynamic), Object?) get typedIsolateFunction;

  Future<IsolateContactor<R, P>> createIsolateContactor() async {
    final (isolateFunctionData, paramsData) = typedIsolateFunction;

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

abstract class IsolateSettingsSync<R, P> extends IsolateSettings<R, P> {
  /// TODO: disallow `Future` as return type of [isolateFunction]
  const IsolateSettingsSync({
    required super.isolateFunction,
    super.converter,
    super.workerConverter,
    super.workerName = '',
    super.customAsyncConcurrent = const AsyncConcurrentSingle(),
    super.initialParams,
    super.isDebug = false,
  });
}

abstract class IsolateSettingsAsync<R, P> extends IsolateSettings<R, P> {
  const IsolateSettingsAsync({
    required super.isolateFunction,
    super.converter,
    super.workerConverter,
    super.workerName = '',
    super.customAsyncConcurrent = const AsyncConcurrentSingle(),
    super.initialParams,
    super.isDebug = false,
  });
}

class IsolateSettingsCustom<R, P> extends IsolateSettingsAsync<R, P> {
  const IsolateSettingsCustom({
    required this.isolateFunction,
    super.converter,
    super.workerConverter,
    super.workerName = '',
    super.initialParams,
    super.customAsyncConcurrent,
    super.isDebug = false,
  }) : super(isolateFunction: isolateFunction);

  @override
  final IsolateCustomFunction isolateFunction;

  @override
  (IsolateCustomFunction, Object?) get typedIsolateFunction =>
      (isolateFunction, initialParams);
}
