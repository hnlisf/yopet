import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Pixel mask shared by all placements of the same asset. Transparent margins
/// must pass pointer events through to the aquarium, including drag starts.
class DecorationMask {
  DecorationMask(this.width, this.height, this.rgba);
  final int width, height;
  final Uint8List rgba;
  bool contains(Offset point, Size size) {
    final fitted = applyBoxFit(
      BoxFit.contain,
      Size(width.toDouble(), height.toDouble()),
      size,
    );
    final rect = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    if (!rect.contains(point)) return false;
    final x = ((point.dx - rect.left) / rect.width * width).floor();
    final y = ((point.dy - rect.top) / rect.height * height).floor();
    return rgba[(y * width + x) * 4 + 3] >= 32;
  }
}

class DecorationHitRegion extends StatefulWidget {
  const DecorationHitRegion({
    required this.asset,
    required this.child,
    super.key,
  });
  final String asset;
  final Widget child;
  @override
  State<DecorationHitRegion> createState() => _DecorationHitRegionState();
}

class _DecorationHitRegionState extends State<DecorationHitRegion> {
  static final _cache = <String, Future<DecorationMask>>{};
  static final _ready = <String, DecorationMask>{};
  DecorationMask? _mask;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DecorationHitRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _mask = null;
      _load();
    }
  }

  Future<void> _load() async {
    final asset = widget.asset;
    if (_ready.containsKey(asset)) {
      _mask = _ready[asset];
      return;
    }
    try {
      final mask = await _cache.putIfAbsent(asset, () async {
        final data = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          targetWidth: 256,
        );
        try {
          final frame = await codec.getNextFrame();
          try {
            final bytes = (await frame.image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            return DecorationMask(
              frame.image.width,
              frame.image.height,
              bytes.buffer.asUint8List(
                bytes.offsetInBytes,
                bytes.lengthInBytes,
              ),
            );
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
      });
      _ready[asset] = mask;
      if (mounted && widget.asset == asset) setState(() => _mask = mask);
    } catch (_) {
      _cache.remove(asset);
    }
  }

  @override
  Widget build(BuildContext context) =>
      _MaskGate(mask: _mask, child: widget.child);
}

class _MaskGate extends SingleChildRenderObjectWidget {
  const _MaskGate({required this.mask, required super.child});
  final DecorationMask? mask;
  @override
  RenderObject createRenderObject(BuildContext context) => _MaskRender(mask);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MaskRender renderObject,
  ) {
    renderObject.mask = mask;
  }
}

class _MaskRender extends RenderProxyBox {
  _MaskRender(this.mask);
  DecorationMask? mask;
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      (mask?.contains(position, size) ?? false) &&
      super.hitTest(result, position: position);
}
