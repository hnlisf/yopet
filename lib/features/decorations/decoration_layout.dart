/// Converts a persisted normalized decoration position into the position of
/// its rendered canvas. PNGs often include transparent watercolor breathing
/// room, so vertical placement anchors the visible silhouette rather than the
/// invisible bottom of that canvas.
class TankDecorationLayout {
  const TankDecorationLayout._();

  static double leftForPosition({
    required double positionX,
    required double tankWidth,
    required double size,
  }) => (tankWidth - size) * positionX;

  static double topForPosition({
    required double positionY,
    required double tankHeight,
    required double size,
    required double contentBottomInset,
  }) => (tankHeight - size) * positionY + size * contentBottomInset;

  static double visibleBottomForPosition({
    required double positionY,
    required double tankHeight,
    required double size,
    required double contentBottomInset,
  }) =>
      topForPosition(
        positionY: positionY,
        tankHeight: tankHeight,
        size: size,
        contentBottomInset: contentBottomInset,
      ) +
      size * (1 - contentBottomInset);
}
