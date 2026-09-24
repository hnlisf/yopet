import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/fish/custom_fish_sprite.dart';
import 'package:yopet/features/fish/fish_models.dart';

void main() {
  test('round body with a petal tail keeps cloud pattern off its eye', () {
    final layout = customFishPatternLayout(
      body: customFishBodyForId('round'),
      tail: customFishTailForId('petal'),
      pattern: customFishPatternForId('cloud'),
    );

    expect(
      layout.faceProtectionEnd,
      greaterThanOrEqualTo(0.30),
      reason:
          'round + petal + cloud leaves the eye inside the watercolor '
          'overlay',
    );
    expect(
      layout.tailOpacity,
      0,
      reason: 'round + petal + cloud must not paint the caudal fin',
    );
  });

  test('every watercolor pattern stays on an adaptive body region', () {
    for (final body in customFishBodies) {
      for (final tail in customFishTails) {
        for (final pattern in customFishPatterns) {
          final layout = customFishPatternLayout(
            body: body,
            tail: tail,
            pattern: pattern,
          );

          expect(
            layout.faceProtectionEnd,
            greaterThanOrEqualTo(0.30),
            reason:
                '${body.id} + ${tail.id} + ${pattern.id} leaves the eye '
                'inside the watercolor overlay',
          );
          expect(
            layout.tailOpacity,
            0,
            reason:
                '${body.id} + ${tail.id} + ${pattern.id} must keep '
                'patterning off the tail and fins',
          );
          expect(
            layout.bodyBounds.right,
            lessThanOrEqualTo(0.74),
            reason:
                '${body.id} + ${tail.id} + ${pattern.id} lets the body '
                'pattern reach the caudal fin area',
          );
          expect(layout.bodyBounds.width, greaterThan(0));
          expect(layout.bodyBounds.height, greaterThan(0));
          expect(layout.markingAnchors, isNotEmpty);
        }
      }
    }
  });

  test('body shapes receive different pattern regions and marking anchors', () {
    final round = customFishPatternLayout(
      body: customFishBodyForId('round'),
      tail: customFishTailForId('petal'),
      pattern: customFishPatternForId('cloud'),
    );
    final eel = customFishPatternLayout(
      body: customFishBodyForId('eel'),
      tail: customFishTailForId('petal'),
      pattern: customFishPatternForId('cloud'),
    );
    final diamond = customFishPatternLayout(
      body: customFishBodyForId('diamond'),
      tail: customFishTailForId('petal'),
      pattern: customFishPatternForId('cloud'),
    );

    expect(round.bodyBounds, isNot(equals(eel.bodyBounds)));
    expect(diamond.bodyBounds.height, isNot(equals(round.bodyBounds.height)));
    expect(round.markingAnchors.first, isNot(equals(eel.markingAnchors.first)));
  });

  test(
    'the same marking grows differently on a disc, torpedo, and eel body',
    () {
      final cloud = customFishPatternForId('cloud');
      final disc = customFishPatternLayout(
        body: customFishBodyForId('disc'),
        tail: customFishTailForId('fan'),
        pattern: cloud,
      );
      final torpedo = customFishPatternLayout(
        body: customFishBodyForId('torpedo'),
        tail: customFishTailForId('fan'),
        pattern: cloud,
      );
      final eel = customFishPatternLayout(
        body: customFishBodyForId('eel'),
        tail: customFishTailForId('fan'),
        pattern: cloud,
      );

      // A natural marking is generated in the fish body's local coordinate
      // system.  It must therefore receive different scale, density and anchor
      // placement on tall, streamlined and very long bodies.  A cropped source
      // texture cannot satisfy this contract.
      expect(disc.markingScale, isNot(equals(torpedo.markingScale)));
      expect(torpedo.markingScale, isNot(equals(eel.markingScale)));
      expect(disc.markingDensity, isNot(equals(eel.markingDensity)));
      expect(
        disc.markingAnchors.first,
        isNot(equals(eel.markingAnchors.first)),
      );
      for (final layout in [disc, torpedo, eel]) {
        expect(layout.markingAnchors, isNotEmpty);
        for (final anchor in layout.markingAnchors) {
          expect(anchor.dx, inInclusiveRange(0.0, 1.0));
          expect(anchor.dy, inInclusiveRange(0.0, 1.0));
        }
      }
    },
  );

  test('disc fan pattern uses an inset torso mask and the sprite alpha', () {
    final layout = customFishPatternLayout(
      body: customFishBodyForId('disc'),
      tail: customFishTailForId('fan'),
      pattern: customFishPatternForId('cloud'),
    );

    // The dorsal and lower fins sit above and below the disc torso, while the
    // tail starts at its right edge.  A generous body ellipse leaks into all
    // three areas, as seen in the original regression screenshot.
    expect(layout.bodyBounds.top, greaterThanOrEqualTo(0.28));
    expect(layout.bodyBounds.bottom, lessThanOrEqualTo(0.72));
    expect(layout.bodyBounds.right, lessThanOrEqualTo(0.60));
    expect(layout.masksToSpriteAlpha, isTrue);
  });

  test('natural marking profiles keep colour on the torso, not the fins', () {
    final diamondSaddle = customFishPatternLayout(
      body: customFishBodyForId('diamond'),
      tail: customFishTailForId('fan'),
      pattern: customFishPatternForId('saddle'),
    );
    final torpedoTiger = customFishPatternLayout(
      body: customFishBodyForId('torpedo'),
      tail: customFishTailForId('fan'),
      pattern: customFishPatternForId('tiger'),
    );
    final roundBelly = customFishPatternLayout(
      body: customFishBodyForId('round'),
      tail: customFishTailForId('fan'),
      pattern: customFishPatternForId('belly'),
    );

    // This is the diamond + fan + saddle regression from the user report.
    // Geometry may now use the complete torso because the dedicated mask—not
    // a small generic rectangle—is the authority that removes every fin.
    expect(diamondSaddle.bodyBounds.top, greaterThanOrEqualTo(0.28));
    expect(diamondSaddle.bodyBounds.bottom, lessThanOrEqualTo(0.70));
    expect(diamondSaddle.markingForm, CustomFishMarkingForm.dorsalSaddles);
    expect(torpedoTiger.markingTone, CustomFishMarkingTone.warmUmber);
    expect(torpedoTiger.markingForm, CustomFishMarkingForm.verticalBands);
    expect(roundBelly.markingForm, CustomFishMarkingForm.lowerCrescent);
    expect(roundBelly.bodyBounds.top, greaterThanOrEqualTo(0.28));
  });

  test('retired eye selection resolves to the replacement wave pattern', () {
    final wave = customFishPatternForId('wave');
    final legacyEye = customFishPatternForId('eye');
    final layout = customFishPatternLayout(
      body: customFishBodyForId('round'),
      tail: customFishTailForId('fan'),
      pattern: wave,
    );

    expect(wave.label, '波浪纹');
    expect(legacyEye.id, 'wave');
    expect(layout.markingForm, CustomFishMarkingForm.waveBands);
    expect(layout.markingTone, CustomFishMarkingTone.bodyDerivedWave);
    expect(layout.markingAnchors.length, greaterThanOrEqualTo(3));
  });

  test('every complete fish row has a dedicated torso-only alpha mask', () {
    for (final body in customFishBodies) {
      for (final tail in customFishTails) {
        final sprite = customFishCompleteSpriteFor(body: body, tail: tail);
        expect(
          File(sprite.torsoMaskAssetPath).existsSync(),
          isTrue,
          reason:
              '${body.id} + ${tail.id} needs a torso mask that excludes every fin',
        );
        expect(sprite.torsoMaskAssetPath, contains('/masks/'));
      }
    }
  });

  test(
    'all body, tail, pattern, and colour combinations honor skin bounds',
    () {
      var combinations = 0;
      for (final body in customFishBodies) {
        for (final tail in customFishTails) {
          for (final pattern in customFishPatterns) {
            for (final colour in customFishColors) {
              final layout = customFishPatternLayout(
                body: body,
                tail: tail,
                pattern: pattern,
                baseColor: colour.color,
              );
              combinations++;
              expect(layout.baseColor, colour.color);
              expect(layout.masksToSpriteAlpha, isTrue);
              expect(layout.tailOpacity, 0);
              expect(layout.bodyBounds.right, lessThanOrEqualTo(.74));
              for (final anchor in layout.markingAnchors) {
                expect(
                  anchor.dx,
                  inInclusiveRange(.34, .84),
                  reason:
                      '${body.id}/${tail.id}/${pattern.id}/${colour.id} '
                      'must leave the face and tail root unpainted',
                );
              }
            }
          }
        }
      }
      expect(combinations, 8 * 3 * 8 * 12);
    },
  );

  test(
    'density, softness, and fish seed change biology rather than a decal',
    () {
      final body = customFishBodyForId('torpedo');
      final tail = customFishTailForId('fan');
      final pattern = customFishPatternForId('tiger');
      final sparse = customFishPatternLayout(
        body: body,
        tail: tail,
        pattern: pattern,
        tuning: const CustomFishPatternTuning(
          density: .08,
          softness: .16,
          individualSeed: 7,
        ),
      );
      final dense = customFishPatternLayout(
        body: body,
        tail: tail,
        pattern: pattern,
        tuning: const CustomFishPatternTuning(
          density: .92,
          softness: .84,
          individualSeed: 31,
        ),
      );

      expect(
        dense.markingAnchors.length,
        greaterThan(sparse.markingAnchors.length),
      );
      expect(dense.markingDensity, greaterThan(sparse.markingDensity));
      expect(dense.markingSoftness, .84);
      expect(sparse.markingSoftness, .16);
      expect(dense.markingPhase, isNot(sparse.markingPhase));
      expect(dense.markingAnchors.first, isNot(sparse.markingAnchors.first));
    },
  );
}
