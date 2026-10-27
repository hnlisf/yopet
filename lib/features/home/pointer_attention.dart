import 'package:flutter/painting.dart';

class PointerAttention {
  Offset? _anchor;
  Duration? _since;
  Duration? _last;
  bool update(Offset pointer, Offset fish, Duration time) {
    if ((pointer - fish).distance > 150) {
      _anchor = null;
      _since = null;
      return false;
    }
    if (_anchor == null || (pointer - _anchor!).distance > 8) {
      _anchor = pointer;
      _since = time;
      return false;
    }
    if (time - _since! < const Duration(seconds: 1) ||
        (_last != null && time - _last! < const Duration(seconds: 15))) {
      return false;
    }
    _last = time;
    return true;
  }
}
