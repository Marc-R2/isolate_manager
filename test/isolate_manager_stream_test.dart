// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';

import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager/src/isolate_manager_stream.dart';
import 'package:test/test.dart';

//  dart run isolate_manager:generate -i test -o test
//  dart test
//  dart test --platform=chrome,vm

void main() async {
  test('fibonacciStream', () async {
    final isolate = IsolateManagerStream<int, int>(
      const IsolateSettings.stream(
        isolateFunction: fibonacciStream,
      ),
    );

    final stream = isolate.stream(10);
    final list = await stream.toList();
    expect(list, [0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55]);
  });
}

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
  }
}
