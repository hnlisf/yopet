import 'dart:typed_data';
import 'package:yopet/features/home/companion_pixels.dart';

void main() {
  for (final size in [(1920, 1080), (2560, 1440), (3840, 2160)]) {
    final pixels = Uint8List(size.$1 * size.$2 * 4);
    for (var i = 3; i < pixels.length; i += 4) { pixels[i] = 128; }
    companionBgra(pixels);
    final watch = Stopwatch()..start();
    for (var frame = 0; frame < 10; frame++) { companionBgra(pixels); }
    watch.stop();
    // ignore: avoid_print
    print('${size.$1}x${size.$2}: conversion ${(watch.elapsedMicroseconds / 10000).toStringAsFixed(1)} ms/frame; raw payload ${(pixels.length * 15 / 1000000).toStringAsFixed(1)} MB/s at 15fps');
  }
}
