import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'desktop_companion.dart';
import 'companion_pixels.dart';
import 'pointer_attention.dart';
import 'companion_diagnostics.dart';

/// Captures only the transparent fish layer, never the Scaffold/background.
class CompanionSurface extends StatefulWidget {
  const CompanionSurface({
    required this.child,
    required this.fishId,
    this.onAttention,
    super.key,
  });
  final void Function(Offset)? onAttention;
  final Widget child;
  final String fishId;
  @override
  State<CompanionSurface> createState() => _CompanionSurfaceState();
}

class _CompanionSurfaceState extends State<CompanionSurface> {
  final _key = GlobalKey();
  Timer? _timer;
  bool _busy = false;
  Duration? _lastErrorLog;
  final _attention = PointerAttention();
  final _clock = Stopwatch()..start();
  @override
  void initState() {
    super.initState();
    CompanionDiagnostics.attach();
    _timer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _capture(),
    );
  }

  Future<void> _capture() async {
    CompanionDiagnostics.count('captureTimer');
    if (_busy || !mounted) {
      CompanionDiagnostics.count('busy');
      return;
    }
    final boundary = _key.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary ||
        (kDebugMode && boundary.debugNeedsPaint)) {
      CompanionDiagnostics.count('notPainted');
      return;
    }
    _busy = true;
    ui.Image? image;
    try {
      image = await boundary.toImage(
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
      CompanionDiagnostics.count('captured');
      final bytes = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      CompanionDiagnostics.count('readPixels');
      if (mounted && bytes != null) {
        final origin = boundary.localToGlobal(Offset.zero);
        final ratio = MediaQuery.devicePixelRatioOf(context);
        final cursor = await DesktopCompanion.channel
            .invokeMapMethod<String, dynamic>('frame', {
              'id': widget.fishId,
              'x': (origin.dx * ratio).round(),
              'y': (origin.dy * ratio).round(),
              'width': image.width,
              'height': image.height,
              'pixels': companionBgra(
                bytes.buffer.asUint8List(
                  bytes.offsetInBytes,
                  bytes.lengthInBytes,
                ),
              ),
            });
        CompanionDiagnostics.count('nativeSubmitted');
        if (mounted &&
            cursor != null &&
            cursor['x'] is num &&
            cursor['y'] is num) {
          final pointer = Offset(
            (cursor['x'] as num).toDouble() / ratio,
            (cursor['y'] as num).toDouble() / ratio,
          );
          if (_attention.update(
            pointer,
            origin + boundary.size.center(Offset.zero),
            _clock.elapsed,
          )) {
            widget.onAttention?.call(pointer);
          }
        }
      }
    } catch (error) {
      CompanionDiagnostics.count('captureError');
      final now = _clock.elapsed;
      if (_lastErrorLog == null ||
          now - _lastErrorLog! > const Duration(seconds: 10)) {
        _lastErrorLog = now;
        debugPrint(
          '[DEBUG-companion-stall] capture failure: ${error is PlatformException ? '${error.code}: ${error.message}' : error.runtimeType}',
        );
      }
      // Native restore callback remains authoritative; never queue stale frames.
    } finally {
      image?.dispose();
      _busy = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    CompanionDiagnostics.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(key: _key, child: widget.child);
}
