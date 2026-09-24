import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'fish_models.dart';
import 'fish_sprite.dart';

/// Renders a pre-illustrated, complete fish silhouette.
///
/// A body/tail pairing selects one row of its dedicated transparent artwork
/// sheet.  This deliberately avoids compositing independent body and tail
/// images, so no visible join, overlap, or straight source-image crop can
/// appear at the caudal peduncle.
class CustomFishSprite extends StatelessWidget {
  const CustomFishSprite({
    required this.appearance,
    this.growthStage = GrowthStage.adult,
    this.facingLeft = false,
    this.width = 120,
    this.patternTuning = const CustomFishPatternTuning(),
    this.patternStudyDirection = 1,
    super.key,
  });

  final CustomFishAppearance appearance;
  final GrowthStage growthStage;
  final bool facingLeft;
  final double width;
  final CustomFishPatternTuning patternTuning;

  /// The approved watercolor art direction is 1. Direction 0 remains only
  /// for the comparison screen's legacy reference; 2 and 3 are archived
  /// exploration directions.
  final int patternStudyDirection;

  @override
  Widget build(BuildContext context) {
    final body = customFishBodyForId(appearance.body);
    final tail = customFishTailForId(appearance.tail);
    final pattern = customFishPatternForId(appearance.pattern);
    final tone = customFishColorForId(appearance.color);
    final scale = FishSprite.scaleForStage(growthStage);
    final fishWidth = width * scale;
    final fishHeight = fishWidth / 1.5;
    final completeSprite = customFishCompleteSpriteFor(body: body, tail: tail);
    final patternLayout = customFishPatternLayout(
      body: body,
      tail: tail,
      pattern: pattern,
      baseColor: tone.color,
      tuning: patternTuning,
    );

    final artwork = SizedBox(
      width: fishWidth,
      height: fishHeight,
      child: _CompleteFishArtwork(
        sprite: completeSprite,
        bodyId: body.id,
        tailId: tail.id,
        color: tone.color,
        patternLayout: patternLayout,
        patternStudyDirection: patternStudyDirection,
      ),
    );
    return Transform.flip(flipX: facingLeft, child: artwork);
  }
}

/// Gentle, player-facing variation controls for a naturally grown marking.
///
/// These values tune a biological pattern family; they never move a decal in
/// screen coordinates. The seed is stable for a fish so its individual look
/// survives ordinary widget rebuilds.
@immutable
class CustomFishPatternTuning {
  const CustomFishPatternTuning({
    this.density = 0.55,
    this.softness = 0.65,
    this.individualSeed = 0,
  });

  final double density;
  final double softness;
  final int individualSeed;
}

/// The part of a fish torso that can carry markings.
///
/// Fins, tail fins, and the face are deliberately excluded: their lighter,
/// unmarked appearance keeps a custom fish legible as a fish rather than a
/// painted sticker.
enum CustomFishBodyContour { oval, stream, diamond, box }

/// The pigment family used by a biological-looking fish marking.  Each entry
/// is intentionally descriptive rather than a generic opacity overlay.
enum CustomFishMarkingTone {
  cloudIvory,
  pearlGold,
  warmUmber,
  riverBlue,
  aqua,
  saddleMahogany,
  bodyDerivedWave,
  bellyCream,
}

/// The marking's natural structure.  The painter uses this policy to avoid
/// substituting unrelated geometric shapes for fish-specific pigmenting.
enum CustomFishMarkingForm {
  cloudPatches,
  pearledSpots,
  verticalBands,
  lateralLines,
  lateralRibbon,
  dorsalSaddles,
  waveBands,
  lowerCrescent,
}

/// Visual policy for fitting a watercolor marking to a joined fish's torso.
///
/// Bounds and source focus are normalized to 0..1. Keeping this policy apart
/// from image decoding gives every body/pattern combination a testable visual
/// contract, while allowing a slender eel and a tall diamond body to receive
/// proportionate rather than fixed-position markings.
@immutable
class CustomFishPatternLayout {
  const CustomFishPatternLayout({
    required this.bodyOpacity,
    required this.tailOpacity,
    required this.faceProtectionEnd,
    required this.bodyBounds,
    required this.bodyContour,
    required this.masksToSpriteAlpha,
    required this.patternId,
    required this.markingScale,
    required this.markingDensity,
    required this.markingSoftness,
    required this.markingAnchors,
    required this.markingPhase,
    required this.markingTone,
    required this.markingForm,
    required this.baseColor,
  });

  final double bodyOpacity;

  /// Kept explicit for regression tests. Tail and other fins never receive a
  /// custom pattern, so this must remain zero.
  final double tailOpacity;
  final double faceProtectionEnd;
  final Rect bodyBounds;
  final CustomFishBodyContour bodyContour;
  final bool masksToSpriteAlpha;

  /// The selected marking's identity.  It is rendered in the fish body's
  /// local coordinate system rather than pasted from a fixed-size texture.
  final String patternId;

  /// A body-area-aware multiplier used by the generated marking geometry.
  /// Tall disc bodies receive broader clusters than a narrow eel body, while
  /// still retaining each pattern's own visual character.
  final double markingScale;

  /// A body-aspect-aware multiplier.  Long bodies spread motifs farther along
  /// their lateral line; tall bodies hold a more compact, layered grouping.
  final double markingDensity;

  /// Softness of pigment edges, normalized to 0..1.
  final double markingSoftness;

  /// Normalized local anchors for the generated motif.  These are deliberately
  /// body dependent: a marking follows a fish's torso instead of behaving as
  /// a fixed sticker in screen coordinates.
  final List<Offset> markingAnchors;

  /// Stable variation for a body/tail/pattern combination.  It prevents a
  /// custom fish from looking mechanically stamped while remaining stable as
  /// the widget rebuilds.
  final double markingPhase;
  final CustomFishMarkingTone markingTone;
  final CustomFishMarkingForm markingForm;
  final Color baseColor;
}

