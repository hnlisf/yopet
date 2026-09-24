import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import 'weather_models.dart';

/// A quiet canvas overlay. Weather changes light, water texture and free-swim
/// pacing, never a fish's health or any action the player must repair.
class WeatherAtmosphere extends StatelessWidget {
  const WeatherAtmosphere({required this.weather, super.key});

  final WeatherSnapshot? weather;

  @override
  Widget build(BuildContext context) {
    final condition = weather?.condition;
    if (condition == null) return const SizedBox.expand();
    final tint = switch (condition) {
      WeatherCondition.clear => const Color(0x24D4A574),
      WeatherCondition.partlyCloudy => const Color(0x165BA8B5),
      WeatherCondition.overcast => const Color(0x263C6178),
      WeatherCondition.fog => const Color(0x2EE8EEF2),
      WeatherCondition.drizzle => const Color(0x245BA8B5),
      WeatherCondition.rain => const Color(0x345BA8B5),
      WeatherCondition.snow => const Color(0x26E8EEF2),
      WeatherCondition.storm => const Color(0x2C6C6AA0),
    };
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [tint, tint.withValues(alpha: 0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(painter: _WeatherTexturePainter(condition)),
          ),
        ],
      ),
    );
  }
}

class _WeatherTexturePainter extends CustomPainter {
  const _WeatherTexturePainter(this.condition);

  final WeatherCondition condition;

  @override
  void paint(Canvas canvas, Size size) {
    switch (condition) {
      case WeatherCondition.clear:
        _paintSunrays(canvas, size);
      case WeatherCondition.partlyCloudy:
      case WeatherCondition.overcast:
        _paintCloudVeil(canvas, size);
      case WeatherCondition.fog:
        _paintFog(canvas, size);
      case WeatherCondition.drizzle:
      case WeatherCondition.rain:
        _paintRain(canvas, size, condition == WeatherCondition.drizzle);
      case WeatherCondition.snow:
        _paintSnow(canvas, size);
      case WeatherCondition.storm:
        _paintStorm(canvas, size);
    }
  }

  void _paintSunrays(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Tokens.amber.withValues(alpha: 0.12)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 5; index++) {
      final x = size.width * (0.16 + index * 0.18);
      canvas.drawLine(Offset(x, 0), Offset(x + 42, size.height * 0.2), paint);
    }
  }

  void _paintCloudVeil(Canvas canvas, Size size) {
    final paint = Paint()..color = Tokens.textDim.withValues(alpha: 0.055);
    for (var index = 0; index < 4; index++) {
      final x = size.width * (index * 0.31 - 0.08);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, size.height * (0.14 + (index % 2) * 0.12)),
          width: size.width * 0.48,
          height: size.height * 0.13,
        ),
        paint,
      );
    }
  }

  void _paintFog(Canvas canvas, Size size) {
    final paint = Paint()..color = Tokens.text.withValues(alpha: 0.06);
    for (var index = 0; index < 5; index++) {
      final y = size.height * (0.13 + index * 0.18);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * (0.38 + (index % 2) * 0.2), y),
          width: size.width * 0.92,
          height: 24,
        ),
        paint,
      );
    }
  }

  void _paintRain(Canvas canvas, Size size, bool isDrizzle) {
    final paint = Paint()
      ..color = Tokens.tankGlowSoft.withValues(alpha: isDrizzle ? 0.16 : 0.26)
      ..strokeWidth = isDrizzle ? 1 : 1.5
      ..strokeCap = StrokeCap.round;
    final count = isDrizzle ? 13 : 20;
    for (var index = 0; index < count; index++) {
      final x = size.width * ((index * 0.173 + 0.06) % 1);
      final y = size.height * ((index * 0.097 + 0.08) % 0.92);
      canvas.drawLine(
        Offset(x, y),
        Offset(x - 7, y + (isDrizzle ? 12 : 20)),
        paint,
      );
    }
  }

  void _paintSnow(Canvas canvas, Size size) {
    final paint = Paint()..color = Tokens.text.withValues(alpha: 0.46);
    for (var index = 0; index < 18; index++) {
      final x = size.width * ((index * 0.217 + 0.04) % 1);
      final y = size.height * ((index * 0.137 + 0.05) % 0.94);
      canvas.drawCircle(Offset(x, y), 1.2 + (index % 3) * 0.45, paint);
    }
  }

  void _paintStorm(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = const Color(0xFFB6A8E6).withValues(alpha: 0.16);
    canvas.drawCircle(Offset(size.width * 0.76, size.height * 0.18), 56, glow);
    final paint = Paint()
      ..color = const Color(0xFFB6A8E6).withValues(alpha: 0.32)
      ..strokeWidth = 1.3;
    final path = Path()
      ..moveTo(size.width * 0.74, 0)
      ..lineTo(size.width * 0.68, size.height * 0.15)
      ..lineTo(size.width * 0.76, size.height * 0.15)
      ..lineTo(size.width * 0.7, size.height * 0.3);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WeatherTexturePainter oldDelegate) =>
      oldDelegate.condition != condition;
}
