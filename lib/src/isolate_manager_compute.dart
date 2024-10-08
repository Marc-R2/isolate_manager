import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager/src/models/async_concurrent.dart';
import 'package:isolate_manager/src/models/isolate_queue.dart';

class IsolateManagerCompute<R, P> extends IsolateManager<R, P> {
  IsolateManagerCompute(
    super.settings, {
    super.concurrent,
    super.queueStrategy,
  }) : super.fromSettings();

  /// Compute isolate manager with [R] is return type.
  ///
  /// You can use [callback] to be able to receive many values before receiving
  /// the final result that is returned from the [compute] method. The final
  /// result will be returned when the callback returns `true`. If you want a
  /// computation runs as soon as possible, you can set the [priority] to `true`
  /// to promote it to the top of the Queue.
  ///
  /// Ex:
  ///
  /// Without callback, the first value received from the Isolate is always the
  /// final value:
  ///
  /// ```dart
  /// final result = await isolate.compute(params); // Get only the first result from the isolate
  /// ```
  ///
  /// With callback, only the `true` value is the final value, so all other values
  /// is marked as the progress values:
  ///
  /// ``` dart
  /// final result = await isolate.compute(params, (value) {
  ///       if (value is int) {
  ///         // Do something here with the value that will be not returned to the `result`.
  ///         print('progress: $value');
  ///         return false;
  ///       }
  ///
  ///       // The value is not `int` and will be returned to the `result` as the final result.
  ///       return true;
  ///  });
  /// ```
  Future<R> compute(
    P params, {
    IsolateCallback<R>? callback,
    bool priority = false,
  }) async {
    final task = await call(params, callback: callback, priority: priority);
    return task.future;
  }

  @override
  Future<ComputeTask<R, P>> call(
    P params, {
    IsolateCallback<R>? callback,
    bool priority = false,
    AsyncConcurrent? asyncConcurrent,
  }) async {
    final task = ComputeTask<R, P>(
      params,
      callback,
      type: settings.type,
      customAsyncConcurrent: asyncConcurrent ?? settings.customAsyncConcurrent,
    );
    await addQueue(task, addToTop: priority);
    return task;
  }
}