CustomFishPatternLayout customFishPatternLayout({
  required CustomFishBody body,
  required CustomFishTail tail,
  required CustomFishPattern pattern,
  Color baseColor = const Color(0xFFFFA457),
  CustomFishPatternTuning tuning = const CustomFishPatternTuning(),
}) {
  final bodySpec = switch (body.id) {
    'round' => (
      Rect.fromLTWH(0.22, 0.32, 0.37, 0.35),
      CustomFishBodyContour.oval,
    ),
    'light' => (
      Rect.fromLTWH(0.20, 0.40, 0.42, 0.15),
      CustomFishBodyContour.stream,
    ),
    'diamond' => (
      Rect.fromLTWH(0.21, 0.34, 0.40, 0.30),
      CustomFishBodyContour.diamond,
    ),
    'disc' => (
      Rect.fromLTWH(0.22, 0.29, 0.37, 0.39),
      CustomFishBodyContour.oval,
    ),
    'torpedo' => (
      Rect.fromLTWH(0.20, 0.40, 0.43, 0.15),
      CustomFishBodyContour.stream,
    ),
    'bottom' => (
      Rect.fromLTWH(0.21, 0.39, 0.41, 0.15),
      CustomFishBodyContour.stream,
    ),
    'box' => (Rect.fromLTWH(0.22, 0.34, 0.39, 0.27), CustomFishBodyContour.box),
    'eel' => (
      Rect.fromLTWH(0.21, 0.41, 0.44, 0.16),
      CustomFishBodyContour.stream,
    ),
    _ => (Rect.fromLTWH(0.19, 0.41, 0.34, 0.18), CustomFishBodyContour.oval),
  };
  final bodyBounds = bodySpec.$1;
  final bodyAspect = bodyBounds.width / bodyBounds.height;
  final bodyAreaScale = math.sqrt(bodyBounds.width * bodyBounds.height);
  final shapeBias = switch (body.id) {
    'disc' || 'diamond' => 1.12,
    'round' || 'box' => 1.02,
    'light' || 'torpedo' => 0.90,
    'bottom' => 0.84,
    'eel' => 0.72,
    _ => 1.0,
  };
  final patternBias = switch (pattern.id) {
    'cloud' => 1.14,
    'pearl' => 0.70,
    'tiger' || 'zebra' => 0.92,
    'neon' => 1.0,
    'saddle' => 1.08,
    'wave' => 0.94,
    'belly' => 1.16,
    _ => 1.0,
  };
  final markingScale = (bodyAreaScale / 0.30 * shapeBias * patternBias).clamp(
    0.52,
    1.46,
  );
  final tunedDensity = tuning.density.clamp(0.0, 1.0);
  final tunedSoftness = tuning.softness.clamp(0.0, 1.0);
  final markingDensity =
      ((0.72 + bodyAspect * 0.18) * (0.72 + tunedDensity * 0.63)).clamp(
        0.62,
        1.78,
      );
  final markingPhase = _markingPhase(
    body.id,
    tail.id,
    pattern.id,
    tuning.individualSeed,
  );
  final markingAnchors = _markingAnchorsFor(
    body: body,
    pattern: pattern,
    density: markingDensity,
    tuningDensity: tunedDensity,
    phase: markingPhase,
  );
  final naturalProfile = switch (pattern.id) {
    'cloud' => (
      CustomFishMarkingTone.cloudIvory,
      CustomFishMarkingForm.cloudPatches,
    ),
    'pearl' => (
      CustomFishMarkingTone.pearlGold,
      CustomFishMarkingForm.pearledSpots,
    ),
    'tiger' => (
      CustomFishMarkingTone.warmUmber,
      CustomFishMarkingForm.verticalBands,
    ),
    'zebra' => (
      CustomFishMarkingTone.riverBlue,
      CustomFishMarkingForm.lateralLines,
    ),
    'neon' => (CustomFishMarkingTone.aqua, CustomFishMarkingForm.lateralRibbon),
    'saddle' => (
      CustomFishMarkingTone.saddleMahogany,
      CustomFishMarkingForm.dorsalSaddles,
    ),
    'wave' => (
      CustomFishMarkingTone.bodyDerivedWave,
      CustomFishMarkingForm.waveBands,
    ),
    'belly' => (
      CustomFishMarkingTone.bellyCream,
      CustomFishMarkingForm.lowerCrescent,
    ),
    _ => (CustomFishMarkingTone.cloudIvory, CustomFishMarkingForm.cloudPatches),
  };

  final rowShift = _bodyRowVerticalShift(body.id, tail.id);
  return CustomFishPatternLayout(
    bodyOpacity: 0.46,
    tailOpacity: 0,
    // All illustrated eyes sit within the front third. Leaving this region
    // unpainted protects expression without starving long-bodied fish of
    // usable torso area.
    faceProtectionEnd: 0.31,
    bodyBounds: bodyBounds.shift(Offset(0, rowShift)),
    bodyContour: bodySpec.$2,
    masksToSpriteAlpha: true,
    patternId: pattern.id,
    markingScale: markingScale.toDouble(),
    markingDensity: markingDensity.toDouble(),
    markingSoftness: tunedSoftness.toDouble(),
    markingAnchors: markingAnchors,
    markingPhase: markingPhase,
    markingTone: naturalProfile.$1,
    markingForm: naturalProfile.$2,
    baseColor: baseColor,
  );
}

List<Offset> _markingAnchorsFor({
  required CustomFishBody body,
  required CustomFishPattern pattern,
  required double density,
  required double tuningDensity,
  required double phase,
}) {
  final count = switch (pattern.id) {
    'cloud' => 3 + (tuningDensity * 3).round(),
    'pearl' => 5 + (tuningDensity * 5).round(),
    'tiger' || 'zebra' => 3 + (tuningDensity * 3).round(),
    'saddle' => 2 + (tuningDensity * 2).round(),
    'wave' => 3 + (tuningDensity * 2).round(),
    _ => 1,
  };
  final bodyShift = switch (body.id) {
    'diamond' => const Offset(-0.03, -0.02),
    'disc' => const Offset(-0.02, 0.01),
    'light' || 'torpedo' => const Offset(0.03, -0.01),
    'bottom' => const Offset(0.02, 0.03),
    'eel' => const Offset(0.05, 0.01),
    'box' => const Offset(-0.01, 0.00),
    _ => Offset.zero,
  };
  final template = List.generate(count, (index) {
    final fraction = count == 1 ? .5 : index / (count - 1);
    final wave = math.sin((phase * 6.28) + index * 2.17);
    return switch (pattern.id) {
      'cloud' => Offset(
        .34 + fraction * .48,
        .31 + ((index * 2) % 3) * .18 + wave * .045,
      ),
      'pearl' => Offset(
        .31 + fraction * .55,
        .29 + ((index * 5) % 4) * .14 + wave * .035,
      ),
      'tiger' => Offset(.35 + fraction * .50, .50 + wave * .025),
      'zebra' => Offset(.46 + fraction * .22, .27 + fraction * .46),
      'saddle' => Offset(.40 + fraction * .40, .25 + wave * .035),
      'wave' => Offset(.34 + fraction * .48, .36 + wave * .10),
      'belly' => const Offset(.56, .70),
      _ => const Offset(.56, .50),
    };
  });
  final lateralSpread = (0.84 + density * 0.13).clamp(0.88, 1.08);
  return List.unmodifiable(
    template.map((anchor) {
      final x = 0.5 + (anchor.dx - 0.5) * lateralSpread + bodyShift.dx;
      final y = anchor.dy + bodyShift.dy;
      return Offset(
        x.clamp(0.34, 0.84).toDouble(),
        y.clamp(0.14, 0.84).toDouble(),
      );
    }),
  );
}

double _markingPhase(
  String bodyId,
  String tailId,
  String patternId,
  int individualSeed,
) {
  final input = '$bodyId/$tailId/$patternId/$individualSeed';
  var hash = 23;
  for (final codeUnit in input.codeUnits) {
    hash = (hash * 37 + codeUnit) & 0x7fffffff;
  }
  return (hash % 1000) / 1000;
}

double _bodyRowVerticalShift(String bodyId, String tailId) {
  if (bodyId == 'disc' && tailId == 'petal') return 0;
  final row = switch (tailId) {
    'petal' => 0,
    'fan' => 1,
    'ribbon' => 2,
    _ => 1,
  };
  final shifts = switch (bodyId) {
    'round' => const [.090, 0.0, -.122],
    'light' => const [.173, 0.0, -.113],
    'diamond' => const [.059, 0.0, -.074],
    'disc' => const [.044, 0.0, -.074],
    'torpedo' => const [.089, 0.0, -.136],
    'bottom' => const [.133, 0.0, -.146],
    'box' => const [.115, 0.0, -.094],
    'eel' => const [.159, 0.0, -.131],
    _ => const [0.0, 0.0, 0.0],
  };
  return shifts[row];
}

