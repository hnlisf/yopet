import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DesktopCompanion {
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  static const channel = MethodChannel('yopet/desktop_companion');
  static Future<void> enter() => channel.invokeMethod<void>('enter');
}
