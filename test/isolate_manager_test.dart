// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';
import 'dart:convert';

import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager/src/models/isolate_queue.dart';
import 'package:test/test.dart';

//  dart run isolate_manager:generate -i test -o test
//  dart test
//  dart test --platform=chrome,vm

void main() {
  group('Models', () {
    test('IsolateState', () {
      for (final state in IsolateState.values) {
        expect(state.isValidJson(state.toJson()), equals(true));
      }
    });

    test('IsolateException', () {
      final exception =
          IsolateException(1, 'Object', StackTrace.fromString('stackTrace'));
      final json = exception.toJson();
      expect(IsolateException.isValidObject(json), equals(true));
      expect(IsolateException.fromJson(json), isA<IsolateException>());
    });
  });

  test('Test IsolateManager.create: Basic Usage', () async {
    // Create IsolateContactor
    final isolateManager = IsolateManagerCompute(
      const IsolateSettings(
        isolateFunction: fibonacci,
        isDebug: true,
      ),
      concurrent: 4,
    );

    final result = await isolateManager.compute(3);

    expect(result, fibonacci(3));

    await isolateManager.stop();
  });

  test('Test IsolateManager.create', () async {
    // Create IsolateContactor
    final isolateManager = IsolateManagerCompute(
      const IsolateSettings(isolateFunction: fibonacci),
      concurrent: 4,
    );

    expect(isolateManager.isStarted, equals(false));

    await isolateManager.start();

    expect(isolateManager.isStarted, equals(true));
    await isolateManager.ensureStarted;

    expect(isolateManager.queuesLength, equals(0));

    await Future.wait([
      for (int i = 0; i < 10; i++)
        isolateManager.compute(i).then((value) {
          expect(value, fibonacci(i));
        }),
    ]);

    await isolateManager.stop();
  });

  test('Test IsolateManager.createCustom', () async {
    // Create IsolateContactor
    final isolateManager = IsolateManagerCompute<int, int>(
      const IsolateSettings.custom(
        isolateFunction: isolateFunction,
        initialParams: ['Test initialParams 0', 'Test initialParams 1'],
        workerName: 'fibonacci',
      ),
      concurrent: 4,
    );
    await isolateManager.start();

    isolateManager.eventStream
        .listen((value) {})
        // Do not need to catch the error here
        .onError((error) {});

    await Future.wait([
      for (int i = 0; i < 10; i++)
        isolateManager.compute(i).then((value) {
          expect(value, fibonacci(i));
        }),
    ]);

    await isolateManager.restart();

    await Future.wait([
      for (int i = 5; i < 13; i++)
        isolateManager.compute(i).then((value) {
          expect(value, fibonacci(i));
        }),
    ]);

    await expectLater(() => isolateManager.compute(-1), throwsStateError);
    await isolateManager.stop();
  });

  test('Test IsolateManager.createCustom with `null` initialParams', () async {
    // Create IsolateContactor
    final isolateManager = IsolateManagerCompute<int, int>(
      const IsolateSettings.custom(isolateFunction: isolateFunction),
      concurrent: 1,
    );
    await isolateManager.start();

    await expectLater(() => isolateManager.compute(-1), throwsStateError);
    await isolateManager.stop();
  });

  test('Test IsolateManager.createCustom with automatically handlers',
      () async {
    // Create IsolateContactor
    final isolateManager = IsolateManagerCompute<int, int>(
      const IsolateSettings.custom(
        isolateFunction: isolateFunctionWithAutomaticallyHandlers,
        initialParams: ['Test initialParams 0', 'Test initialParams 1'],
      ),
      concurrent: 4,
    );
    await isolateManager.start();

    isolateManager.eventStream
        .listen((value) {})
        // Do not need to catch the error here
        .onError((error) {});

    await Future.wait([
      for (int i = 0; i < 10; i++)
        isolateManager.compute(i).then((value) {
          expect(value, fibonacci(i));
        }),
    ]);

    await isolateManager.restart();

    await Future.wait([
      for (int i = 5; i < 13; i++)
        isolateManager.compute(i).then((value) {
          expect(value, fibonacci(i));
        }),
    ]);

    await expectLater(() => isolateManager.compute(-1), throwsStateError);
    await isolateManager.stop();
  });

  test('Test IsolateManager.create with Worker', () async {
    // Create IsolateContactor
    final isolateManager = IsolateManagerCompute(
      const IsolateSettings(
        isolateFunction: fibonacci,
        workerName: 'fibonacci',
      ),
      concurrent: 4,
    );

    await isolateManager.start();

    await Future.wait([
      for (int i = 0; i < 10; i++)
        isolateManager.compute(i).then((value) {
          final realFib = fibonacci(i);

          expect(value, realFib);
        }),
    ]);

    await isolateManager.stop();
  });

  test('Test with Exception future function', () async {
    final isolateManager = IsolateManagerCompute(
      const IsolateSettings(isolateFunction: errorFunctionFuture),
      concurrent: 1,
    );
    await isolateManager.start();

    await expectLater(
      () async => isolateManager.compute([50, 50]),
      throwsStateError,
    );
    await isolateManager.stop();
  });

  test('Test with Exception function', () async {
    final isolateManager = IsolateManagerCompute(
      const IsolateSettings(isolateFunction: errorFunction),
      concurrent: 1,
    );
    await isolateManager.start();

    await expectLater(
      () async => isolateManager.compute([50, 50]),
      throwsStateError,
    );
    await isolateManager.stop();
  });

  test('Test with Exception function with available callback', () async {
    final isolateManager = IsolateManagerCompute(
      const IsolateSettings(isolateFunction: errorFunction),
      concurrent: 1,
    );
    await isolateManager.start();

    await expectLater(
      () => isolateManager.compute([50, 50], callback: (value) => true),
      throwsStateError,
    );
    await isolateManager.stop();
  });

  test('Test with Exception function with eagerError is true', () async {
    final isolateManager = IsolateManagerCompute(
      const IsolateSettings(isolateFunction: errorFunction),
      concurrent: 2,
    );
    await isolateManager.start();
    final futures = <Future<int>>[];

    for (var i = 0; i < 100; i++) {
      futures.add(isolateManager.compute([i, 20]));
    }

    await expectLater(
      () async => Future.wait(futures, eagerError: true),
      throwsStateError,
    );
    await isolateManager.stop();
  });

  test(
      'Test with Exception function with eagerError is true with available callback',
      () async {
    final isolateManager = IsolateManagerCompute(
      const IsolateSettings(isolateFunction: errorFunction),
      concurrent: 2,
    );
    await isolateManager.start();
    final futures = <Future<int>>[];

    for (var i = 0; i < 100; i++) {
      futures.add(isolateManager.compute([i, 20], callback: (value) => true));
    }

    await expectLater(
      () async => Future.wait(futures, eagerError: true),
      throwsStateError,
    );
    await isolateManager.stop();
  });

  test('Test with Exception function with eagerError is false', () async {
    final isolateManager = IsolateManagerCompute(
      const IsolateSettings(isolateFunction: errorFunction),
      concurrent: 2,
    );
    await isolateManager.start();
    final futures = <Future<int>>[];

    for (var i = 0; i < 100; i++) {
      futures.add(isolateManager.compute([i, 20]));
    }

    await expectLater(
      () async => Future.wait(futures, eagerError: false),
      throwsStateError,
    );
    await isolateManager.stop();
  });

  test(
      'Test with Exception function with eagerError is false with available callback',
      () async {
    final isolateManager = IsolateManagerCompute(
      const IsolateSettings(isolateFunction: errorFunction),
      concurrent: 2,
    );
    await isolateManager.start();
    final futures = <Future<int>>[];

    for (var i = 0; i < 100; i++) {
      futures.add(isolateManager.compute([i, 20], callback: (value) => true));
    }

    await expectLater(
      () async => Future.wait(futures),
      throwsStateError,
    );
    await isolateManager.stop();
  });

  test('Test with IsolateCallback', () async {
    final isolateManager = IsolateManagerCompute<String, int>(
      const IsolateSettings.custom(
        isolateFunction: isolateCallbackFunction,
        workerName: 'workers/isolateCallbackFunction',
      ),
      concurrent: 1,
    );
    await isolateManager.start();

    final result = await isolateManager.compute(
      1,
      callback: (value) {
        final decoded = jsonDecode(value) as Map;
        // Do not return this [value] as the final result
        if (decoded.containsKey('source')) {
          return false;
        }

        // Return this [value] as the final result
        return true;
      },
    );

    final decoded = jsonDecode(result) as Map;
    expect(
      decoded.containsKey('data'),
      equals(true),
    );

    await isolateManager.stop();
  });

  test('Test with IsolateCallback with simpler function', () async {
    final isolateManager = IsolateManagerCompute<String, int>(
      const IsolateSettings.custom(
        isolateFunction: isolateCallbackSimpleFunction,
        workerName: 'workers/isolateCallbackSimpleFunction',
      ),
      concurrent: 1,
    );
    await isolateManager.start();

    final result = await isolateManager.compute(
      1,
      callback: (value) {
        final decoded = jsonDecode(value) as Map;
        // Do not return this [value] as the final result
        if (decoded.containsKey('source')) {
          return false;
        }

        // Return this [value] as the final result
        return true;
      },
    );

    final decoded = jsonDecode(result) as Map;
    expect(
      decoded.containsKey('data'),
      equals(true),
    );

    await isolateManager.stop();
  });

  test('Test with IsolateCallback with simpler specified type function',
      () async {
    final isolateManager = IsolateManagerCompute<String, int>(
      const IsolateSettings.custom(
        isolateFunction: isolateCallbackSimpleFunctionWithSpecifiedType,
        workerName: 'isolateCallbackSimpleFunctionWithSpecifiedType',
      ),
      concurrent: 1,
    );
    await isolateManager.start();

    final result = await isolateManager.compute(
      1,
      callback: (value) {
        final decoded = jsonDecode(value) as Map;
        // Do not return this [value] as the final result
        if (decoded.containsKey('source')) {
          return false;
        }

        // Return this [value] as the final result
        return true;
      },
    );

    final decoded = jsonDecode(result) as Map;
    expect(
      decoded.containsKey('data'),
      equals(true),
    );

    await isolateManager.stop();
  });

  test(
      'Test with IsolateCallback with simpler specified type function no Worker',
      () async {
    final isolateManager = IsolateManagerCompute<String, int>(
      const IsolateSettings.custom(
        isolateFunction: isolateCallbackSimpleFunctionWithSpecifiedType,
      ),
      concurrent: 1,
    );
    await isolateManager.start();

    final result = await isolateManager.compute(
      1,
      callback: (value) {
        final decoded = jsonDecode(value) as Map;
        // Do not return this [value] as the final result
        if (decoded.containsKey('source')) {
          return false;
        }

        // Return this [value] as the final result
        return true;
      },
    );

    final decoded = jsonDecode(result) as Map;
    expect(
      decoded.containsKey('data'),
      equals(true),
    );

    await isolateManager.stop();
  });

  test('Test with returning a List<String>', () async {
    final isolate = IsolateManagerCompute(
      IsolateSettings(
        isolateFunction: aStringList,
        workerName: 'workers/aStringList',
        // Cast to List<String>
        workerConverter: (value) => value.cast<String>() as List<String>,
      ),
    );
    await isolate.start();

    final listString = ['a', 'b', 'c'];
    final result = await isolate.compute(listString);

    expect(result, listString);
  });

  test('Test with returning a Map<String, int>', () async {
    final isolate = IsolateManagerCompute(
      const IsolateSettings(
        isolateFunction: aStringIntMap,
        workerName: 'aStringIntMap',
      ),
    );
    await isolate.start();

    final map = {'a': 1, 'b': 2, 'c': 3};
    final result = await isolate.compute(jsonEncode(map));

    expect(jsonDecode(result), map);
  });

  group('Isolate Queue Strategy -', () {
    test('QueueStrategyRemoveNewest with unlimited queue count', () {
      final queueStrategies = QueueStrategyUnlimited<int, int>();
      for (var i = 0; i < 10; i++) {
        queueStrategies.add(ComputeTask<int, int>(i, null));
      }
      expect(queueStrategies.queuesCount, equals(10));
      expect(queueStrategies.continueIfMaxCountExceeded(), true);
      final result = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
      while (queueStrategies.hasNext()) {
        expect(queueStrategies.getNext().params, equals(result.removeAt(0)));
      }
      expect(result.length, equals(0));
    });

    test('QueueStrategyRemoveNewest with addToTop is true', () {
      final queueStrategies = QueueStrategyUnlimited<int, int>();
      for (var i = 0; i < 10; i++) {
        queueStrategies.add(ComputeTask<int, int>(i, null), addToTop: true);
      }
      expect(queueStrategies.queuesCount, equals(10));
      final result = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].reversed.toList();
      while (queueStrategies.hasNext()) {
        expect(queueStrategies.getNext().params, equals(result.removeAt(0)));
      }
      expect(result.length, equals(0));
    });

    test('QueueStrategyRemoveNewest', () {
      final queueStrategies = QueueStrategyRemoveNewest<int, int>(maxCount: 3);
      for (var i = 0; i < 10; i++) {
        queueStrategies.add(ComputeTask<int, int>(i, null));
      }
      expect(queueStrategies.queuesCount, equals(3));
      final result = [0, 1, 9];
      while (queueStrategies.hasNext()) {
        expect(queueStrategies.getNext().params, equals(result.removeAt(0)));
      }
      expect(result.length, equals(0));
    });

    test('QueueStrategyRemoveNewest with addToTop is true', () {
      final queueStrategies = QueueStrategyRemoveNewest<int, int>(maxCount: 3);
      for (var i = 0; i < 10; i++) {
        queueStrategies.add(ComputeTask<int, int>(i, null), addToTop: true);
      }
      expect(queueStrategies.queuesCount, equals(3));
      final result = [9, 8, 7];
      while (queueStrategies.hasNext()) {
        expect(queueStrategies.getNext().params, equals(result.removeAt(0)));
      }
      expect(result.length, equals(0));
    });

    test('QueueStrategyRemoveOldest', () {
      final queueStrategies = QueueStrategyRemoveOldest<int, int>(maxCount: 3);
      for (var i = 0; i < 10; i++) {
        queueStrategies.add(ComputeTask<int, int>(i, null));
      }
      expect(queueStrategies.queuesCount, equals(3));
      final result = [7, 8, 9];
      while (queueStrategies.hasNext()) {
        expect(queueStrategies.getNext().params, equals(result.removeAt(0)));
      }
      expect(result.length, equals(0));
    });

    test('QueueStrategyRemoveOldest with addToTop is true', () {
      final queueStrategies = QueueStrategyRemoveOldest<int, int>(maxCount: 3);
      for (var i = 0; i < 10; i++) {
        queueStrategies.add(ComputeTask<int, int>(i, null), addToTop: true);
      }
      expect(queueStrategies.queuesCount, equals(3));
      final result = [9, 1, 0];
      while (queueStrategies.hasNext()) {
        expect(queueStrategies.getNext().params, equals(result.removeAt(0)));
      }
      expect(result.length, equals(0));
    });

    test('QueueStrategyDiscardIncoming', () {
      final queueStrategies =
          QueueStrategyDiscardIncoming<int, int>(maxCount: 3);
      for (var i = 0; i < 10; i++) {
        queueStrategies.add(ComputeTask<int, int>(i, null));
      }
      expect(queueStrategies.queuesCount, equals(3));
      final result = [0, 1, 2];
      while (queueStrategies.hasNext()) {
        expect(queueStrategies.getNext().params, equals(result.removeAt(0)));
      }
      expect(result.length, equals(0));
    });

    test('QueueStrategyDiscardIncoming with addToTop is true', () {
      final queueStrategies =
          QueueStrategyDiscardIncoming<int, int>(maxCount: 3);
      for (var i = 0; i < 10; i++) {
        queueStrategies.add(ComputeTask<int, int>(i, null), addToTop: true);
      }
      expect(queueStrategies.queuesCount, equals(3));
      final result = [2, 1, 0];
      while (queueStrategies.hasNext()) {
        expect(queueStrategies.getNext().params, equals(result.removeAt(0)));
      }
      expect(result.length, equals(0));
    });
  });
}

