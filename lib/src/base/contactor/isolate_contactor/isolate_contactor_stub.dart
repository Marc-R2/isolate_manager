import 'dart:async';
import 'dart:isolate';

import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager/src/base/contactor/isolate_contactor.dart';
import 'package:isolate_manager/src/base/contactor/isolate_contactor_controller/isolate_contactor_controller_stub.dart';
import 'package:isolate_manager/src/base/contactor/models/isolate_port.dart';
import 'package:isolate_manager/src/base/contactor/models/isolate_state.dart';

class IsolateContactorInternal<R, P> extends IsolateContactor<R, P> {
  /// Internal instance
  IsolateContactorInternal._({
    required CustomIsolateFunction isolateFunction,
    required dynamic isolateParam,
    required String workerName,
    required IsolateConverter<R> converter,
    required IsolateConverter<R> workerConverter,
    required ReceivePort receivePort,
    super.debugMode = false,
  })  : _isolateFunction = isolateFunction,
        _workerName = workerName,
        _isolateParam = isolateParam,
        _receivePort = receivePort,
        _isolateContactorController = IsolateContactorControllerImpl(
          receivePort,
          converter: converter,
          workerConverter: workerConverter,
          onDispose: null,
        );

  /// Create receive port
  final ReceivePort _receivePort;

  /// Create isolate channel
  final IsolateContactorControllerImpl<R, P> _isolateContactorController;

  /// Create isolate
  Isolate? _isolate;

  /// Check for current computing state in enum with listener
  final StreamController<IsolateMessage<R>> _mainStreamController =
      StreamController.broadcast();

  /// Control the function of isolate
  final void Function(dynamic) _isolateFunction;

  /// Control the parameters of isolate
  final Object? _isolateParam;

  /// Only for web platform
  // ignore: unused_field
  final String _workerName;

  /// Create an instance with your own function
  static Future<IsolateContactorInternal<R, P>> createCustom<R, P>({
    required CustomIsolateFunction isolateFunction,
    required Object? initialParams,
    required String workerName,
    required IsolateConverter<R> converter,
    required IsolateConverter<R> workerConverter,
    bool debugMode = false,
  }) async {
    final isolateContactor = IsolateContactorInternal<R, P>._(
      isolateFunction: isolateFunction,
      workerName: workerName,
      isolateParam: initialParams,
      converter: converter,
      workerConverter: workerConverter,
      debugMode: debugMode,
      receivePort: ReceivePort(),
    );

    await isolateContactor._initial();

    return isolateContactor;
  }

  /// Initialize
  Future<void> _initial() async {
    _isolateContactorController.onMessage.listen((message) {
      printDebug(() => 'Message received from Isolate: $message');
      _mainStreamController.sink.add(message);
    }).onError((Object err, StackTrace? stack) {
      printDebug(() => 'Error message received from Isolate: $err');
      _mainStreamController.sink.addError(err, stack);
    });

    _isolate = await Isolate.spawn(
      _isolateFunction,
      [_isolateParam, _receivePort.sendPort],
    );

    await _isolateContactorController.ensureInitialized.future;
    printDebug(() => 'Initialized');
  }

  Future<void> _dispose() async {
    _isolateContactorController.sendIsolateState(IsolateState.dispose);
    await _isolateContactorController.close();
    _receivePort.close();
    _isolate!.kill();
    _isolate = null;
  }

  /// Get current message as stream
  @override
  Stream<Msg<R>> get onMessage => _mainStreamController.stream;

  /// Dispose current [Isolate]
  @override
  Future<void> dispose() async {
    await _dispose();
    await _mainStreamController.close();
    printDebug(() => 'Disposed');
  }

  /// Send message to child isolate [function]
  ///
  /// Throw IsolateContactorException if error occurs.
  @override
  Future<R> sendMessage(Msg<P> message) async {
    final completer = Completer<R>();
    late final StreamSubscription<Msg<R>> sub;
    sub = _isolateContactorController.onMessage.listen((result) async {
      if (!completer.isCompleted) {
        completer.complete(result.value);
        await sub.cancel();
      }
    })
      ..onError((Object err, StackTrace? stack) async {
        completer.completeError(err, stack);
        await sub.cancel();
      });

    printDebug(() => 'Message send to isolate: $message');

    _isolateContactorController.sendIsolate(message);

    return completer.future;
  }
}
