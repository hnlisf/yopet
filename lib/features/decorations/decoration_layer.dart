import 'package:flutter/material.dart';

import '../../data/decorations.dart';
import 'tank_decoration.dart';

class TankDecorationsLayer extends StatefulWidget {
  const TankDecorationsLayer({
    required this.decorations,
    required this.onMove,
    required this.onRemove,
    super.key,
  });

  final List<TankDecoration> decorations;
  final ValueChanged<(TankDecoration, Offset)> onMove;
  final ValueChanged<TankDecoration> onRemove;

  @override
  State<TankDecorationsLayer> createState() => _TankDecorationsLayerState();
}

class _TankDecorationsLayerState extends State<TankDecorationsLayer> {
  final _localPositions = <String, Offset>{};
  final _draggingIds = <String>{};

  @override
  void didUpdateWidget(covariant TankDecorationsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.decorations.map((decoration) => decoration.id).toSet();
    _localPositions.removeWhere((id, _) => !ids.contains(id));
    for (final decoration in widget.decorations) {
      if (!_draggingIds.contains(decoration.id)) {
        _localPositions[decoration.id] = Offset(
          decoration.positionX,
          decoration.positionY,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final objects = widget.decorations
        .where((decoration) => decoration.type != DecorationType.background)
        .toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: objects
              .map(
                (decoration) => _buildDecoration(
                  decoration,
                  constraints.maxWidth,
                  constraints.maxHeight,
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildDecoration(
    TankDecoration decoration,
    double width,
    double height,
  ) {
    final definition = decorationForCode(decoration.code);
    if (definition == null) return const SizedBox.shrink();
    final position =
        _localPositions[decoration.id] ??
        Offset(decoration.positionX, decoration.positionY);
    final size = width * definition.widthFactor;
    return Align(
      alignment: Alignment(position.dx * 2 - 1, position.dy * 2 - 1),
      child: Semantics(
        button: true,
        label: '${definition.nameZh}，点击移除；拖动调整位置',
        child: GestureDetector(
          onTap: () => widget.onRemove(decoration),
          onPanStart: (_) => _draggingIds.add(decoration.id),
          onPanUpdate: (details) {
            final current = _localPositions[decoration.id] ?? position;
            final next = Offset(
              (current.dx + details.delta.dx / width).clamp(0.06, 0.94),
              (current.dy + details.delta.dy / height).clamp(0.08, 0.92),
            );
            setState(() => _localPositions[decoration.id] = next);
          },
          onPanEnd: (_) {
            _draggingIds.remove(decoration.id);
            final finalPosition = _localPositions[decoration.id] ?? position;
            widget.onMove((decoration, finalPosition));
          },
          onPanCancel: () => _draggingIds.remove(decoration.id),
          child: SizedBox(
            width: size,
            height: size,
            child: Image.asset(
              definition.assetPath,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.landscape_outlined, color: Colors.white54),
            ),
          ),
        ),
      ),
    );
  }
}
