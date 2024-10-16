import 'dart:async';

import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager/src/base/contactor/models/isolate_port.dart';

import 'package:isolate_manager/src/base/isolate_contactor.dart';
import 'package:isolate_manager/src/base/shared/isolate_params.dart';
import 'package:isolate_manager/src/models/isolate_queue.dart';

/// Type for the callback of the isolate.
typedef IsolateCallback<R> = FutureOr<bool> Function(R value);

/// Callback for the `createCustom`'s `function`.
typedef IsolateCustomFunction = IsolateFutureOr<void, dynamic>;

typedef Msg<T> = TaskStateUpdate<T>;

typedef IC<R, P> = IsolateContactor<R, P>;

/// Create new [IsolateManager] instance by using [IsolateManager.fromSettings]
abstract class IsolateManager<R, P> {
  /// An easy way to create a new isolate.
  IsolateManager.fromSettings(
    this.settings, {
    QueueStrategy<R, P>? queueStrategy,
    int concurrent = 1,
  })  : queueStrategy = queueStrategy ?? QueueStrategyUnlimited(),
        _concurrent = concurrent {
    // Set the debug log prefix.
    IsolateContactor.debugLogPrefix = debugLogPrefix;
  }

  /*
  /// An easy way to create a new isolate.
  @Deprecated('Use IsolateManager.fromSettings')
  factory IsolateManager.create(
    IsolateFunction<R, P> isolateFunction, {
    String workerName = '',
    int concurrent = 1,
    IsolateConverter<R>? converter,
    IsolateConverter<R>? workerConverter,
    QueueStrategy<R, P>? queueStrategy,
    bool isDebug = false,
  }) =>
      IsolateManagerCompute(
        IsolateSettings<R, P>(
          isolateFunction: isolateFunction,
          converter: converter,
          workerConverter: workerConverter,
          workerName: workerName,
          isDebug: isDebug,
        ),
        queueStrategy: queueStrategy,
        concurrent: concurrent,
      );

  /// Create a new isolate with your own isolate function.
  @Deprecated('Use IsolateManager.fromSettings')
  factory IsolateManager.createCustom(
    IsolateCustomFunction isolateFunction, {
    String workerName = '',
    Object? initialParams,
    int concurrent = 1,
    IsolateConverter<R>? converter,
    IsolateConverter<R>? workerConverter,
    QueueStrategy<R, P>? queueStrategy,
    bool isDebug = false,
  }) =>
      IsolateManagerCompute(
        IsolateSettings<R, P>.custom(
          isolateFunction: isolateFunction,
          converter: converter,
          workerConverter: workerConverter,
          workerName: workerName,
          initialParams: initialParams,
          isDebug: isDebug,
        ),
        queueStrategy: queueStrategy,
        concurrent: concurrent,
      );
   */

  final IsolateSettings<R, P> settings;

  /// Debug logs prefix.
  static String debugLogPrefix = 'Isolate Manager';

  /// Target Number of concurrent isolates.
  int _concurrent;

  /// Get Target Number of concurrent isolates.
  int get concurrent => _concurrent;

  /// Get value as stream.
  Stream<IsolateMessage<R>> get eventStream => _eventStreamController.stream;

  /// Get current number of queues.
  int get queuesLength => queueStrategy.queuesCount;

  /// Strategy to control a new (incoming) computation.
  ///
  /// Basic strategies:
  ///   - [QueueStrategyUnlimited] - default.
  ///   - [QueueStrategyRemoveNewest]
  ///   - [QueueStrategyRemoveOldest]
  ///   - [QueueStrategyDiscardIncoming]
  final QueueStrategy<R, P> queueStrategy;

  /// If you want to call the [start] method manually without `await`, you can `await`
  /// later by using [ensureStarted] to ensure that all the isolates are started.
  Future<void> get ensureStarted => _startedCompleter.future;

  /// To check if the [start] method is completed or not.
  bool get isStarted => _startedCompleter.isCompleted;

