import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager/src/models/async_concurrent.dart';
import 'package:isolate_manager/src/models/isolate_queue.dart';

class IsolateManagerStream<R, P> extends IsolateManager<R, P> {
  IsolateManagerStream(
    super.settings, {
    super.concurrent,
    super.queueStrategy,
  }) : super.fromSettings();

  Stream<R> stream(
    P params, {
    IsolateCallback<R>? callback,
    bool priority = false,
    AsyncConcurrent? asyncConcurrent,
  }) async* {
    final task = await call(
      params,
      callback: callback,
      priority: priority,
      asyncConcurrent: asyncConcurrent,
    );
    yield* task.stream;
  }

  @override
  Future<StreamTask<R, P>> call(
    P params, {
    IsolateCallback<R>? callback,
    bool priority = false,
    AsyncConcurrent? asyncConcurrent,
  }) async {
    final task = StreamTask(
      params,
      callback,
      settings: settings,
      customAsyncConcurrent: asyncConcurrent,
    );
    await addQueue(task, addToTop: priority);
    return task;
  }
}
