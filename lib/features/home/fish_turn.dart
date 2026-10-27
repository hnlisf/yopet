import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Two side views blend during a banked turn without a singular flat scale.
/// Child artwork must face left, matching curated and custom tank sprites.
class FishTurn extends StatelessWidget {
  const FishTurn({super.key, required this.facingLeft, required this.child});
  final bool facingLeft;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: facingLeft ? 1.0 : 0.0),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 780),
    curve: Curves.easeInOutSine,
    builder: (context, progress, _) {
      final bank = math.sin(progress * math.pi);
      final width = 1 - .24 * bank;
      final mix = Curves.easeInOut.transform(
        ((progress - .30) / .40).clamp(0, 1),
      );
      Widget side(bool left, double opacity) => Opacity(
        opacity: opacity,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(
            left ? width : -width,
            1 + .04 * bank,
            1,
          ),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              (left ? Colors.white : Colors.black).withValues(
                alpha: .10 * bank,
              ),
              BlendMode.srcATop,
            ),
            child: child,
          ),
        ),
      );
      return Transform.translate(
        offset: Offset(0, -4 * bank),
        child: Transform.rotate(
          angle: .09 * bank,
          child: Stack(
            alignment: Alignment.center,
            children: [side(false, 1 - mix), side(true, mix)],
          ),
        ),
      );
    },
  );
}