@isolateManagerWorker
int fibonacci(int n) {
  if (n < 0) throw StateError('n<0');
  if (n == 0) return 0;
  if (n == 1) return 1;

  var f1 = 0;
  var f2 = 1;
  var r = 1;

  for (var i = 2; i <= n; i++) {
    r = f1 + f2;
    f1 = f2;
    f2 = r;
  }

  return r;
}

@isolateManagerWorker
int fibonacciRecursive(int n) {
  if (n == 0) return 0;
  if (n == 1) return 1;

  return fibonacciRecursive(n - 1) + fibonacciRecursive(n - 2);
}

@isolateManagerWorker
List<String> aStringList(List<String> params) {
  return params;
}

@isolateManagerWorker
String aStringIntMap(String params) {
  return params;
}

void isolateFunction(dynamic params) {
  IsolateManagerFunction.customFunction<int, int>(
    params,
    onEvent: (controller, message) {
      try {
        final result = fibonacci(message);
        controller.sendResult(result);
      } catch (err, stack) {
        controller.sendResultError(err, stack);
      }
      return 0;
    },
    onInitial: (controller, initialParams) {},
    onDispose: (controller) {},
    autoHandleException: false,
    autoHandleResult: false,
  );
}

@pragma('vm:entry-point')
void isolateFunctionWithAutomaticallyHandlers(dynamic params) {
  IsolateManagerFunction.customFunction<int, int>(
    params,
    onEvent: (controller, message) {
      return fibonacci(message);
    },
    onInitial: (controller, initialParams) {},
    onDispose: (controller) {},
    autoHandleException: true,
    autoHandleResult: true,
  );
}