/// Paints one row from a generated sprite sheet, then masks the selected
/// watercolor pattern to that same complete silhouette.
class _CompleteFishArtwork extends StatefulWidget {
  const _CompleteFishArtwork({
    required this.sprite,
    required this.bodyId,
    required this.tailId,
    required this.color,
    required this.patternLayout,
    required this.patternStudyDirection,
  });

  final CustomFishCompleteSprite sprite;
  final String bodyId;
  final String tailId;
  final Color color;
  final CustomFishPatternLayout patternLayout;
  final int patternStudyDirection;

  @override
  State<_CompleteFishArtwork> createState() => _CompleteFishArtworkState();
}

class _CompleteFishArtworkState extends State<_CompleteFishArtwork> {
  ui.Image? _sheet;
  ui.Image? _torsoMask;
  ImageStream? _sheetStream;
  ImageStream? _maskStream;
  ImageStreamListener? _sheetListener;
  ImageStreamListener? _maskListener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImages();
  }

  @override
  void didUpdateWidget(covariant _CompleteFishArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sprite.assetPath != widget.sprite.assetPath ||
        oldWidget.sprite.torsoMaskAssetPath !=
            widget.sprite.torsoMaskAssetPath) {
      _removeListeners();
      _sheet = null;
      _torsoMask = null;
      _resolveImages();
    }
  }

  @override
  void dispose() {
    _removeListeners();
    super.dispose();
  }

  void _resolveImages() {
    _sheetStream = AssetImage(
      widget.sprite.assetPath,
    ).resolve(createLocalImageConfiguration(context));
    _sheetListener = ImageStreamListener((image, _) {
      if (mounted) setState(() => _sheet = image.image);
    });
    _sheetStream!.addListener(_sheetListener!);
    _maskStream = AssetImage(
      widget.sprite.torsoMaskAssetPath,
    ).resolve(createLocalImageConfiguration(context));
    _maskListener = ImageStreamListener((image, _) {
      if (mounted) setState(() => _torsoMask = image.image);
    });
    _maskStream!.addListener(_maskListener!);
  }

  void _removeListeners() {
    if (_sheetStream != null && _sheetListener != null) {
      _sheetStream!.removeListener(_sheetListener!);
    }
    if (_maskStream != null && _maskListener != null) {
      _maskStream!.removeListener(_maskListener!);
    }
    _sheetStream = null;
    _maskStream = null;
    _sheetListener = null;
    _maskListener = null;
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _sheet;
    final torsoMask = _torsoMask;
    if (sheet == null || torsoMask == null) return const SizedBox.expand();
    return CustomPaint(
      painter: _CompleteFishPainter(
        sheet: sheet,
        torsoMask: torsoMask,
        row: widget.sprite.row,
        rows: widget.sprite.rows,
        bodyId: widget.bodyId,
        tailId: widget.tailId,
        color: widget.color,
        patternLayout: widget.patternLayout,
        patternStudyDirection: widget.patternStudyDirection,
      ),
    );
  }
}

class _CompleteFishPainter extends CustomPainter {
  const _CompleteFishPainter({
    required this.sheet,
    required this.torsoMask,
    required this.row,
    required this.rows,
    required this.bodyId,
    required this.tailId,
    required this.color,
    required this.patternLayout,
    required this.patternStudyDirection,
  });

  final ui.Image sheet;
  final ui.Image torsoMask;
  final int row;
  final int rows;
  final String bodyId;
  final String tailId;
  final Color color;
  final CustomFishPatternLayout patternLayout;
  final int patternStudyDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final sourceHeight = sheet.height / rows;
    final source = Rect.fromLTWH(
      0,
      sourceHeight * row.clamp(0, rows - 1),
      sheet.width.toDouble(),
      sourceHeight,
    );
    final destination = Offset.zero & size;
    // The complete silhouette stays a single illustration. Isolating this
    // layer lets the fin membranes transmit the aquarium behind the fish
    // without punching holes in the rest of the scene.
    canvas.saveLayer(destination, Paint());
    if (color == customFishColors.first.color) {
      // Keep the established warm-orange rendering of the master artwork.
      canvas.drawImageRect(
        sheet,
        source,
        destination,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..colorFilter = ColorFilter.mode(color, BlendMode.modulate),
      );
    } else {
      final tintedPaint = Paint()
        ..filterQuality = FilterQuality.medium
        // Replace the orange hue and saturation, retaining the original
        // watercolour luminance and ink. Direct multiplication made blue and
        // green fish muddy brown.
        ..colorFilter = ColorFilter.mode(color, BlendMode.color);

      canvas.saveLayer(destination, Paint());
      canvas.drawImageRect(sheet, source, destination, tintedPaint);
      // The bright master needs value correction for darker selected colours.
      final targetTone = HSLColor.fromColor(color);
      final hueDistance =
          ((((targetTone.hue - 28 + 540) % 360) - 180).abs() / 180);
      final darkness = ((.65 - targetTone.lightness) / .25).clamp(0.0, 1.0);
      final correction = (.12 + .72 * hueDistance + .16 * darkness).clamp(
        .12,
        .95,
      );
      canvas.drawRect(
        destination,
        Paint()
          ..color = Color.lerp(Colors.white, color, correction)!
          ..blendMode = BlendMode.modulate,
      );
      // BlendMode.color can fill transparent source pixels with solid tint.
      // Restore the exact transparency of the one-piece illustration.
      canvas.drawImageRect(
        sheet,
        source,
        destination,
        Paint()..blendMode = BlendMode.dstIn,
      );
      canvas.restore();
    }

    _paintFinTranslucency(
      canvas,
      size,
      bodyId: bodyId,
      tailId: tailId,
      bodyBounds: patternLayout.bodyBounds,
      torsoMask: torsoMask,
      source: source,
    );
    canvas.restore();

