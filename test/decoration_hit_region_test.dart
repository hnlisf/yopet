import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/decorations/decoration_hit_region.dart';

void main() {
  test(
    'transparent decoration pixels and contain letterboxing pass through',
    () {
      final pixels = Uint8List(2 * 4);
      pixels[7] = 255;
      final mask = DecorationMask(2, 1, pixels);
      expect(
        mask.contains(const Offset(25, 50), const Size(100, 100)),
        isFalse,
      );
      expect(mask.contains(const Offset(75, 50), const Size(100, 100)), isTrue);
      expect(
        mask.contains(const Offset(75, 10), const Size(100, 100)),
        isFalse,
      );
    },
  );
}