  /// Create multiple long live isolates for computation. This method can be used
  /// to compute multiple functions.
  ///
  /// [concurrent] is a number of isolates that you want to create.
  ///
  /// Set [useWorker] to `true` if you want to use the Worker on the Web.
  ///
  /// [workerConverter] is a converter for the worker, the data from the worker
  /// will be directly sent to this method to convert to the result format that
  /// you want to.
  ///
  /// Predefine the mapping between a function and a name of worker function
  /// using the [workerMappings], so we can ignore the `workerName` parameter
  /// when we compute a function multiple times.
  ///
  /// Set [autoStart] to `false` if you want to call the `start()` method manually.
  ///
  /// If the generated Worker is put inside a folder (such as `workers`), the [subPath]
  /// needs to be set to `workers`.
  ///
  /// Control the Queue strategy via [queueStrategy] with the following basic
  /// strategies:
  ///   - [QueueStrategyUnlimited] - default.
  ///   - [QueueStrategyRemoveNewest]
  ///   - [QueueStrategyRemoveOldest]
  ///   - [QueueStrategyDiscardIncoming]
  ///
  /// Set [isDebug] to `true` if you want to print the debug log.
  static IsolateManagerShared createShared({
    int concurrent = 1,
    bool useWorker = false,
    Object Function(dynamic)? workerConverter,
    Map<Function, String> workerMappings = const {},
    bool autoStart = true,
    String subPath = '',
    int maxQueueCount = 0,
    QueueStrategy<Object, IsolateParamsFunc<Object, dynamic>>? queueStrategy,
    bool isDebug = false,
  }) =>
      IsolateManagerShared(
        concurrent: concurrent,
        useWorker: useWorker,
        workerConverter: workerConverter,
        workerMappings: workerMappings,
        autoStart: autoStart,
        subPath: subPath,
        queueStrategy: queueStrategy,
        isDebug: isDebug,
      );

  final _activeTasks = <int, IsolateQueue<R, P>>{};

  /// Map<IsolateContactor instance, isBusy>.
  final Map<IC<R, P>, List<IsolateQueue<R, P>>> _isolates = {};

  List<IsolateQueue<R, P>> _getIsolateJobs(IC<R, P> isolate) =>
      _isolates[isolate]!;

  void _addJob(IC<R, P> isolate, IsolateQueue<R, P> job) =>
      _getIsolateJobs(isolate).add(job);

  bool _removeJob(IsolateQueue<R, P> job) {
    _activeTasks.remove(job.id);
    for (final isolate in _isolates.keys) {
      if (_getIsolateJobs(isolate).remove(job)) return true;
    }
    return false;
  }

  /// Controller for stream.
  final StreamController<IsolateMessage<R>> _eventStreamController =
      StreamController.broadcast();

  StreamSubscription<IsolateMessage<R>>? _streamSubscription;

  // final List<StreamSubscription<R>> _streamSubscriptions = [];

  /// Is the `start` method is starting.
  bool _isStarting = false;

  /// Control when the `start` method is completed.
  Completer<void> _startedCompleter = Completer();

  /// Initialize the instance. This method can be called manually or will be
  /// called when the first `compute()` has been made.
  Future<void> start() async {
    // This instance is stopped.
    if (_eventStreamController.isClosed) return;

    // Return here if this method is already completed.
    if (_startedCompleter.isCompleted) return;

    // If this method has already been called, it will wait for completion.
    if (_isStarting) return _startedCompleter.future;

    // Mark as the `start()` is starting.
    _isStarting = true;

    final scaling = scale(concurrent);

    _streamSubscription = _eventStreamController.stream.listen(onData)
      // Needs to put onError here to make the try-catch work properly.
      ..onError(onError);

    await scaling;
    _executeQueue();

    // Mark the `start()` to be completed.
    _startedCompleter.complete();
  }

  /// Scale the number of isolates.
  Future<void> scale(int count) async {
    assert(count > 0, 'The number of isolates must be greater than 0.');
    _concurrent = count;
    final waiting = <Future<void>>[];

    if (concurrent > _isolates.length) {
      for (var i = 0; i < concurrent - _isolates.length; i++) {
        final isolate = settings.createIsolateContactor();
        waiting.add(
          isolate.then((value) {
            late final StreamSubscription<IsolateMessage<R>> sub;
            sub = value.onMessage.listen(
              _eventStreamController.add,
              onError: _eventStreamController.addError,
              onDone: () {
                sub.cancel();
                _isolates.remove(value);
              },
            );
            _isolates.addAll({value: []});
          }),
        );
      }
    } else {
      for (var i = 0; i < _isolates.length - concurrent; i++) {
        final isolate = _isolates.keys.last;
        _isolates.remove(isolate);
        waiting.add(isolate.dispose());
      }
    }
    await Future.wait(waiting);
  }