    final bodyBounds = _scaledBounds(size, patternLayout.bodyBounds);
    canvas.saveLayer(destination, Paint());
    if (patternStudyDirection == 0) {
      _paintBodyGrownMarking(canvas, bodyBounds, patternLayout);
    } else {
      _paintStudyBodyMarking(
        canvas,
        bodyBounds,
        patternLayout,
        patternStudyDirection,
      );
    }
    if (patternLayout.masksToSpriteAlpha) {
      // Every complete body/tail row has a separately audited torso mask.
      // Unlike generic silhouette alpha, it excludes dorsal, pectoral, anal
      // and tail fins, so pigment can never leak onto them.
      canvas.drawImageRect(
        patternStudyDirection > 0 && patternLayout.patternId == 'belly'
            ? sheet
            : torsoMask,
        source,
        destination,
        Paint()..blendMode = BlendMode.dstIn,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CompleteFishPainter oldDelegate) =>
      oldDelegate.sheet != sheet ||
      oldDelegate.torsoMask != torsoMask ||
      oldDelegate.row != row ||
      oldDelegate.rows != rows ||
      oldDelegate.bodyId != bodyId ||
      oldDelegate.tailId != tailId ||
      oldDelegate.color != color ||
      oldDelegate.patternLayout != patternLayout ||
      oldDelegate.patternStudyDirection != patternStudyDirection;
}

/// Thin fin membranes transmit water across their surface, not only at their
/// very tips. The torso mask and a narrow opaque root protect the body from
/// opacity washes, while the original painted rays remain visible.
void _paintFinTranslucency(
  Canvas canvas,
  Size size, {
  required String bodyId,
  required String tailId,
  required Rect bodyBounds,
  required ui.Image torsoMask,
  required Rect source,
}) {
  final body = _scaledBounds(size, bodyBounds);
  // Begin near the peduncle: the inner torso mask is intentionally smaller
  // than the silhouette, so the narrow tail root must stay solid.
  final tailStart = body.right + size.width * .020;
  final tailFade = switch (tailId) {
    'fan' => .59,
    'ribbon' => .47,
    _ => .55,
  };
  final tailRegion = Rect.fromLTRB(tailStart, 0, size.width, size.height);
  // A thin, backlit membrane is slightly paler as well as see-through.
  // Lifting it first prevents warm fins from turning muddy over dark water.
  canvas.drawRect(
    tailRegion,
    Paint()
      ..blendMode = BlendMode.srcATop
      ..shader = ui.Gradient.linear(
        Offset(tailStart, body.center.dy),
        Offset(size.width * .88, body.center.dy),
        [Colors.transparent, Colors.white.withValues(alpha: .32)],
      ),
  );

  // Accumulate all fin fades on a mask, cut the torso back out, and only then
  // remove opacity from the illustration. This keeps even a broad dorsal or
  // near-side pectoral wash from thinning the skin where fins overlap it.
  canvas.saveLayer(Offset.zero & size, Paint()..blendMode = BlendMode.dstOut);
  canvas.drawRect(
    tailRegion,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(tailStart, body.center.dy),
        Offset(size.width * .88, body.center.dy),
        [
          Colors.transparent,
          Colors.black.withValues(alpha: tailFade * .18),
          Colors.black.withValues(alpha: tailFade * .58),
          Colors.black.withValues(alpha: tailFade * .87),
          Colors.black.withValues(alpha: tailFade),
        ],
        const [0, .10, .35, .70, 1],
      ),
  );

  final tallFins =
      bodyId == 'diamond' ||
      bodyId == 'box' ||
      bodyId == 'bottom' ||
      bodyId == 'torpedo';
  final dorsalHeight = size.height * (tallFins ? .14 : .085);
  // The pattern-safe torso mask only covers inner skin. Fade the outer fin
  // wash out before its root instead of clipping at a visible straight line.
  _fadeFinWithSoftRoot(
    canvas,
    size: size,
    rootY: body.top - body.height * .23,
    feather: size.height * .08,
    dorsal: true,
    center: Offset(
      body.left + body.width * (tallFins ? .56 : .53),
      body.top - dorsalHeight * (tallFins ? .80 : .72),
    ),
    radiusX: body.width * (tallFins ? .38 : .29),
    radiusY: dorsalHeight * 1.45,
    strength: tallFins ? .58 : .52,
  );

  // The near-side pectoral fin is thin and mobile, but its attachment should
  // remain the same colour as the torso. A feathered distal wash does that
  // without producing a second, visibly pasted-on shape.
  _fadeFinWithSoftRoot(
    canvas,
    size: size,
    rootY: body.bottom + body.height * .18,
    feather: size.height * .05,
    dorsal: false,
    center: Offset(
      body.left + body.width * .25,
      body.bottom + size.height * (bodyId == 'diamond' ? -.005 : .035),
    ),
    radiusX: body.width * .21,
    radiusY: size.height * (bodyId == 'diamond' ? .085 : .105),
    strength: .55,
  );

  if (tallFins || bodyId == 'eel') {
    _fadeFinWithSoftRoot(
      canvas,
      size: size,
      rootY: body.bottom + body.height * .18,
      feather: size.height * .08,
      dorsal: false,
      center: Offset(
        body.left + body.width * .70,
        body.bottom + size.height * (bodyId == 'diamond' ? .12 : .045),
      ),
      radiusX: body.width * .30,
      radiusY: size.height * (bodyId == 'diamond' ? .18 : .11),
      strength: .54,
    );
  }
  canvas.drawImageRect(
    torsoMask,
    source,
    Offset.zero & size,
    Paint()..blendMode = BlendMode.dstOut,
  );
  canvas.restore();
}

void _fadeFinWithSoftRoot(
  Canvas canvas, {
  required Size size,
  required double rootY,
  required double feather,
  required bool dorsal,
  required Offset center,
  required double radiusX,
  required double radiusY,
  required double strength,
}) {
  canvas.saveLayer(Offset.zero & size, Paint());
  _fadeFinTip(
    canvas,
    center: center,
    radiusX: radiusX,
    radiusY: radiusY,
    strength: strength,
  );
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = ui.Gradient.linear(
        Offset(0, dorsal ? rootY - feather : rootY),
        Offset(0, dorsal ? rootY : rootY + feather),
        dorsal
            ? [Colors.black, Colors.transparent]
            : [Colors.transparent, Colors.black],
      ),
  );
  canvas.restore();
}

void _fadeFinTip(
  Canvas canvas, {
  required Offset center,
  required double radiusX,
  required double radiusY,
  required double strength,
}) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(radiusX, radiusY);
  canvas.drawCircle(
    Offset.zero,
    1,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1,
        [
          Colors.black.withValues(alpha: strength),
          Colors.black.withValues(alpha: strength * .62),
          Colors.transparent,
        ],
        const [0, .55, 1],
      ),
  );
  canvas.restore();
}

Rect _scaledBounds(Size size, Rect normalized) => Rect.fromLTWH(
  normalized.left * size.width,
  normalized.top * size.height,
  normalized.width * size.width,
  normalized.height * size.height,
);

/// Draws markings from the local geometry of the fish's torso.  This is
/// intentionally not an image decal: every motif uses a body-relative scale,
/// density and set of anchors so a tall disc fish and a long eel do not carry
/// the same fixed piece of artwork.
void _paintBodyGrownMarking(
  Canvas canvas,
  Rect bodyBounds,
  CustomFishPatternLayout layout,
) {
  switch (layout.markingForm) {
    case CustomFishMarkingForm.cloudPatches:
      _paintCloudMarking(canvas, bodyBounds, layout);
      break;
    case CustomFishMarkingForm.pearledSpots:
      _paintPearlMarking(canvas, bodyBounds, layout);
      break;
    case CustomFishMarkingForm.verticalBands:
      _paintTigerMarking(canvas, bodyBounds, layout);
      break;
    case CustomFishMarkingForm.lateralLines:
      _paintZebraMarking(canvas, bodyBounds, layout);
      break;
    case CustomFishMarkingForm.lateralRibbon:
      _paintNeonMarking(canvas, bodyBounds, layout);
      break;
    case CustomFishMarkingForm.dorsalSaddles:
      _paintSaddleMarking(canvas, bodyBounds, layout);
      break;
    case CustomFishMarkingForm.waveBands:
      _paintWaveMarking(canvas, bodyBounds, layout);
      break;
    case CustomFishMarkingForm.lowerCrescent:
      _paintBellyMarking(canvas, bodyBounds, layout);
      break;
  }
}

