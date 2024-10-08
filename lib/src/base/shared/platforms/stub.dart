import 'dart:async';

import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager/src/base/shared/isolate_params.dart';

/// Execute
Future<R> platformExecuteImpl<R extends Object, P extends Object>({
  required DefaultIsolateManager manager,
  required IsolateFutureOr<R, P> function,
  required P params,
  required String? workerFunction,
  required Object? workerParams,
  required bool priority,
}) async {
  final func = IsolateParamsFunc(function, params);
  return (await manager.compute(func, priority: priority)) as R;
}

/// Create a Worker on Web.
void workerFunctionImpl(Map<String, Function> map) {
  throw UnimplementedError('Only implemented on the Web for the Worker');
}
