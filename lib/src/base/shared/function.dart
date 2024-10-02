import 'dart:async';

import 'package:isolate_manager/isolate_manager.dart';

import 'package:isolate_manager/src/base/shared/platforms/web.dart'
    if (dart.library.io) 'package:isolate_manager/src/base/shared/platforms/stub.dart';

// typedef IsolateParams = (dynamic Function(dynamic), dynamic);

abstract class IsolateParams<R, P> {
  const IsolateParams(this.funcRaw, this.params);

  final dynamic funcRaw;
  final P params;
}

class IsolateParamsFunc<R, P> extends IsolateParams<R, P> {
  const IsolateParamsFunc(IsolateFunction<R, P> super.func, super.params);

  dynamic Function(P) get func => funcRaw as dynamic Function(P);

  dynamic call() => func(params);
}

class IsolateParamsRef<R, P> extends IsolateParams<R, P> {
  const IsolateParamsRef(super.func, super.params);

  String get func => funcRaw as String;
}

/// Internal function
Future<Object> internalFunction(IsolateParamsFunc<Object, dynamic> params) {
  // assert(params is List, 'params is not a list');
  // assert(params.length == 2, 'params must have only 2 elements');
  // assert(params[0] is Function, 'params[0] is not a Function');

  final completer = Completer<Object>()..complete(params.call());
  return completer.future;
}

/// Internal platform execute
Future<R> platformExecute<R extends Object, P extends Object>({
  required IsolateManager<Object, IsolateParams<Object, dynamic>> manager,
  required FutureOr<R> Function(P) function,
  required P params,
  required String? workerFunction,
  required Object? workerParams,
  required bool priority,
}) async {
  return platformExecuteImpl<R, P>(
    manager: manager,
    function: function,
    params: params,
    workerFunction: workerFunction,
    workerParams: workerParams,
    priority: priority,
  );
}

/// Internal shared Worker function
void sharedWorkerFunctionImpl(Map<String, Function> map) {
  return workerFunctionImpl(map);
}