Offset _bodyPoint(Rect bodyBounds, Offset local) => Offset(
  bodyBounds.left + local.dx * bodyBounds.width,
  bodyBounds.top + local.dy * bodyBounds.height,
);

Color _markingColor(CustomFishPatternLayout layout) {
  final base = HSLColor.fromColor(layout.baseColor);
  final hue = switch (layout.markingTone) {
    CustomFishMarkingTone.warmUmber ||
    CustomFishMarkingTone.saddleMahogany => _mixHue(base.hue, 26, .22),
    CustomFishMarkingTone.aqua => _mixHue(base.hue, 172, .74),
    // Wave is defined by its perpendicular S-curve, not a fixed hue. Keeping
    // the body hue lets orange, pink, green and blue fish each grow a related
    // pigment rather than receiving the same blue-cyan decal.
    CustomFishMarkingTone.bodyDerivedWave => base.hue,
    _ => base.hue,
  };
  final saturation = switch (layout.markingTone) {
    CustomFishMarkingTone.cloudIvory ||
    CustomFishMarkingTone.bellyCream => (base.saturation * .50).clamp(.22, .58),
    CustomFishMarkingTone.pearlGold => (base.saturation * .62).clamp(.38, .72),
    CustomFishMarkingTone.aqua => (base.saturation * .92).clamp(.55, .80),
    CustomFishMarkingTone.bodyDerivedWave => (base.saturation * .82).clamp(
      .40,
      .78,
    ),
    _ => (base.saturation * .82).clamp(.42, .78),
  };
  final lightness = switch (layout.markingTone) {
    CustomFishMarkingTone.cloudIvory => (base.lightness + .14).clamp(.56, .78),
    CustomFishMarkingTone.pearlGold => (base.lightness + .15).clamp(.60, .78),
    CustomFishMarkingTone.warmUmber => (base.lightness * .54).clamp(.20, .39),
    CustomFishMarkingTone.riverBlue => (base.lightness * .52).clamp(.20, .38),
    CustomFishMarkingTone.aqua => (base.lightness + .02).clamp(.50, .66),
    CustomFishMarkingTone.saddleMahogany => (base.lightness * .57).clamp(
      .22,
      .40,
    ),
    CustomFishMarkingTone.bodyDerivedWave => (base.lightness * .52).clamp(
      .16,
      .42,
    ),
    CustomFishMarkingTone.bellyCream => (base.lightness + .16).clamp(.64, .77),
  };
  return HSLColor.fromAHSL(
    1,
    hue,
    saturation.toDouble(),
    lightness.toDouble(),
  ).toColor();
}

double _mixHue(double start, double end, double amount) {
  final delta = ((end - start + 540) % 360) - 180;
  return (start + delta * amount + 360) % 360;
}

Paint _markingPaint(
  CustomFishPatternLayout layout,
  Color color,
  double opacity, {
  double softnessFactor = 1,
}) {
  final sigma =
      (.18 + layout.markingSoftness * 1.35) *
      layout.markingScale *
      softnessFactor;
  return Paint()
    ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
    ..style = PaintingStyle.fill
    ..maskFilter = sigma < .24 ? null : MaskFilter.blur(BlurStyle.normal, sigma)
    ..isAntiAlias = true;
}

