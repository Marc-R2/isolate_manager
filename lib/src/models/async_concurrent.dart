import 'package:isolate_manager/src/models/isolate_queue.dart';

typedef Task = IsolateQueue<dynamic, dynamic>;

typedef TaskList = List<Task>;

/// Set the maximum number of concurrent tasks running in the same isolate.
///
/// Some tasks may be able to take advantage of concurrency
/// because they spend most of their time waiting anyway.
/// e.g. tasks that are I/O bound.
///
/// With the introduction of Streams this becomes even more important.
/// So one isolate can potentially handle multiple streams.
abstract class AsyncConcurrent {
  const AsyncConcurrent(this._isCompatible);

  final bool Function(Task) _isCompatible;

  bool canRun(TaskList running) {
    return running.every(_isCompatible);
  }
}

class AsyncConcurrentSingle extends AsyncConcurrent {
  const AsyncConcurrentSingle() : super(singleCheck);

  static bool singleCheck(Task _) => false;
}

class AsyncConcurrentUnlimited extends AsyncConcurrent {
  const AsyncConcurrentUnlimited() : super(unlimitedCheck);

  static bool unlimitedCheck(Task _) => true;
}

class AsyncConcurrentOtherAsync extends AsyncConcurrent {
  const AsyncConcurrentOtherAsync() : super(otherAsyncCheck);

  static bool otherAsyncCheck(Task t1) => t1.type?.isAsync ?? false;
}
