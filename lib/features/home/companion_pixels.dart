import 'dart:typed_data';

/// Converts straight RGBA from Flutter's rawStraightRgba capture into the
/// premultiplied BGRA required by a Windows per-pixel layered surface.
/// Never infer alpha from a colour key: purple fish remain purple.
Uint8List companionBgra(Uint8List rgba) {
  if (rgba.length % 4 != 0) throw ArgumentError('Incomplete RGBA pixel');
  final result = Uint8List(rgba.length);
  for (var i = 0; i < rgba.length; i += 4) {
    final alpha = rgba[i + 3];
    result[i] = (rgba[i + 2] * alpha + 127) ~/ 255;
    result[i + 1] = (rgba[i + 1] * alpha + 127) ~/ 255;
    result[i + 2] = (rgba[i] * alpha + 127) ~/ 255;
    result[i + 3] = alpha;
  }
  return result;
}
