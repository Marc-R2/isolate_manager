// coverage:ignore-file
// Tested by compiling to `js` for the Web Worker.

import 'dart:async';
import 'dart:js_interop';

import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager/src/base/contactor/models/isolate_port.dart';
import 'package:web/web.dart';

@JS('self')
external DedicatedWorkerGlobalScope get self;

/// Create a worker in your `main`.
Future<void> isolateWorkerImpl<R, P>(
  IsolateWorkerFunction<R, P> function,
  FutureOr<void> Function()? onInitial,
) async {
  final controller = IsolateManagerController<R, P>(self);
  if (onInitial != null) {
    final completer = Completer<void>()..complete(onInitial());
    await completer.future;
  }
  controller.onIsolateMessage.listen((message) async {
    if (message is! TaskData<P>) {
      throw UnimplementedError();
    }
    final irc = IsolateRuntimeController<R, P>(
      msg: message,
      controller: controller,
      initialParams: controller.initialParams,
    );

    final completer = Completer<R?>();
    final then = completer.future
        .then((value) => irc.sendResult(value as R))
        .onError((err, stack) => completer.completeError(err!, stack));

    try {
      completer.complete(await function(message.value));
    } catch (err, stack) {
      completer.completeError(err, stack);
    }
    await then;
  });
  controller.initialized();
}

/// Create a custom worker in your `main`.
void customWorkerFunctionImpl(IsolateWorkerFunction<void, dynamic> function) {
  function(self);
}
