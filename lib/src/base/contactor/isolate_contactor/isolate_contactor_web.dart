import 'dart:async';

import 'package:isolate_manager/src/base/contactor/isolate_contactor.dart';
import 'package:isolate_manager/src/base/contactor/isolate_contactor/web_platform/isolate_contactor_web.dart';
import 'package:isolate_manager/src/base/contactor/isolate_contactor/web_platform/isolate_contactor_web_worker.dart';
import 'package:isolate_manager/src/isolate_manager.dart';

abstract class IsolateContactorInternal<R, P> extends IsolateContactor<R, P> {
  /// Constructer.
  const IsolateContactorInternal({required super.debugMode});

  /// Create modified isolate function
  static Future<IsolateContactorInternal<R, P>> createCustom<R, P>({
    required CustomIsolateFunction isolateFunction,
    required String workerName,
    required Object? initialParams,
    required IsolateConverter<R> converter,
    required IsolateConverter<R> workerConverter,
    bool debugMode = false,
  }) async {
    /// If browser is not supported Worker then use Future
    if (workerName != '') {
      try {
        return IsolateContactorInternalWorker.createCustom<R, P>(
          isolateFunction: isolateFunction,
          workerName: workerName,
          initialParams: initialParams,
          converter: converter,
          workerConverter: workerConverter,
          debugMode: debugMode,
        );
      } catch (_) {
        if (debugMode) {
          print(
            "[${IsolateContactor.debugLogPrefix}]: This browser doesn't support Worker, Future will be applied!",
          );
        }
      }
    }
    return IsolateContactorInternalFuture.createCustom<R, P>(
      isolateFunction: isolateFunction,
      isolateFunctionName: workerName,
      initialParams: initialParams,
      converter: converter,
      workerConverter: workerConverter,
      debugMode: debugMode,
    );
  }

  @override
  Future<void> dispose() {
    throw UnimplementedError();
  }

  @override
  Stream<Msg<R>> get onMessage => throw UnimplementedError();

  @override
  Future<R> sendMessage(Msg<P> message) {
    throw UnimplementedError();
  }
}
