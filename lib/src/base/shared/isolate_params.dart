import 'package:isolate_manager/isolate_manager.dart';

typedef DefaultIsolateManager
    = IsolateManagerCompute<Object, IsolateParams<Object, dynamic>>;

abstract class IsolateParams<R, P> {
  const IsolateParams(this.funcRaw, this.params);

  final dynamic funcRaw;
  final P params;
}

class IsolateParamsFunc<R, P> extends IsolateParams<R, P> {
  const IsolateParamsFunc(IsolateFutureOr<R, P> super.func, super.params);

  dynamic Function(P) get func => funcRaw as dynamic Function(P);

  dynamic call() => func(params);
}

class IsolateParamsRef<R, P> extends IsolateParams<R, P> {
  const IsolateParamsRef(super.func, super.params);

  String get func => funcRaw as String;
}
