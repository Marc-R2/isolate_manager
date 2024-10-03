import 'dart:async';

import 'package:isolate_manager/src/isolate_manager.dart';

/// Use for queuing your `compute`.
abstract class IsolateQueue<R, P> {
  /// Use for queuing your `compute`.
  IsolateQueue(this.params, this.callback) : id = _idCounter++;

  static var _idCounter = 0;

  /// Unique id of this `IsolateQueue`.
  final int id;

  /// Control the params of this `IsolateQueue`.
  final P params;

  /// Control when to return the needed result.
  final IsolateCallback<R>? callback;

  FutureOr<bool> callCallback(R event) {
    final callback = this.callback;
    if (callback == null) return true;

    final completer = Completer<bool>()..complete(callback(event));
    return completer.future;
  }
}

class ComputeTask<R, P> extends IsolateQueue<R, P> {
  /// Use for queuing your `compute`.
  ComputeTask(super.params, super.callback);

  /// Control the state and result of this `IsolateQueue`.
  final Completer<R> completer = Completer<R>();

  Future<R> get future => completer.future;

  @override
  String toString() => 'ComputeTask{id: $id, params: $params}';
}

class StreamTask<R, P> extends IsolateQueue<R, P> {
  /// Use for queuing your `stream`.
  StreamTask(super.params, super.callback);

  final StreamController<R> controller = StreamController<R>.broadcast();

  Stream<R> get stream => controller.stream;

  @override
  String toString() => 'StreamTask{id: $id, params: $params}';
}
