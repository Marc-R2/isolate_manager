import 'package:isolate_manager/isolate_manager.dart';

class IsolateManagerCompute<R, P> extends IsolateManager<R, P> {
  IsolateManagerCompute.fromSettings(
    super.settings, {
    super.concurrent,
    super.queueStrategy,
  }) : super.fromSettings();
}
