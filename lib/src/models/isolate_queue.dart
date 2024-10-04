import 'dart:async';

import 'package:isolate_manager/src/base/contactor/models/isolate_port.dart';
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

  TaskState state = TaskState.idle;

  final _completer = Completer<void>();

  Future<void> get done => _completer.future;

  bool get isDone => _completer.isCompleted;

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
  final Completer<R> _dataCompleter = Completer<R>();

  Future<R> get future => _dataCompleter.future;

  void _canComplete() {
    if (isDone) throw StateError('Task already completed');
    if (_dataCompleter.isCompleted) throw StateError('Data not completed');
  }

  void complete(R data) {
    _canComplete();
    _dataCompleter.complete(data);
    _completer.complete();
  }

  void completeError(Object error, StackTrace stack) {
    _canComplete();
    _dataCompleter.completeError(error, stack);
    _completer.complete();
  }

  @override
  String toString() => 'ComputeTask{id: $id, params: $params}';
}

class StreamTask<R, P> extends IsolateQueue<R, P> {
  /// Use for queuing your `stream`.
  StreamTask(super.params, super.callback);

  final StreamController<R> _controller = StreamController<R>.broadcast();

  Stream<R> get stream => _controller.stream;

  void _canComplete() {
    if (isDone) throw StateError('Task already completed');
    if (_controller.isClosed) throw StateError('Controller not completed');
  }

  void add(R event) {
    _canComplete();
    _controller.add(event);
  }

  void addError(Object error, [StackTrace? stackTrace]) {
    _canComplete();
    _controller.addError(error, stackTrace);
  }

  Future<void> close() async {
    _canComplete();
    await _controller.close();
    _completer.complete();
  }

  @override
  String toString() => 'StreamTask{id: $id, params: $params}';
}
