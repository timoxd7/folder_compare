import 'dart:async';

class LimitedQueue<T> {
  final List<T> _queue = <T>[];
  int limit;

  LimitedQueue(this.limit);

  Completer<void>? _onPop;
  Completer<void>? _onAdd;

  Future<void> add(T item) async {
    if (_queue.length >= limit) {
      _onPop = Completer<void>();
      await _onPop!.future;
    }

    _queue.add(item);

    if (_onAdd != null) {
      _onAdd!.complete();
      _onAdd = null;
    }
  }

  Future<T> pop() async {
    if (_queue.isEmpty) {
      _onAdd = Completer<void>();
      await _onAdd!.future;
    }

    final T item = _queue.removeAt(0);

    if (_onPop != null) {
      _onPop!.complete();
      _onPop = null;
    }

    return item;
  }

  bool get isEmpty => _queue.isEmpty;
  bool get isNotEmpty => _queue.isNotEmpty;
}
