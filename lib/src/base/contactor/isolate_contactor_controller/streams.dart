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
    switch (key) {
      case IsolatePort.main:
        _handelDelegateMain(value);
      case IsolatePort.isolate:
        _handelDelegateIsolate(value);
    }
  }

  void _handelDelegateMain(dynamic value) {
    if (value is IsolateException) {
      _mainStreamController.addError(value.error, value.stack);
      return;
    }

    if (value == IsolateState.initialized) {
      if (!ensureInitialized.isCompleted) {
        ensureInitialized.complete();
      }
      return;
    }

    if (value is IsolateMessage<R>) {
      _mainStreamController.add(value.withValue(useConverter(value.value)));
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
