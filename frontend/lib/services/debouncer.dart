import 'dart:async';

import 'package:flutter/foundation.dart';

/// Utility to debounce rapid user-triggered actions.
///
/// Only the last call within [delay] will execute. Useful for search inputs,
/// save buttons, and other user-triggered API calls.
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 500)});

  /// Schedule [action] to run after [delay]. Any previously scheduled action
  /// is cancelled.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Schedule an async [action] after [delay], returning a Future.
  /// Previous pending actions are cancelled.
  Future<T> runAsync<T>(Future<T> Function() action) {
    _timer?.cancel();
    final completer = Completer<T>();
    _timer = Timer(delay, () async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  /// Cancel any pending debounced action.
  void cancel() {
    _timer?.cancel();
  }

  /// Whether a debounced action is currently pending.
  bool get isPending => _timer?.isActive ?? false;

  /// Clean up the timer.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
