import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/home/company_approach.dart';

void main() {
  test(
    'desktop distance sets travel budget instead of a fixed twelve seconds',
    () {
      final near = CompanyApproach(100);
      final far = CompanyApproach(2400);
      expect(far.speed, greaterThan(near.speed));
      expect(far.timeout.inSeconds, greaterThan(12));
      expect(far.timeout.inSeconds * far.speed, greaterThan(2400));
      expect(CompanyApproach.reached(800), isFalse);
      expect(CompanyApproach.reached(24), isTrue);
    },
  );
}
