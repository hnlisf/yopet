import 'dart:math' as math;

class CompanyApproach {
  CompanyApproach(double distance) : distance = math.max(0, distance);
  final double distance;
  double get speed => (distance / 16).clamp(45, 160);
  Duration get timeout => Duration(seconds: (distance / speed * 2 + 8).ceil());
  static bool reached(double distance) => distance <= 24;
}
