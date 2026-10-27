import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A continuous deformation: the torso is fixed, fin tips carry the motion.
Offset fishFinOffset(Offset point, Rect body, double phase, double strength) {
  final tail = ((point.dx - body.right) / (1 - body.right)).clamp(0.0, 1.0);
  final dorsal = ((body.top - point.dy) / body.top).clamp(0.0, 1.0);
  final ventral = ((point.dy - body.bottom) / (1 - body.bottom)).clamp(
    0.0,
    1.0,
  );
  final finWindow = point.dx >= body.left && point.dx <= body.right ? 1.0 : 0.0;
  // In side view, lateral tail beats are seen as foreshortening and unfolding,
  // not as a vertical wag. Keep the root pinned and let the membrane fold.
  final beat = math.sin(phase);
  final fold = (beat + 1) / 2;
  final tailWeight = tail * tail;
  final center = body.center.dy;
  return Offset(
    -.095 * fold * tailWeight * strength +
        .012 * math.sin(phase - tail * 1.8) * tailWeight * strength +
        math.sin(phase * 1.25 + point.dy * 2) *
            .035 *
            (dorsal * dorsal + ventral * ventral) *
            finWindow *
            strength,
    -(point.dy - center) * .26 * fold * tailWeight * strength +
        math.sin(phase - tail * 2.1) * .006 * tailWeight * strength,
  );
}

class FishFinMeshPainter extends CustomPainter {
  const FishFinMeshPainter({
    required this.image,
    required this.body,
    required this.phase,
    required this.strength,
    this.tint,
  });
  final ui.Image image;
  final Rect body;
  final double phase;
  final double strength;
  final Color? tint;

  @override
  void paint(Canvas canvas, Size size) {
    const columns = 32;
    const rows = 24;
    final positions = <Offset>[];
    final texture = <Offset>[];
    final indices = <int>[];
    for (var y = 0; y <= rows; y++) {
      for (var x = 0; x <= columns; x++) {
        final point = Offset(x / columns, y / rows);
        final offset = fishFinOffset(point, body, phase, strength);
        positions.add(
          Offset(
            (point.dx + offset.dx) * size.width,
            (point.dy + offset.dy) * size.height,
          ),
        );
        texture.add(Offset(point.dx * image.width, point.dy * image.height));
        if (x < columns && y < rows) {
          final a = y * (columns + 1) + x;
          indices.addAll([
            a,
            a + 1,
            a + columns + 1,
            a + 1,
            a + columns + 2,
            a + columns + 1,
          ]);
        }
      }
    }
    final vertices = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texture,
      indices: indices,
    );
    final paint = Paint()
      ..shader = ImageShader(
        image,
        TileMode.clamp,
        TileMode.clamp,
        Matrix4.identity().storage,
      )
      ..filterQuality = FilterQuality.medium;
    if (tint != null) {
      paint.colorFilter = ColorFilter.mode(tint!, BlendMode.modulate);
    }
    canvas.save();
    canvas.clipRect((Offset.zero & size).deflate(1), doAntiAlias: false);
    canvas.drawVertices(vertices, BlendMode.srcOver, paint);
    canvas.restore();
    vertices.dispose();
  }

  @override
  bool shouldRepaint(FishFinMeshPainter old) =>
      old.image != image ||
      old.body != body ||
      old.phase != phase ||
      old.strength != strength ||
      old.tint != tint;
}

/// Preset sprites reuse decoded asset frames; no screenshot or per-frame decode.
class FishFinAsset extends StatefulWidget {
  const FishFinAsset({
    required this.assetPath,
    required this.tint,
    required this.width,
    required this.phase,
    required this.strength,
    super.key,
  });
  final String assetPath;
  final Color tint;
  final double width;
  final double phase;
  final double strength;
  @override
  State<FishFinAsset> createState() => _FishFinAssetState();
}

class _FishFinAssetState extends State<FishFinAsset> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _image;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(FishFinAsset oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _image = null;
      _resolve();
    }
  }

  void _resolve() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = AssetImage(
      widget.assetPath,
    ).resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener((info, _) {
      if (mounted) setState(() => _image = info.image);
    });
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return SizedBox(width: widget.width, height: widget.width * 2 / 3);
    }
    return SizedBox(
      width: widget.width,
      height: widget.width * image.height / image.width,
      child: CustomPaint(
        painter: FishFinMeshPainter(
          image: image,
          body: const Rect.fromLTRB(.20, .32, .62, .70),
          phase: widget.phase,
          strength: widget.strength,
          tint: widget.tint,
        ),
      ),
    );
  }
}
