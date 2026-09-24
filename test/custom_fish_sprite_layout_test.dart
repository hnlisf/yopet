import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/fish/custom_fish_sprite.dart';
import 'package:yopet/features/fish/fish_models.dart';

void main() {
  test('every body and tail choice resolves to a complete sprite sheet', () {
    for (final body in customFishBodies) {
      for (final tail in customFishTails) {
        final sprite = customFishCompleteSpriteFor(body: body, tail: tail);

        expect(
          File(sprite.assetPath).existsSync(),
          isTrue,
          reason:
              '${body.id} + ${tail.id} has no complete fish artwork to render',
        );
        expect(
          sprite.assetPath,
          contains('assets/custom_fish/complete/'),
          reason:
              '${body.id} + ${tail.id} falls back to a separately composited '
              'body or tail asset',
        );
      }
    }
  });

  test('petal, fan, and ribbon tails select different whole-fish rows', () {
    final body = customFishBodyForId('disc');

    expect(
      customFishCompleteSpriteFor(
        body: body,
        tail: customFishTailForId('petal'),
      ).row,
      0,
    );
    expect(
      customFishCompleteSpriteFor(
        body: body,
        tail: customFishTailForId('petal'),
      ).rows,
      1,
    );
    expect(
      customFishCompleteSpriteFor(
        body: body,
        tail: customFishTailForId('fan'),
      ).row,
      1,
    );
    expect(
      customFishCompleteSpriteFor(
        body: body,
        tail: customFishTailForId('ribbon'),
      ).row,
      2,
    );
  });

  test(
    'disc petal whole-fish artwork has a genuinely transparent backdrop',
    () async {
      final sprite = customFishCompleteSpriteFor(
        body: customFishBodyForId('disc'),
        tail: customFishTailForId('petal'),
      );
      final encoded = await File(sprite.assetPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(encoded);
      addTearDown(codec.dispose);
      final image = (await codec.getNextFrame()).image;
      addTearDown(image.dispose);
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

      int alphaAt(int x, int y) =>
          rgba!.getUint8(((y * image.width) + x) * 4 + 3);

      // The fish needs to work on every aquarium background.  An opaque
      // checkerboard at these corners is a generated-asset defect, not a UI
      // background, and would follow the fish into the tank.
      expect(alphaAt(0, 0), 0);
      expect(alphaAt(image.width - 1, 0), 0);
      expect(alphaAt(0, image.height - 1), 0);
      expect(alphaAt(image.width - 1, image.height - 1), 0);
    },
  );

  test(
    'every complete whole-fish sheet has transparent outer corners',
    () async {
      final uniqueSprites = <String, CustomFishCompleteSprite>{
        for (final body in customFishBodies)
          for (final tail in customFishTails)
            customFishCompleteSpriteFor(body: body, tail: tail).assetPath:
                customFishCompleteSpriteFor(body: body, tail: tail),
      };

      for (final sprite in uniqueSprites.values) {
        final encoded = await File(sprite.assetPath).readAsBytes();
        final codec = await ui.instantiateImageCodec(encoded);
        addTearDown(codec.dispose);
        final image = (await codec.getNextFrame()).image;
        addTearDown(image.dispose);
        final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        int alphaAt(int x, int y) =>
            rgba!.getUint8(((y * image.width) + x) * 4 + 3);

        expect(alphaAt(0, 0), 0, reason: '${sprite.assetPath} top-left');
        expect(
          alphaAt(image.width - 1, 0),
          0,
          reason: '${sprite.assetPath} top-right',
        );
        expect(
          alphaAt(0, image.height - 1),
          0,
          reason: '${sprite.assetPath} bottom-left',
        );
        expect(
          alphaAt(image.width - 1, image.height - 1),
          0,
          reason: '${sprite.assetPath} bottom-right',
        );
      }
    },
  );

  testWidgets('a recoloured fish keeps a transparent backdrop and blue skin', (
    tester,
  ) async {
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: const CustomFishSprite(
              appearance: CustomFishAppearance(
                body: 'disc',
                tail: 'fan',
                pattern: 'belly',
                color: 'blue',
              ),
              width: 240,
            ),
          ),
        ),
      ),
    );
    // AssetImage decoding and RenderRepaintBoundary.toImage use real engine
    // futures; let them complete outside the widget test's fake clock.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
    expect(image, isNotNull);
    final rendered = image!;
    addTearDown(rendered.dispose);
    final rgba = await tester.runAsync(
      () => rendered.toByteData(format: ui.ImageByteFormat.rawRgba),
    );

    int channel(int x, int y, int component) =>
        rgba!.getUint8(((y * rendered.width) + x) * 4 + component);

    expect(channel(0, 0, 3), 0);
    // A filtered edge pixel can have faint antialiasing, but a tint-coloured
    // rectangle would remain fully opaque across the entire backdrop.
    expect(channel(rendered.width - 1, rendered.height - 1, 3), lessThan(64));
    expect(channel(96, 80, 3), greaterThan(150));
    expect(channel(96, 80, 2), greaterThan(channel(96, 80, 0)));
  });

  for (final (tail, membraneY, minimumMembraneAlpha) in <(String, double, int)>[
    ('fan', .50, 120),
    ('petal', .40, 130),
    ('ribbon', .32, 90),
  ]) {
    testWidgets('the $tail membrane transmits water but the skin stays solid', (
      tester,
    ) async {
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: CustomFishSprite(
                appearance: CustomFishAppearance(
                  body: 'disc',
                  tail: tail,
                  pattern: 'zebra',
                  color: 'orange',
                ),
                width: 240,
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await tester.runAsync(
        () => boundary.toImage(pixelRatio: 1),
      );
      expect(image, isNotNull);
      final rendered = image!;
      addTearDown(rendered.dispose);
      final rgba = await tester.runAsync(
        () => rendered.toByteData(format: ui.ImageByteFormat.rawRgba),
      );

      int alphaAt(double x, double y) {
        final px = (x * rendered.width).round();
        final py = (y * rendered.height).round();
        return rgba!.getUint8(((py * rendered.width) + px) * 4 + 3);
      }

      final torso = alphaAt(.42, .50);
      final tailRoot = alphaAt(.61, .50);
      final tailMembrane = alphaAt(.80, membraneY);
      expect(torso, greaterThan(240));
      expect(tailRoot, greaterThan(220));
      expect(tailMembrane, lessThan(torso - 60));
      expect(tailMembrane, greaterThan(minimumMembraneAlpha));
      if (tail == 'petal') {
        expect(alphaAt(.43, .29), greaterThan(220)); // upper shoulder
      }
    });
  }

  for (final (body, tail, dorsalX, dorsalY, ventralX, ventralY)
      in <(String, String, double, double, double, double)>[
        ('diamond', 'fan', .38, .271, .45, .692),
        ('disc', 'petal', .43, .200, .30, .750),
      ]) {
    testWidgets('$body $tail fins have no abrupt horizontal opacity seam', (
      tester,
    ) async {
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: CustomFishSprite(
                appearance: CustomFishAppearance(
                  body: body,
                  tail: tail,
                  pattern: 'pearl',
                  color: 'orange',
                ),
                width: 240,
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await tester.runAsync(
        () => boundary.toImage(pixelRatio: 1),
      );
      final rendered = image!;
      addTearDown(rendered.dispose);
      final rgba = await tester.runAsync(
        () => rendered.toByteData(format: ui.ImageByteFormat.rawRgba),
      );

      int alphaAt(double x, double y) {
        final px = (x * rendered.width).round();
        final py = (y * rendered.height).round();
        return rgba!.getUint8(((py * rendered.width) + px) * 4 + 3);
      }

      final dorsalJump =
          (alphaAt(dorsalX, dorsalY - .005) - alphaAt(dorsalX, dorsalY + .005))
              .abs();
      final ventralJump =
          (alphaAt(ventralX, ventralY - .005) -
                  alphaAt(ventralX, ventralY + .005))
              .abs();
      expect(dorsalJump, lessThan(35));
      expect(ventralJump, lessThan(35));
    });
  }
}
