import 'dart:async';

import 'package:isolate_manager/isolate_manager.dart';

import 'package:isolate_manager/src/base/isolate_contactor.dart';
import 'package:isolate_manager/src/base/shared/isolate_params.dart';
import 'package:isolate_manager/src/models/isolate_queue.dart';

/// Type for the callback of the isolate.
typedef IsolateCallback<R> = FutureOr<bool> Function(R value);

/// Callback for the `createCustom`'s `function`.
typedef IsolateCustomFunction = IsolateFunction<void, dynamic>;

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

  final IsolateSettings<R, P> settings;

  /// Debug logs prefix.
  static String debugLogPrefix = 'Isolate Manager';

  /// Target Number of concurrent isolates.
  int _concurrent;

  /// Get Target Number of concurrent isolates.
  int get concurrent => _concurrent;

  /// Get value as stream.
  Stream<R> get eventStream => _eventStreamController.stream;

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

  /// Map<IsolateContactor instance, isBusy>.
  final Map<IsolateContactor<R, P>, bool> _isolates = {};

  /// Controller for stream.
  final StreamController<R> _eventStreamController =
      StreamController.broadcast();
  StreamSubscription<R>? _streamSubscription;

  // final List<StreamSubscription<R>> _streamSubscriptions = [];

  /// Is the `start` method is starting.
  bool _isStarting = false;

  /// Control when the `start` method is completed.
  Completer<void> _startedCompleter = Completer();

  /// Initialize the instance. This method can be called manually or will be
  /// called when the first `compute()` has been made.
  Future<void> start() async {
    // This instance is stoped.
    if (_eventStreamController.isClosed) return;

    // Return here if this method is already completed.
    if (_startedCompleter.isCompleted) return;

    // If this method has already been called, it will wait for completion.
    if (_isStarting) return _startedCompleter.future;

    // Mark as the `start()` is starting.
    _isStarting = true;

    final scaling = scale(concurrent);

    _streamSubscription = _eventStreamController.stream.listen((result) {
      _executeQueue();
    })
      // Needs to put onError here to make the try-catch work properly.
      ..onError((error, stack) {});

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
        waiting.add(isolate.then((value) => _isolates.addAll({value: false})));
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
      if (queueStrategy.hasNext() && _isolates[isolate] == false) {
        final queue = queueStrategy.getNext();
        _execute(isolate, queue);
      }
    }
  }

  /// Send and recieve value.
  Future<R> _execute(IsolateContactor<R, P> isolate, IsolateQueue<R, P> queue) {
    if (queue is ComputeTask<R, P>) return _executeCompute(isolate, queue);
    if (queue is StreamTask<R, P>) return _executeStream(isolate, queue);
    throw UnimplementedError();
  }

  /// Execute the stream.
  Future<R> _executeStream(
    IsolateContactor<R, P> isolate,
    StreamTask<R, P> queue,
  ) async {
    // Mark the current isolate as busy.
    _isolates[isolate] = true;

    late final StreamSubscription<R> sub;

    void endStream() {
      sub.cancel();
      // Mark the current isolate as free.
      _isolates[isolate] = false;
      // Send the result back to the main app.
      queue.controller.close();
    }

    sub = isolate.onMessage.listen(
      (event) async {
        if (!await queue.callCallback(event)) return;
        // Send the result back to the main app.
        queue.controller.sink.add(event);
      },
      onError: (Object err, StackTrace? stack) {
        // Send the exception back to the main app.
        queue.controller.sink.addError(err, stack);
        endStream();
      },
    );

    try {
      await isolate.sendMessage(queue.params);
    } catch (_, __) {
      /* Do not need to catch the Exception here because it's catched in the above Stream */
    }

    return queue.stream.last;
  }

  Future<R> _executeCompute(
    IsolateContactor<R, P> isolate,
    ComputeTask<R, P> queue,
  ) async {
    // Mark the current isolate as busy.
    _isolates[isolate] = true;

    late final StreamSubscription<R> sub;
    sub = isolate.onMessage.listen(
      (event) async {
        if (await queue.callCallback(event)) {
          await sub.cancel();
          // Mark the current isolate as free.
          _isolates[isolate] = false;
          // Send the result back to the main app.
          _eventStreamController.sink.add(event);
          queue.completer.complete(event);
        }
      },
      onError: (Object err, StackTrace? stack) {
        sub.cancel();
        // Mark the current isolate as free.
        _isolates[isolate] = false;

        // Send the exception back to the main app.
        _eventStreamController.sink.addError(err, stack);
        queue.completer.completeError(err, stack);
      },
    );

    try {
      await isolate.sendMessage(queue.params);
    } catch (_, __) {
      /* Do not need to catch the Exception here because it's catched in the above Stream */
    }

    return queue.completer.future;
  }

  /// Print logs if _settings.isDebug_ is true
  void printDebug(Object? Function() object) {
    if (settings.isDebug) {
      print('[$debugLogPrefix]: ${object()}');
    }
  }
}
