import 'dart:async';

import 'package:isolate_manager/src/models/queue_strategy.dart';

import 'base/isolate_contactor.dart';
import 'base/isolate_manager_shared.dart';
import 'isolate_manager_function.dart';
import 'models/isolate_queue.dart';

/// Type for the callback of the isolate.
typedef IsolateCallback<R> = FutureOr<bool> Function(R value);

/// Callback for the `createCustom`'s `function`.
typedef IsolateCustomFunction = IsolateFunction<void, dynamic>;

/// Create a new [IsolateManager] instance by using [IsolateManager.create] or
/// [IsolateManager.createCustom].
class IsolateManager<R, P> {
  /// Debug logs prefix.
  static String debugLogPrefix = 'Isolate Manager';

  /// Target Number of concurrent isolates.
  int _concurrent;

  /// Get Target Number of concurrent isolates.
  int get concurrent => _concurrent;

  /// Isolate function.
  final Object isolateFunction;

  /// Name of the `Worker` without the extension.
  ///
  /// Ex: Worker: `worker.js` => workerName: 'worker;
  ///     Worker: `workers/worker.js` => workerName: 'workers/worker'
  final String workerName;

  /// Initial parameters.
  final Object? initialParams;

  /// Is using your own isolate function.
  final bool isCustomIsolate;

  /// Allow print debug log.
  final bool isDebug;

  /// Get value as stream.
  Stream<R> get eventStream => _eventStreamController.stream;

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

  /// An easy way to create a new isolate.
  IsolateManager.create(
    IsolateFunction<R, P> this.isolateFunction, {
    this.workerName = '',
    int concurrent = 1,
    this.converter,
    this.workerConverter,
    QueueStrategy<R, P>? queueStrategy,
    this.isDebug = false,
  })  : isCustomIsolate = false,
        initialParams = '',
        _concurrent = concurrent,
        queueStrategy = queueStrategy ?? QueueStrategyUnlimited() {
    // Set the debug log prefix.
    IsolateContactor.debugLogPrefix = debugLogPrefix;
  }

  /// Create a new isolate with your own isolate function.
  IsolateManager.createCustom(
    IsolateCustomFunction this.isolateFunction, {
    this.workerName = '',
    this.initialParams,
    int concurrent = 1,
    this.converter,
    this.workerConverter,
    QueueStrategy<R, P>? queueStrategy,
    this.isDebug = false,
  })  : isCustomIsolate = true,
        _concurrent = concurrent,
        queueStrategy = queueStrategy ?? QueueStrategyUnlimited() {
    // Set the debug log prefix.
    IsolateContactor.debugLogPrefix = debugLogPrefix;
  }

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
    QueueStrategy<Object, List<Object>>? queueStrategy,
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

  /// A default function for using the [IsolateManager.create] method.
  static void _defaultIsolateFunction<R, P>(dynamic params) {
    IsolateManagerFunction.customFunction<R, P>(params,
        onEvent: (controller, message) {
      final function = controller.initialParams;
      return function(message);
    });
  }

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
      _excuteQueue();
    })
      // Needs to put onError here to make the try-catch work properly.
      ..onError((error, stack) {});

    await scaling;
    _excuteQueue();

    // Mark the `start()` to be completed.
    _startedCompleter.complete();
  }

  /// Scale the number of isolates.
  Future<void> scale(int count) async {
    assert(count > 0, 'The number of isolates must be greater than 0.');
    _concurrent = count;
    if (concurrent > _isolates.length) {
      final (isolateFunctionData, paramsData) = switch (isCustomIsolate) {
        true => (isolateFunction as IsolateCustomFunction, initialParams),
        false => (_defaultIsolateFunction<R, P>, this.isolateFunction),
      };

      final waiting = <Future<IsolateContactor>>[];

      for (int i = 0; i < concurrent - _isolates.length; i++) {
        final isolate = IsolateContactor.createCustom<R, P>(
          isolateFunctionData,
          workerName: workerName,
          initialParams: paramsData,
          converter: converter,
          workerConverter: workerConverter,
          debugMode: isDebug,
        );
        waiting.add(isolate);
        isolate.then((value) => _isolates.addAll({value: false}));
      }

      await Future.wait(waiting);
    } else {
      for (int i = 0; i < _isolates.length - concurrent; i++) {
        final isolate = _isolates.keys.last;
        _isolates.remove(isolate);
        await isolate.dispose();
      }
    }
  }

  /// Stop isolate manager without close streamController.
  Future<void> _tempStop() async {
    _isStarting = false;
    _startedCompleter = Completer();
    queueStrategy.clear();
    await Future.wait(
        [for (IsolateContactor isolate in _isolates.keys) isolate.dispose()]);
    _isolates.clear();
    _streamSubscription?.cancel();
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
  Future<R> call(P params,
          {IsolateCallback<R>? callback, bool priority = false}) =>
      compute(params, callback: callback, priority: priority);

  ///  Similar to the [compute], for who's using IsolateContactor.
  Future<R> sendMessage(P params,
          {IsolateCallback<R>? callback, bool priority = false}) =>
      compute(params, callback: callback, priority: priority);

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
    await start();

    final queue = ComputeTask<R, P>(params, callback);
    queueStrategy.add(queue, addToTop: priority);
    _excuteQueue();

    return queue.completer.future;
  }

  Stream<R> stream(P params, {IsolateCallback<R>? callback}) {
    final queue = StreamTask<R, P>(params, callback);
    queueStrategy.add(queue);
    _excuteQueue();

    return queue.stream;
  }

  /// Exccute the element in the queues.
  void _excuteQueue() {
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
    throw UnimplementedError();
  }

  Future<R> _executeCompute(
    IsolateContactor<R, P> isolate,
    ComputeTask<R, P> queue,
  ) async {
    // Mark the current isolate as busy.
    _isolates[isolate] = true;

    StreamSubscription? sub;
    sub = isolate.onMessage.listen((event) async {
      if (await queue.callCallback(event)) {
        sub?.cancel();
        // Mark the current isolate as free.
        _isolates[isolate] = false;
        // Send the result back to the main app.
        _eventStreamController.sink.add(event);
        queue.completer.complete(event);
      }
    }, onError: (error, stackTrace) {
      sub?.cancel();
      // Mark the current isolate as free.
      _isolates[isolate] = false;

      // Send the exception back to the main app.
      _eventStreamController.sink.addError(error!, stackTrace);
      queue.completer.completeError(error, stackTrace);
    });

    try {
      await isolate.sendMessage(queue.params);
    } catch (_, __) {
      /* Do not need to catch the Exception here because it's catched in the above Stream */
    }

    return queue.completer.future;
  }

  /// Print logs if [isDebug] is true
  void printDebug(Object? Function() object) {
    if (isDebug) {
      print('[$debugLogPrefix]: ${object()}');
    }
  }
}
