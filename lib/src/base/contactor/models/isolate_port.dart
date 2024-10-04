/// Port for sending message
enum IsolatePort {
  main,
  isolate;

  IsolatePort get opposite => switch (this) {
        main => isolate,
        isolate => main,
      };
}

enum TaskState {
  idle,
  started,
  data,
  error,
  done,
}

abstract class TaskStateUpdate<R> {
  const TaskStateUpdate({required this.id, required this.state});

  final int id;

  final TaskState state;
}

class TaskControl<R> extends TaskStateUpdate<R> {
  const TaskControl(int id, TaskState state) : super(id: id, state: state);

  @override
  String toString() => 'TaskControl{id: $id, state: $state}';
}

typedef IsolateMessage<R> = TaskStateUpdate<R>;

class TaskData<R> extends TaskStateUpdate<R> {
  const TaskData(int id, this.value)
      : super(id: id, state: TaskState.data);

  final R value;

  IsolateMessage<T> withValue<T>(T value) => TaskData<T>(id, value);

  @override
  String toString() => 'TaskData{id: $id, value: $value}';
}