  /// Stop isolate manager without close streamController.
  Future<void> _tempStop() async {
    _isStarting = false;
    _startedCompleter = Completer();
    queueStrategy.clear();
    await Future.wait(
      [for (final isolate in _isolates.keys) isolate.dispose()],
    );
    _isolates.clear();
    await _streamSubscription?.cancel();
  }

  /// Stop the isolate.
  Future<void> stop() async {
    await _tempStop();
    await _eventStreamController.close();
  }

  /// Restart the isolate.
  Future<void> restart() async {
    await _tempStop();
    await start();
  }

  /// Compute isolate manager with [R] is return type.
  ///
  /// You can use [callback] to be able to receive many values before receiving
  /// the final result that is returned from the [call] method. The final
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
  /// final result = await isolate(params); // Get only the first result from the isolate
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
  Future<IsolateQueue<R, P>> call(
    P params, {
    IsolateCallback<R>? callback,
    bool priority = false,
  });

  Future<void> addQueue(
    IsolateQueue<R, P> queue, {
    bool addToTop = false,
  }) async {
    await start();
    queueStrategy.add(queue, addToTop: addToTop);
    _executeQueue();
  }

  /// Execute the element in the queues.
  void _executeQueue() {
    printDebug(() => 'Number of queues: ${queueStrategy.queuesCount}');
    for (final isolate in _isolates.keys) {
      /// Allow calling `compute` before `start`.
      if (queueStrategy.hasNext() && _canRunJob(isolate, queueStrategy.next)) {
        final queue = queueStrategy.getNext();
        _execute(isolate, queue);
      }
    }
  }

  bool _canRunJob(IC<R, P> isolate, IsolateQueue<R, P>? next) {
    final running = _getIsolateJobs(isolate);
    return (next?.canRun(running) ?? false) &&
        running.every((e) => e.asyncConcurrent.canRun(running));
  }

  /// Send [task] to the [isolate].
  Future<void> _execute(IC<R, P> isolate, IsolateQueue<R, P> task) async {
    assert(!_activeTasks.containsKey(task.id), 'Task already exists');
    _activeTasks[task.id] = task;

    try {
      // Assing the task to the isolate.
      _addJob(isolate, task);
      final msg = TaskData(task.id, task.params);
      await isolate.sendMessage(msg);
    } catch (_, __) {
      /* Do not need to catch the Exception here because it's catched in the above Stream */
    }
  }

  IsolateQueue<R, P> getTask(int id) {
    final task = _activeTasks[id];
    if (task != null) return task;
    throw ArgumentError('Task not found: $id');
  }

  Future<void> onData(IsolateMessage<R> event) async {
    final task = getTask(event.id);

    if (event is TaskData<R>) {
      await _onData(task, event);
    } else if (event is TaskControl<R>) {
      await _onControl(task, event);
    }
  }

  Future<void> _onData(IsolateQueue<R, P> task, TaskData<R> event) async {
    final callbackResult = await task.callCallback(event.value);
    if (!callbackResult) return;

    if (task is ComputeTask<R, P>) {
      task.complete(event.value);
    } else if (task is StreamTask<R, P>) {
      task.add(event.value);
    }
  }

  Future<void> _onControl(IsolateQueue<R, P> task, TaskControl<R> event) async {
    final control = event.state;
    task.state = control;
    if (control == TaskState.done || control == TaskState.error) {
      if (task is StreamTask<R, P>) await task.close();

      _removeJob(task);
      _executeQueue();
    }
  }

  void onError(Object error, StackTrace stack) {
    if (error is IsolateException) {
      final task = getTask(error.id);

      if (task is ComputeTask<R, P>) {
        task.completeError(error.error, stack);
      } else if (task is StreamTask<R, P>) {
        task.addError(error.error, stack);
      }
    }
  }

  /// Print logs if _settings.isDebug_ is true
  void printDebug(Object? Function() object) {
    if (settings.isDebug) {
      print('[$debugLogPrefix]: ${object()}');
    }
  }
}
