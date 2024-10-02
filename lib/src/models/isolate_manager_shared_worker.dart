import 'package:isolate_manager/isolate_manager.dart';

/// All functions with this annotation will be combined and generated to the `$shared_worker.js`
/// inside the `web` folder.
const isolateManagerSharedWorker = _IsolateManagerWorkerShared();

/// Shared Worker annotation
class _IsolateManagerWorkerShared {
  // ignore: unused_element
  const _IsolateManagerWorkerShared([this.name = kSharedWorkerName]);

  /// Name of the Worker JS. Default is `worker.js`.
  final String name;
}
