import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/home/pointer_attention.dart';

void main() {
  test('requires nearby stable pointer and cools down', () {
    final attention = PointerAttention();
    expect(attention.update(Offset.zero, Offset.zero, Duration.zero), isFalse);
    expect(
      attention.update(Offset.zero, Offset.zero, const Duration(seconds: 1)),
      isTrue,
    );
    expect(
      attention.update(Offset.zero, Offset.zero, const Duration(seconds: 5)),
      isFalse,
    );
    expect(
      attention.update(
        const Offset(500, 0),
        Offset.zero,
        const Duration(seconds: 17),
      ),
      isFalse,
    );
    expect(
      attention.update(Offset.zero, Offset.zero, const Duration(seconds: 18)),
      isFalse,
    );
    expect(
      attention.update(Offset.zero, Offset.zero, const Duration(seconds: 19)),
      isTrue,
    );
  });
}
