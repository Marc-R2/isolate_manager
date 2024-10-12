// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';

import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager/src/isolate_manager_stream.dart';
import 'package:test/test.dart';

//  dart run isolate_manager:generate -i test -o test
//  dart test
//  dart test --platform=chrome,vm

void main() {
  test('fibonacciStream(10)', () async {
    final isolate = IsolateManagerStream<int, int>(
      const IsolateSettingsStream(
        isolateFunction: fibonacciStream,
      ),
    );

    final stream = isolate.stream(10);
    final list = await stream.toList();
    expect(list, [0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55]);
  });

  test('fibonacciSync(10)', () async {
    final isolate = IsolateManagerStream<int, int>(
      const IsolateSettingsIterable(
        isolateFunction: fibonacciSync,
      ),
    );

    final stream = isolate.stream(10);
    final list = await stream.toList();
    expect(list, [0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55]);
  });

  test('fibonacciStream(0)', () async {
    final isolate = IsolateManagerStream<int, int>(
      const IsolateSettingsStream(
        isolateFunction: fibonacciStream,
      ),
    );

    final stream = isolate.stream(0);
    final list = await stream.toList();
    expect(list, [0]);
  });

  test('fibonacciStream(-1)', () async {
    final isolate = IsolateManagerStream<int, int>(
      const IsolateSettingsStream(
        isolateFunction: fibonacciStream,
      ),
    );

    final stream = isolate.stream(-1);
    await expectLater(stream, emitsError(isA<StateError>()));
  });

  test('fibonacciStream(1)', () async {
    final isolate = IsolateManagerStream<int, int>(
      const IsolateSettingsStream(
        isolateFunction: fibonacciStream,
      ),
    );

    final stream = isolate.stream(1);
    final list = await stream.toList();
    expect(list, [0, 1]);
  });

  test('async fibonacciStream(s)', () async {
    final isolate = IsolateManagerStream<int, int>(
      const IsolateSettingsStream(
        isolateFunction: fibonacciStream,
      ),
    );

    const samples = 64;

    final stream1 = isolate.stream(samples);
    final stream2 = isolate.stream(samples);

    final stopwatch = Stopwatch()..start();

    final l1 = stream1.toList();
    final l2 = stream2.toList();
    await Future.wait([l1, l2]);
    expect(await l1, await l2);

    stopwatch.stop();

    // Check if the total time is less than the sum of individual times
    expect(
      stopwatch.elapsedMilliseconds,
      lessThan(2 * samples * streamDelay.inMilliseconds),
    );
  });
}

@isolateManagerWorker
Iterable<int> fibonacciSync(int n) sync* {
  if (n < 0) throw StateError('n<0');
  if (n >= 0) yield 0;
  if (n >= 1) yield 1;

  var f1 = 0;
  var f2 = 1;
  var r = 1;

  for (var i = 2; i <= n; i++) {
    r = f1 + f2;
    f1 = f2;
    f2 = r;
    yield r;
  }
}

const streamDelay = Duration(milliseconds: 4);

@isolateManagerWorker
Stream<int> fibonacciStream(int n) async* {
  if (n < 0) throw StateError('n<0');
  if (n >= 0) yield 0;
  if (n >= 1) yield 1;

  var f1 = 0;
  var f2 = 1;
  var r = 1;

  for (var i = 2; i <= n; i++) {
    r = f1 + f2;
    f1 = f2;
    f2 = r;
    yield r;
    await Future<void>.delayed(streamDelay);
  }
}
