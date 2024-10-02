import 'dart:async';

import 'package:isolate_manager/src/base/contactor/isolate_contactor/isolate_contactor_web.dart';
import 'package:isolate_manager/src/base/contactor/isolate_contactor_controller/isolate_contactor_controller_web.dart';
import 'package:isolate_manager/src/base/isolate_contactor.dart';

class IsolateContactorInternalFuture<R, P>
    extends IsolateContactorInternal<R, P> {
  /// Create an instance
  IsolateContactorInternalFuture._({
    required CustomIsolateFunction isolateFunction,
    required String workerName,
    required Object? isolateParam,
    required IsolateConverter<R> converter,
    required IsolateConverter<R> workerConverter,
    bool debugMode = false,
  })  : _isolateFunction = isolateFunction,
        _workerName = workerName,
        _isolateParam = isolateParam,
        _isolateContactorController = IsolateContactorControllerImpl(
          StreamController.broadcast(),
          converter: converter,
          workerConverter: workerConverter,
          onDispose: null,
        ),
        super(debugMode);

  /// Check for current cumputing state in enum with listener
  final StreamController<R> _mainStreamController =
      StreamController.broadcast();

  /// Listener for result
  final IsolateContactorController<R, P>? _isolateContactorController;

  /// Control the function of isolate
  final void Function(dynamic) _isolateFunction;

  /// Control the parameters of isolate
  final dynamic _isolateParam;

  // ignore: unused_field
  final String _workerName;

  /// Create modified isolate function
  static Future<IsolateContactorInternalFuture<R, P>> createCustom<R, P>({
    required CustomIsolateFunction isolateFunction,
    required String isolateFunctionName,
    required dynamic initialParams,
    required IsolateConverter<R> converter,
    required IsolateConverter<R> workerConverter,
    bool debugMode = false,
  }) async {
    final isolateContactor = IsolateContactorInternalFuture<R, P>._(
      isolateFunction: isolateFunction,
      workerName: isolateFunctionName,
      isolateParam: initialParams ?? [],
      converter: converter,
      workerConverter: workerConverter,
      debugMode: debugMode,
    );

    await isolateContactor._initial();

    return isolateContactor;
  }

  /// Initialize
  Future<void> _initial() async {
    _isolateContactorController!.onMessage.listen((message) {
      printDebug(
        () => '[Main Stream] Message received from Future: $message',
      );
      _mainStreamController.sink.add(message);
    }).onError((err, stack) {
      printDebug(
        () => '[Main Stream] Error message received from Future: $err',
      );
      _mainStreamController.sink.addError(err as Object, stack as StackTrace?);
    });

    _isolateFunction([_isolateParam, _isolateContactorController]);

    await _isolateContactorController.ensureInitialized.future;

    printDebug(() => 'Initialized');
  }

  /// Get current message as stream
  @override
  Stream<R> get onMessage => _mainStreamController.stream;

  /// Dispose current [Isolate]
  @override
  Future<void> dispose() async {
    _isolateContactorController?.sendIsolateState(IsolateState.dispose);

    await _isolateContactorController?.close();
    await _mainStreamController.close();

    printDebug(() => 'Disposed');
  }

  /// Send message to child isolate [function].
  ///
  /// Throw IsolateContactorException if error occurs.
  @override
  Future<R> sendMessage(P message) {
    if (_isolateContactorController == null) {
      printDebug(() => '! This isolate has been terminated');
      return throw const IsolateException('This isolate was terminated');
    }

    final completer = Completer<R>();
    late final StreamSubscription<R> sub;
    sub = _isolateContactorController.onMessage.listen((result) async {
      if (!completer.isCompleted) {
        completer.complete(result);
        await sub.cancel();
      }
    })
      ..onError((err, stack) async {
        completer.completeError(err as Object, stack as StackTrace?);
        await sub.cancel();
      });

    printDebug(() => 'Message send to isolate: $message');

    _isolateContactorController.sendIsolate(message);

    return completer.future;
  }
}
