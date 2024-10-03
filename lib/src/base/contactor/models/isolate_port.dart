/// Port for sending message
enum IsolatePort {
  main,
  isolate;

  IsolatePort get opposite => switch (this) {
        main => isolate,
        isolate => main,
      };
}

class IsolateMessage<R> {
  IsolateMessage(this.id, this.port, this.value);

  final int id;

  final IsolatePort port;

  final R value;

  IsolateMessage<T> returnWith<T>(T value) =>
      IsolateMessage<T>(id, port.opposite, value);

  @override
  String toString() => 'IsolateMessage{id: $id, value: $value}';
}
