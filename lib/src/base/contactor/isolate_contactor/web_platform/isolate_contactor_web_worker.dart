import 'dart:async';
import 'dart:isolate';

import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager/src/base/contactor/isolate_contactor.dart';
import 'package:isolate_manager/src/base/contactor/isolate_contactor/isolate_contactor_web.dart';
import 'package:isolate_manager/src/base/contactor/isolate_contactor_controller.dart';
import 'package:isolate_manager/src/base/contactor/isolate_contactor_controller/isolate_contactor_controller_web.dart';
import 'package:isolate_manager/src/base/contactor/models/isolate_port.dart';
import 'package:web/web.dart';

class IsolateContactorInternalWorker<R, P>
    extends IsolateContactorInternal<R, P> {
  /// Create an instance
  IsolateContactorInternalWorker._({
    required CustomIsolateFunction isolateFunction,
    required Object? isolateParam,
    required String workerName,
    required IsolateConverter<R> converter,
    required IsolateConverter<R> workerConverter,
    super.debugMode = false,
  })  : _isolateFunction = isolateFunction,
        _isolateParam = isolateParam,
        _isolateContactorController = IsolateContactorControllerImpl(
          // TODO: Change to `'$workerName.js'.toJS` when releasing version `6.0.0` (a new major version).
          // this is a workaround to use a wider range of the package `web` version (>=0.5.1 <2.0.0).
          Worker('$workerName.js' as dynamic),
          converter: converter,
          workerConverter: workerConverter,
          onDispose: null,
        );

  /// Check for current cumputing state in enum with listener
  final StreamController<Msg<R>> _mainStreamController =
      StreamController.broadcast();

  /// Listener for result
  IsolateContactorController<R, P>? _isolateContactorController;

  // final _isolateWorker = Worker("isolate.dart.js");

  /// Control the function of isolate
  // ignore: unused_field
  final void Function(dynamic) _isolateFunction;

  /// Control the parameters of isolate
  // ignore: unused_field
  final dynamic _isolateParam;

  /// Create modified isolate function
  static Future<IsolateContactorInternalWorker<R, P>> createCustom<R, P>({
    required CustomIsolateFunction isolateFunction,
    required String workerName,
    required Object? initialParams,
    required IsolateConverter<R> converter,
    required IsolateConverter<R> workerConverter,
    bool debugMode = false,
  }) async {
    final isolateContactor = IsolateContactorInternalWorker<R, P>._(
      isolateFunction: isolateFunction,
      workerName: workerName,
      isolateParam: initialParams,
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
        () => '[Main Stream] Message received from Worker: $message',
      );
      _mainStreamController.sink.add(message);
    }).onError((Object err, StackTrace? stack) {
      printDebug(
        () => '[Main Stream] Error message received from Worker: $err',
      );
      _mainStreamController.sink.addError(err, stack);
    });

    await _isolateContactorController!.ensureInitialized.future;

    printDebug(() => 'Initialized');
  }

  /// Get current message as stream
  @override
  Stream<Msg<R>> get onMessage => _mainStreamController.stream;

  /// Dispose current [Isolate]
  @override
  Future<void> dispose() async {
    _isolateContactorController?.sendIsolateState(IsolateState.dispose);

    await _isolateContactorController?.close();
    await _mainStreamController.close();

    _isolateContactorController = null;

    printDebug(() => 'Disposed');
  }

  /// Send message to child isolate [function].
  ///
  /// Throw IsolateContactorException if error occurs.
  @override
  Future<R> sendMessage(Msg<P> message) {
    if (_isolateContactorController == null) {
      printDebug(() => '! This isolate has been terminated');
      return throw const IsolateException(-1, 'This isolate was terminated');
    }

    final completer = Completer<R>();
    late final StreamSubscription<Msg<R>> sub;
    sub = _isolateContactorController!.onMessage.listen((result) async {
      if (!completer.isCompleted && result is TaskData<R>) {
        completer.complete(result.value);
        await sub.cancel();
      }
    })
      ..onError((Object err, StackTrace? stack) async {
        completer.completeError(err, stack);
        await sub.cancel();
      });

    printDebug(() => 'Message send to isolate: $message');

    _isolateContactorController!.sendIsolate(message);

    return completer.future;
  }
}
