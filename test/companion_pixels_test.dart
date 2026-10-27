import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/home/companion_pixels.dart';

void main() {
  test('preserves fin alpha without adding a purple matte', () {
    expect(companionBgra(Uint8List.fromList([240, 120, 0, 128])),
        [0, 60, 120, 128]);
    expect(companionBgra(Uint8List.fromList([255, 0, 255, 0])),
        [0, 0, 0, 0]);
    expect(companionBgra(Uint8List.fromList([255, 0, 255, 255])),
        [255, 0, 255, 255]);
  });
  test('rejects incomplete pixels', () {
    expect(() => companionBgra(Uint8List(3)), throwsArgumentError);
  });
}
