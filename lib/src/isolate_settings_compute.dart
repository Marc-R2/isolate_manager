import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager/src/base/isolate_contactor.dart';

dynamic Function(P) _function<R, P>(dynamic params) {
  if (params is IsolateFunctionFuture<R, P>) {
    return params;
  }
  throw ArgumentError('Invalid function type: ${params.runtimeType}');
}

/// A default function for using the [IsolateSettings] method.
void _defaultIsolateFunction<R, P>(dynamic params) {
  IsolateManagerFunction.customFunction<R, P>(
    params,
    onEvent: (controller, message) {
      final function = _function<R, P>(controller.initialParams);
      assert(function is IsolateFunctionFuture<R, P>, 'Invalid function type');
      return function.call(message);
    },
  );
}

class IsolateSettingsObject<R, P> extends IsolateSettingsSync<R, P> {
  const IsolateSettingsObject({
    required this.isolateFunction,
    super.converter,
    super.workerConverter,
    super.workerName = '',
    super.customAsyncConcurrent,
    super.isDebug = false,
  }) : super(isolateFunction: isolateFunction);

  @override
  final IsolateFunctionObject<R, P> isolateFunction;

  @override
  (void Function(dynamic), Object?) get typedIsolateFunction =>
      (_defaultIsolateFunction<R, P>, isolateFunction);
}

class IsolateSettingsFuture<R, P> extends IsolateSettingsAsync<R, P> {
  const IsolateSettingsFuture({
    required this.isolateFunction,
    super.converter,
    super.workerConverter,
    super.workerName = '',
    super.customAsyncConcurrent,
    super.isDebug = false,
  }) : super(isolateFunction: isolateFunction);

  @override
  final IsolateFunctionFuture<R, P> isolateFunction;

  @override
  (void Function(dynamic), Object?) get typedIsolateFunction =>
      (_defaultIsolateFunction<R, P>, isolateFunction);
}
