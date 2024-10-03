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
    final (key, value) = event as (IsolatePort, IsolateMessage<dynamic>);
    switch (key) {
      case IsolatePort.main:
        _handelDelegateMain(value);
      case IsolatePort.isolate:
        _handelDelegateIsolate(value);
    }
  }

  void _handelDelegateMain(IsolateMessage<dynamic> event) {
    final value = event.value;

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

    _mainStreamController.add(event.withValue(useConverter(value)));
  }

  R useConverter(dynamic value);

  void _handelDelegateIsolate(IsolateMessage<dynamic> event) {
    final value = event.value;
    if (value == IsolateState.dispose) {
      onDispose?.call();
      close();
    } else {
      _isolateStreamController.add(event.withValue(value as P));
    }
  }

  Future<void> closeStream() async {
    await Future.wait([
      _mainStreamController.close(),
      _isolateStreamController.close(),
    ]);
  }
}
