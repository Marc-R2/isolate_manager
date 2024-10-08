import 'dart:async';

import 'package:isolate_manager/isolate_manager.dart';

import 'package:isolate_manager/src/base/shared/function.dart';
import 'package:isolate_manager/src/base/shared/isolate_params.dart';

/// Web platform does not need to use the `function`
Future<R> platformExecuteImpl<R extends Object, P extends Object>({
  required DefaultIsolateManager manager,
  required IsolateFutureOr<R, P> function,
  required P params,
  required String? workerFunction,
  required Object? workerParams,
  required bool priority,
}) async {
  final isWorker = manager.settings.workerName != '';
  final isDebug = manager.settings.isDebug;
  if (isDebug && isWorker && workerFunction == null) {
    print('[Isolate Manager] Worker is available but `workerFunction` is null, '
        'so `Future` will be used instead');
  }

  final finalParams = (workerParams ?? params) as P;

  // ignore: omit_local_variable_types
  final IsolateParams<R, P> func = (isWorker && workerFunction != null)
      ? IsolateParamsRef<R, P>(workerFunction, finalParams)
      : IsolateParamsFunc<R, P>(function, finalParams);

  return (await manager.compute(func, priority: priority)) as R;
}

/// Create a Worker on Web.
void workerFunctionImpl(Map<String, Function> map) {
  IsolateManagerFunction.workerFunction(
      (IsolateParamsRef<dynamic, dynamic> message) {
    final func = map[message.func]! as Object Function(dynamic);
    return internalFunction(IsolateParamsFunc(func, message.params));
  });
}