@isolateManagerCustomWorker
void isolateCallbackFunction(dynamic params) {
  IsolateManagerFunction.customFunction(
    params,
    onEvent: (controller, message) {
      try {
        for (var i = 0; i < 10; i++) {
          controller.sendResult(jsonEncode({'source': '$i'}));
        }

        controller.sendResult(jsonEncode({'data': 'data'}));
      } catch (err, stack) {
        controller.sendResultError(err, stack);
      }

      // Just returns something that unused to complete this method.
      return '';
    },
    autoHandleException: false,
    autoHandleResult: false,
  );
}

@isolateManagerCustomWorker
void isolateCallbackSimpleFunction(dynamic params) {
  IsolateManagerFunction.customFunction(
    params,
    onEvent: (controller, message) {
      for (var i = 0; i < 10; i++) {
        controller.sendResult(jsonEncode({'source': '$i'}));
      }

      return jsonEncode({'data': message});
    },
  );
}

@isolateManagerCustomWorker
void isolateCallbackSimpleFunctionWithSpecifiedType(dynamic params) {
  IsolateManagerFunction.customFunction<String, int>(
    params,
    onEvent: (controller, message) {
      for (var i = 0; i < 10; i++) {
        controller.sendResult(jsonEncode({'source': '$i'}));
      }

      return jsonEncode({'data': message});
    },
  );
}

@pragma('vm:entry-point')
int errorFunction(List<int> value) {
  if (value[0] == 50) {
    return throw StateError('The exception is threw at value[0] = ${value[0]}');
  }
  return value[0] + value[1];
}

@pragma('vm:entry-point')
Future<int> errorFunctionFuture(List<int> value) async {
  await Future<void>.delayed(const Duration(seconds: 1));

  if (value[0] == 50) {
    return throw StateError('The exception is threw at value[0] = ${value[0]}');
  }
  return value[0] + value[1];
}
