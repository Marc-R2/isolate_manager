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
  IsolateMessage(this.id, this.value);

  final int id;

  final R value;

  IsolateMessage<T> withValue<T>(T value) =>
      IsolateMessage<T>(id, value);

  @override
  String toString() => 'IsolateMessage{id: $id, value: $value}';
}