void _paintCloudMarking(
  Canvas canvas,
  Rect bodyBounds,
  CustomFishPatternLayout layout,
) {
  final width = bodyBounds.width * 0.15 * layout.markingScale;
  final height = bodyBounds.height * 0.22 * layout.markingScale;
  for (var index = 0; index < layout.markingAnchors.length; index++) {
    final anchor = _bodyPoint(bodyBounds, layout.markingAnchors[index]);
    final phase = layout.markingPhase * math.pi * 2 + index * 1.73;
    final center =
        anchor +
        Offset(math.sin(phase) * width * .08, math.cos(phase) * height * .10);
    final radius = width * (.45 + math.sin(phase * 1.3).abs() * .12);
    final vertices = List.generate(9, (vertex) {
      final angle = vertex * math.pi * 2 / 9;
      final ripple =
          .78 +
          .15 * math.sin(angle * 3 + phase) +
          .10 * math.cos(angle * 5 - phase);
      return center +
          Offset(
            math.cos(angle) * radius * ripple,
            math.sin(angle) * height * .48 * ripple,
          );
    });
    final path = Path()..moveTo(vertices.first.dx, vertices.first.dy);
    for (var vertex = 0; vertex < vertices.length; vertex++) {
      final next = vertices[(vertex + 1) % vertices.length];
      final middle = Offset(
        (vertices[vertex].dx + next.dx) / 2,
        (vertices[vertex].dy + next.dy) / 2,
      );
      path.quadraticBezierTo(next.dx, next.dy, middle.dx, middle.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      _markingPaint(layout, _markingColor(layout), .27, softnessFactor: 2.6),
    );
  }
}

void _paintPearlMarking(
  Canvas canvas,
  Rect bodyBounds,
  CustomFishPatternLayout layout,
) {
  final baseRadius = bodyBounds.shortestSide * 0.038 * layout.markingScale;
  for (var index = 0; index < layout.markingAnchors.length; index++) {
    final anchor = _bodyPoint(bodyBounds, layout.markingAnchors[index]);
    final pulse = 0.65 + ((index + 1) % 4) * 0.11;
    canvas.drawCircle(
      anchor,
      baseRadius * pulse,
      _markingPaint(layout, _markingColor(layout), 0.43, softnessFactor: 1.6),
    );
  }
}

void _paintTigerMarking(
  Canvas canvas,
  Rect bodyBounds,
  CustomFishPatternLayout layout,
) {
  final count = layout.markingAnchors.length;
  // Keep a visible gap even at the highest density. A fixed wide brush made
  // adjacent bands merge into the rectangular brown block in the screenshots.
  final halfWidth =
      bodyBounds.width *
      math.min(.022, .12 / math.max(1, count - 1)) *
      layout.markingScale.clamp(.75, 1.10);
  for (var index = 0; index < layout.markingAnchors.length; index++) {
    final anchor = _bodyPoint(bodyBounds, layout.markingAnchors[index]);
    final variation = math.sin(
      (layout.markingPhase + index * .23) * math.pi * 2,
    );
    final top =
        bodyBounds.top + bodyBounds.height * (.10 + .04 * variation.abs());
    final bottom =
        bodyBounds.bottom -
        bodyBounds.height * (.10 + .04 * (1 - variation.abs()));
    final sway = bodyBounds.width * .007 * variation;
    final path = Path()
      ..moveTo(anchor.dx - halfWidth * .55, top)
      ..cubicTo(
        anchor.dx - halfWidth + sway,
        anchor.dy - bodyBounds.height * .14,
        anchor.dx - halfWidth - sway,
        anchor.dy + bodyBounds.height * .13,
        anchor.dx - halfWidth * .22 + sway,
        bottom,
      )
      ..cubicTo(
        anchor.dx + halfWidth * .18 + sway,
        bottom - bodyBounds.height * .04,
        anchor.dx + halfWidth + sway,
        anchor.dy + bodyBounds.height * .13,
        anchor.dx + halfWidth * .62,
        top,
      )
      ..cubicTo(
        anchor.dx + halfWidth * .20,
        top - bodyBounds.height * .025,
        anchor.dx - halfWidth * .16,
        top - bodyBounds.height * .02,
        anchor.dx - halfWidth * .55,
        top,
      )
      ..close();
    canvas.drawPath(
      path,
      _markingPaint(layout, _markingColor(layout), .57, softnessFactor: 1.2),
    );
  }
}

void _paintZebraMarking(
  Canvas canvas,
  Rect bodyBounds,
  CustomFishPatternLayout layout,
) {
  final lineCount = layout.markingDensity > 1.25 ? 3 : 2;
  final left = bodyBounds.left + bodyBounds.width * .31;
  final right = bodyBounds.right - bodyBounds.width * .09;
  for (var index = 0; index < lineCount; index++) {
    final y =
        bodyBounds.top +
        bodyBounds.height * (.39 + index * (lineCount == 3 ? .11 : .17));
    final wave =
        bodyBounds.height *
        (.025 + .014 * math.sin(layout.markingPhase * 6.28 + index));
    final thickness = bodyBounds.height * .026 * layout.markingScale;
    final path = Path()
      ..moveTo(left, y)
      ..cubicTo(
        left + bodyBounds.width * .20,
        y - wave,
        right - bodyBounds.width * .20,
        y + wave,
        right,
        y,
      )
      ..cubicTo(
        right - bodyBounds.width * .22,
        y + wave + thickness,
        left + bodyBounds.width * .18,
        y - wave + thickness,
        left,
        y,
      )
      ..close();
    canvas.drawPath(
      path,
      _markingPaint(layout, _markingColor(layout), .48, softnessFactor: 1.15),
    );
  }
}

void _paintNeonMarking(
  Canvas canvas,
  Rect bodyBounds,
  CustomFishPatternLayout layout,
) {
  final anchor = _bodyPoint(bodyBounds, layout.markingAnchors.single);
  final left = bodyBounds.left + bodyBounds.width * .28;
  final right = bodyBounds.right - bodyBounds.width * .11;
  final thickness = bodyBounds.height * .042 * layout.markingScale;
  final path = Path()
    ..moveTo(left, anchor.dy)
    ..cubicTo(
      left + bodyBounds.width * .18,
      anchor.dy - bodyBounds.height * .055,
      right - bodyBounds.width * .18,
      anchor.dy + bodyBounds.height * .035,
      right,
      anchor.dy,
    );
  canvas.drawPath(
    path,
    _markingPaint(layout, _markingColor(layout), .24, softnessFactor: 2.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness * 2.3
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawPath(
    path,
    _markingPaint(layout, _markingColor(layout), .58, softnessFactor: .65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round,
  );
}

void _paintSaddleMarking(
  Canvas canvas,
  Rect bodyBounds,
  CustomFishPatternLayout layout,
) {
  final count = layout.markingAnchors.length;
  final width =
      bodyBounds.width *
      math.min(.058, .24 / math.max(1, count - 1)) *
      layout.markingScale.clamp(.78, 1.18);
  for (var index = 0; index < layout.markingAnchors.length; index++) {
    final anchor = _bodyPoint(bodyBounds, layout.markingAnchors[index]);
    final phase = layout.markingPhase * 6.28 + index * 1.53;
    final crown =
        bodyBounds.top + bodyBounds.height * (.17 + .02 * math.sin(phase));
    final depth = bodyBounds.height * (.25 + .03 * math.cos(phase));
    final path = Path()
      ..moveTo(anchor.dx - width * .50, crown)
      ..cubicTo(
        anchor.dx - width * .38,
        crown - bodyBounds.height * .035,
        anchor.dx,
        crown - bodyBounds.height * .025,
        anchor.dx + width * .52,
        crown,
      )
      ..cubicTo(
        anchor.dx + width * .42,
        crown + depth * .43,
        anchor.dx + width * .12,
        crown + depth * .88,
        anchor.dx + width * .05,
        crown + depth,
      )
      ..cubicTo(
        anchor.dx - width * .10,
        crown + depth * .89,
        anchor.dx - width * .42,
        crown + depth * .43,
        anchor.dx - width * .50,
        crown,
      )
      ..close();
    canvas.drawPath(
      path,
      _markingPaint(layout, _markingColor(layout), .63, softnessFactor: 1.15),
    );
  }
}

void _paintWaveMarking(
  Canvas canvas,
  Rect bodyBounds,
  CustomFishPatternLayout layout,
) {
  final lineCount = layout.markingDensity > 1.25 ? 4 : 3;
  final left = bodyBounds.left + bodyBounds.width * .29;
  final right = bodyBounds.right - bodyBounds.width * .11;
  final color = _markingColor(layout);
  for (var index = 0; index < lineCount; index++) {
    final fraction = (index + 1) / (lineCount + 1);
    final x = left + (right - left) * fraction;
    final amplitude =
        bodyBounds.width *
        (.072 + .010 * math.sin(layout.markingPhase * 6.28 + index));
    final top = bodyBounds.top + bodyBounds.height * .18;
    final bottom = bodyBounds.bottom - bodyBounds.height * .17;
    final path = Path()
      ..moveTo(x, top)
      ..cubicTo(
        x + amplitude,
        top + bodyBounds.height * .18,
        x - amplitude,
        top + bodyBounds.height * .36,
        x + amplitude * .22,
        top + bodyBounds.height * .51,
      )
      ..cubicTo(
        x - amplitude,
        bottom - bodyBounds.height * .23,
        x + amplitude,
        bottom - bodyBounds.height * .08,
        x,
        bottom,
      );
    canvas.drawPath(
      path,
      _markingPaint(layout, color, .19, softnessFactor: 2.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = bodyBounds.shortestSide * .115 * layout.markingScale
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      _markingPaint(layout, color, .62, softnessFactor: .72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = bodyBounds.shortestSide * .040 * layout.markingScale
        ..strokeCap = StrokeCap.round,
    );
  }
}

void _paintBellyMarking(
  Canvas canvas,
  Rect bodyBounds,
  CustomFishPatternLayout layout,
) {
  // Diffuse countershading dies away before the hand-audited torso mask's
  // internal edge. A full-height linear gradient exposed that mask's angular
  // inset as a pale triangle on wide bodies.
  final cream = _markingColor(layout);
  final center = Offset(
    bodyBounds.left +
        bodyBounds.width *
            (.55 + .025 * math.sin(layout.markingPhase * math.pi * 2)),
    bodyBounds.top + bodyBounds.height * .77,
  );
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(bodyBounds.width * .46, bodyBounds.height * .34);
  canvas.drawCircle(
    Offset.zero,
    1,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1,
        [
          cream.withValues(alpha: .48),
          cream.withValues(alpha: .32),
          cream.withValues(alpha: .07),
          cream.withValues(alpha: 0),
        ],
        [0, .30, .62, 1],
      ),
  );
  canvas.restore();
}

// The selected direction is a body-relative watercolor treatment. Direction 1
// is the approved default; 0 remains available solely to compare the retired
// renderer in /prototype/fish-patterns.
void _paintStudyBodyMarking(
  Canvas canvas,
  Rect bounds,
  CustomFishPatternLayout layout,
  int direction,
) {
  final variant = direction.clamp(1, 3);
  final base = HSLColor.fromColor(layout.baseColor);
  final light = base
      .withSaturation((base.saturation * .64).clamp(.24, .68))
      .withLightness((base.lightness + .16).clamp(.60, .78))
      .toColor();
  final dark = base
      .withSaturation((base.saturation * .78).clamp(.42, .82))
      .withLightness((base.lightness * .47).clamp(.18, .36))
      .toColor();
  final mid = base
      .withSaturation((base.saturation * .88).clamp(.43, .85))
      .withLightness((base.lightness * .68).clamp(.29, .50))
      .toColor();
  final softness = switch (variant) {
    1 => 3.2,
    2 => .85,
    _ => .35,
  };
  // The workspace sliders remain meaningful after committing direction A:
  // density changes motif count within a deliberately narrow natural range,
  // while softness adjusts the watercolor edge without losing its silhouette.
  final densityTuning = ((layout.markingDensity - .62) / 1.16).clamp(0.0, 1.0);
  final softnessScale = .58 + layout.markingSoftness * .92;
  final phase = layout.markingPhase * math.pi * 2;
  Offset at(double x, double y) =>
      Offset(bounds.left + x * bounds.width, bounds.top + y * bounds.height);
  Paint pigment(Color color, double opacity, {double blur = 0}) => Paint()
    ..color = color.withValues(alpha: opacity)
    ..isAntiAlias = true
    ..maskFilter = blur <= .25
        ? null
        : MaskFilter.blur(BlurStyle.normal, blur * softnessScale);

  switch (layout.patternId) {
    case 'cloud':
      final cloudTint = base
          .withSaturation((base.saturation * .95).clamp(.56, .90))
          .withLightness((base.lightness + .07).clamp(.57, .74))
          .toColor();
      final washes = switch (variant) {
        1 => <(double, double, double, double, double)>[
          (.38, .30, .14, .13, .38),
          (.67, .61, .15, .13, .35),
        ],
        2 => <(double, double, double, double, double)>[
          (.34, .34, .11, .14, .73),
          (.45, .52, .12, .15, .69),
          (.56, .32, .11, .13, .67),
          (.68, .55, .13, .16, .70),
          (.80, .36, .11, .14, .66),
        ],
        _ => <(double, double, double, double, double)>[
          (.38, .30, .14, .13, .44),
          (.68, .62, .15, .13, .41),
        ],
      };
      if (variant != 2) {
        final cloudPath = Path()
          ..moveTo(at(.27, .40).dx, at(.27, .40).dy)
          ..cubicTo(
            at(.38, .18).dx,
            at(.38, .18).dy,
            at(.46, .27).dx,
            at(.46, .27).dy,
            at(.55, .39).dx,
            at(.55, .39).dy,
          )
          ..cubicTo(
            at(.67, .54).dx,
            at(.67, .54).dy,
            at(.72, .18).dx,
            at(.72, .18).dy,
            at(.88, .29).dx,
            at(.88, .29).dy,
          )
          ..cubicTo(
            at(.83, .47).dx,
            at(.83, .47).dy,
            at(.74, .45).dx,
            at(.74, .45).dy,
            at(.66, .63).dx,
            at(.66, .63).dy,
          )
          ..cubicTo(
            at(.53, .78).dx,
            at(.53, .78).dy,
            at(.45, .47).dx,
            at(.45, .47).dy,
            at(.27, .61).dx,
            at(.27, .61).dy,
          )
          ..close();
        canvas.drawPath(
          cloudPath,
          pigment(
            cloudTint,
            variant == 1 ? .54 : .69,
            blur: variant == 1 ? 4.2 : 2.1,
          ),
        );
      }
      for (final wash in washes) {
        _paintStudyWash(
          canvas,
          at(wash.$1, wash.$2),
          bounds.width * wash.$3,
          bounds.height * wash.$4,
          cloudTint,
          wash.$5,
        );
      }
      break;
    case 'pearl':
      final columns = variant == 1
          ? 4 + (densityTuning * 3).round()
          : variant == 3
          ? 4
          : 6;
      final rows = variant == 1 ? 2 : 3;
      for (var row = 0; row < rows; row++) {
        for (var col = 0; col < columns; col++) {
          final x = .29 + col * (.55 / (columns - 1)) + (row.isOdd ? .035 : 0);
          final y =
              .27 +
              row * (rows == 2 ? .34 : .23) +
              .025 * math.sin(phase + col * 1.3);
          final radius =
              bounds.height *
              (variant == 3 ? .062 : (variant == 2 ? .043 : .052)) *
              (1 + .17 * math.sin(col + row * 2));
          final center = at(x, y);
          if (variant != 1) {
            canvas.drawCircle(center, radius * 1.34, pigment(mid, .57));
          }
          canvas.drawCircle(
            center,
            radius,
            pigment(light, variant == 1 ? .88 : 1, blur: variant == 1 ? .6 : 0),
          );
        }
      }
      break;
    case 'tiger':
      // A needs to remain softly painted, but the alternating vertical bands
      // must still read at a card-sized preview.  Four broader, irregular
      // bands communicate "tiger" much more clearly than five faint slivers.
      final count = variant == 1
          ? 3 + (densityTuning * 2).round()
          : variant == 3
          ? 4
          : 5;
      for (var i = 0; i < count; i++) {
        final x =
            (variant == 1 ? .34 : .32) +
            i * ((variant == 1 ? .48 : .51) / (count - 1));
        final drift = .03 * math.sin(phase + i * 1.9);
        final width = switch (variant) {
          1 => .054,
          3 => .043,
          _ => .030,
        };
        final lowerEnd = variant == 1
            ? [.79, .70, .84, .73][i % 4]
            : variant == 2 && i.isOdd
            ? .69
            : .86;
        final top = at(x - width, .20);
        final path = Path()
          ..moveTo(top.dx, top.dy)
          ..cubicTo(
            at(x - width * .9, .32).dx,
            at(x - width * .9, .32).dy,
            at(x + drift - width * .45, .63).dx,
            at(x + drift - width * .45, .63).dy,
            at(x + drift, lowerEnd).dx,
            at(x + drift, lowerEnd).dy,
          )
          ..cubicTo(
            at(x + width * .7, .68).dx,
            at(x + width * .7, .68).dy,
            at(x + width, .36).dx,
            at(x + width, .36).dy,
            at(x + width, .20).dx,
            at(x + width, .20).dy,
          )
          ..quadraticBezierTo(
            at(x + drift * .2, .14 + .015 * math.sin(i * 1.7)).dx,
            at(x + drift * .2, .14 + .015 * math.sin(i * 1.7)).dy,
            top.dx,
            top.dy,
          )
          ..close();
        canvas.drawPath(
          path,
          pigment(
            dark,
            variant == 1 ? .84 : .82,
            blur: variant == 1 ? 1.35 : softness,
          ),
        );
      }
      break;
    case 'zebra':
      // Multiple, parallel lateral bands make this visibly different from
      // the single neon ribbon even when the fish is thumbnail-sized.
      final lines = variant == 1 ? 3 + (densityTuning > .55 ? 1 : 0) : 3;
      for (var i = 0; i < lines; i++) {
        final y = variant == 1 ? .25 + i * .17 : .31 + i * .20;
        final path = Path()
          ..moveTo(
            at(variant == 1 ? .25 : .28, y).dx,
            at(variant == 1 ? .25 : .28, y).dy,
          )
          ..cubicTo(
            at(.46, y - (variant == 1 ? .035 : .06)).dx,
            at(.46, y - (variant == 1 ? .035 : .06)).dy,
            at(.64, y + (variant == 1 ? .025 : .045)).dx,
            at(.64, y + (variant == 1 ? .025 : .045)).dy,
            at(.88, y - (variant == 1 ? .015 : .025)).dx,
            at(.88, y - (variant == 1 ? .015 : .025)).dy,
          );
        canvas.drawPath(
          path,
          pigment(
              dark,
              variant == 1 ? .84 : .88,
              blur: variant == 1 ? 1.15 : softness,
            )
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = bounds.height * (variant == 1 ? .054 : .055),
        );
      }
      break;
    case 'neon':
      final path = Path()
        ..moveTo(at(.26, .51).dx, at(.26, .51).dy)
        ..cubicTo(
          at(.47, .43).dx,
          at(.47, .43).dy,
          at(.66, .54).dx,
          at(.66, .54).dy,
          at(.88, .48).dx,
          at(.88, .48).dy,
        );
      final aqua = Color.lerp(const Color(0xFF36C8D6), light, .16)!;
      canvas.drawPath(
        path,
        pigment(dark, .72, blur: .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = bounds.height * (variant == 3 ? .17 : .13)
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path,
        pigment(aqua, .40, blur: variant == 1 ? 3 : 1.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = bounds.height * .19
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path,
        pigment(const Color(0xFFB5FFF1), .98)
          ..style = PaintingStyle.stroke
          ..strokeWidth = bounds.height * (variant == 3 ? .055 : .032)
          ..strokeCap = StrokeCap.round,
      );
      if (variant == 2) {
        for (var i = 0; i < 7; i++) {
          canvas.drawCircle(
            at(.32 + i * .077, .50 + .035 * math.sin(i * 1.5)),
            bounds.height * .026,
            pigment(light, .88),
          );
        }
      }
      break;
    case 'saddle':
      final count = variant == 1 ? 1 + (densityTuning > .46 ? 1 : 0) : 3;
      for (var i = 0; i < count; i++) {
        final x = variant == 1
            ? .43 + i * .34
            : .43 + i * (count == 2 ? .34 : .22);
        final w = variant == 1 ? .17 : (variant == 3 ? .14 : .13);
        final lowestPoint = variant == 1 ? .64 : .52;
        final path = Path()
          ..moveTo(at(x - w, .20).dx, at(x - w, .20).dy)
          ..cubicTo(
            at(x - w * .55, .15).dx,
            at(x - w * .55, .15).dy,
            at(x + w * .55, .15).dx,
            at(x + w * .55, .15).dy,
            at(x + w, .20).dx,
            at(x + w, .20).dy,
          )
          ..cubicTo(
            at(x + w * .93, variant == 1 ? .48 : .40).dx,
            at(x + w * .93, variant == 1 ? .48 : .40).dy,
            at(x + w * .45, variant == 1 ? .59 : .49).dx,
            at(x + w * .45, variant == 1 ? .59 : .49).dy,
            at(x, lowestPoint).dx,
            at(x, lowestPoint).dy,
          )
          ..cubicTo(
            at(x - w * .48, variant == 1 ? .59 : .49).dx,
            at(x - w * .48, variant == 1 ? .59 : .49).dy,
            at(x - w * .96, variant == 1 ? .48 : .40).dx,
            at(x - w * .96, variant == 1 ? .48 : .40).dy,
            at(x - w, .20).dx,
            at(x - w, .20).dy,
          )
          ..close();
        canvas.drawPath(
          path,
          pigment(
            dark,
            variant == 1 ? .82 : .85,
            blur: variant == 1 ? 1.45 : softness,
          ),
        );
      }
      break;
    case 'wave':
      // These bands grow from back to belly, perpendicular to the fish's
      // travel direction. Their S-shaped rhythm stays distinct from the
      // straighter tiger bars and horizontal zebra lines.
      // The wave's vertical rhythm carries its identity. Its pigment is a
      // deeper, slightly concentrated version of the selected body colour,
      // so it follows every watercolor choice rather than staying blue-cyan.
      final waveTone = base
          .withSaturation((base.saturation * .90).clamp(.42, .84))
          .withLightness((base.lightness * .48).clamp(.18, .42))
          .toColor();
      final lineCount = variant == 1
          ? 2 + (densityTuning > .62 ? 1 : 0)
          : variant == 2
          ? 4
          : 3;
      for (var i = 0; i < lineCount; i++) {
        final x = lineCount == 2
            ? .39 + i * .24
            : lineCount == 3
            ? .35 + i * .20
            : .30 + i * .16;
        final amplitude = .076 + .010 * math.sin(phase + i * 1.7);
        final path = Path()
          ..moveTo(at(x, .18).dx, at(x, .18).dy)
          ..cubicTo(
            at(x + amplitude, .34).dx,
            at(x + amplitude, .34).dy,
            at(x - amplitude, .48).dx,
            at(x - amplitude, .48).dy,
            at(x + amplitude * .18, .58).dx,
            at(x + amplitude * .18, .58).dy,
          )
          ..cubicTo(
            at(x - amplitude, .70).dx,
            at(x - amplitude, .70).dy,
            at(x + amplitude, .80).dx,
            at(x + amplitude, .80).dy,
            at(x, .85).dx,
            at(x, .85).dy,
          );
        canvas.drawPath(
          path,
          pigment(
              waveTone,
              variant == 1 ? .38 : .42,
              blur: variant == 1 ? 3.1 : 1.7,
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = bounds.width * (variant == 1 ? .085 : .072)
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawPath(
          path,
          pigment(
              waveTone,
              variant == 1 ? .86 : .88,
              blur: variant == 1 ? .8 : .35,
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = bounds.width * (variant == 1 ? .030 : .034)
            ..strokeCap = StrokeCap.round,
        );
      }
      break;
    case 'belly':
      // A broad, soft ventral countershade; the study mask uses the sprite
      // silhouette so the inset torso mask cannot reveal an angular edge.
      canvas.save();
      final center = at(.58, variant == 3 ? .79 : .77);
      canvas.translate(center.dx, center.dy);
      canvas.scale(bounds.width * .58, bounds.height * .29);
      canvas.drawCircle(
        Offset.zero,
        1,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            1,
            [
              light.withValues(alpha: variant == 3 ? .88 : .73),
              light.withValues(alpha: variant == 1 ? .52 : .63),
              light.withValues(alpha: 0),
            ],
            [0, .43, .76],
          )
          ..isAntiAlias = true,
      );
      canvas.restore();
      break;
  }
}

void _paintStudyWash(
  Canvas canvas,
  Offset center,
  double radiusX,
  double radiusY,
  Color color,
  double opacity,
) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(radiusX, radiusY);
  canvas.drawCircle(
    Offset.zero,
    1,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1,
        [
          color.withValues(alpha: opacity),
          color.withValues(alpha: opacity * .72),
          color.withValues(alpha: 0),
        ],
        [0, .48, 1],
      )
      ..isAntiAlias = true,
  );
  canvas.restore();
}
