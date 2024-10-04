import 'dart:async';

import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager/src/base/contactor/models/isolate_port.dart';

mixin Streams<R, P> {
  final StreamController<IsolateMessage<R>> _mainStreamController =
      StreamController.broadcast();

  final StreamController<IsolateMessage<P>> _isolateStreamController =
      StreamController.broadcast();

  Stream<IsolateMessage<R>> get onMessage => _mainStreamController.stream;

  Stream<IsolateMessage<P>> get onIsolateMessage =>
      _isolateStreamController.stream;

  void Function()? get onDispose;

  Future<void> close();

  Completer<void> ensureInitialized = Completer();

  void handleDelegate(dynamic event) {
    final (key, value) = event as (IsolatePort, dynamic);
    return switch (key) {
      IsolatePort.main => _handelDelegateMain(value),
      IsolatePort.isolate => _handelDelegateIsolate(value),
    };
  }

  void _handelDelegateMain(dynamic event) {
    if (event is IsolateException) {
      _mainStreamController.addError(event, event.stack);
      return;
    }

    if (event == IsolateState.initialized) {
      if (!ensureInitialized.isCompleted) {
        ensureInitialized.complete();
      }
      return;
    }

    if (event is TaskStateUpdate<R>) {
      if (event is TaskData<R>) {
        _mainStreamController.add(event.withValue(useConverter(event.value)));
      } else if (event is TaskControl<R>) {
        _mainStreamController.add(event);
      } else {
        throw UnimplementedError();
      }
    }
  }

  R useConverter(dynamic value);

  void _handelDelegateIsolate(dynamic value) {
    if (value == IsolateState.dispose) {
      onDispose?.call();
      close();
    } else if (value is IsolateMessage<P>) {
      _isolateStreamController.add(value);
    } else {
      throw UnimplementedError();
    }
  }

  Future<void> closeStream() async {
    await Future.wait([
      _mainStreamController.close(),
      _isolateStreamController.close(),
    ]);
  }
}
