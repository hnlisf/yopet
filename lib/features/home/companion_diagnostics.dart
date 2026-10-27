import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Temporary stability probe. No names, accounts, pointer coordinates or pixels.
class CompanionDiagnostics {
  static Timer? _timer;
  static int _surfaces = 0;
  static final _counts = <String, int>{};
  static void count(String stage) {
    if (!kDebugMode) return;
    _counts.update(stage, (v) => v + 1, ifAbsent: () => 1);
  }
  static void attach() {
    if (!kDebugMode) return;
    _surfaces++;
    _timer ??= Timer.periodic(const Duration(seconds: 10), (_) {
      debugPrint(
        '[DEBUG-companion-stall] lifecycle=${WidgetsBinding.instance.lifecycleState} surfaces=$_surfaces stages=$_counts',
      );
      _counts.clear();
    });
  }

  static void detach() {
    if (!kDebugMode) return;
    _surfaces--;
    if (_surfaces == 0) {
      _timer?.cancel();
      _timer = null;
      _counts.clear();
    }
  }
}
