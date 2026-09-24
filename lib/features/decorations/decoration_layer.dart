import 'package:flutter/material.dart';

import '../../data/decorations.dart';
import 'decoration_layout.dart';
import 'tank_decoration.dart';

class TankDecorationsLayer extends StatefulWidget {
  const TankDecorationsLayer({
    required this.decorations,
    required this.onMove,
    required this.onRemove,
    this.onResize,
    super.key,
  });

  final List<TankDecoration> decorations;
  final ValueChanged<(TankDecoration, Offset)> onMove;
  final ValueChanged<TankDecoration> onRemove;
  final ValueChanged<(TankDecoration, double)>? onResize;

  @override
  State<TankDecorationsLayer> createState() => _TankDecorationsLayerState();
}

class _TankDecorationsLayerState extends State<TankDecorationsLayer> {
  final _localPositions = <String, Offset>{};
  final _localScales = <String, double>{};
  final _draggingIds = <String>{};
  final _selectionTapGroup = Object();
  String? _selectedId;

  @override
  void didUpdateWidget(covariant TankDecorationsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.decorations.map((decoration) => decoration.id).toSet();
    _localPositions.removeWhere((id, _) => !ids.contains(id));
    _localScales.removeWhere((id, _) => !ids.contains(id));
    if (_selectedId != null && !ids.contains(_selectedId)) {
      _selectedId = null;
    }
    for (final decoration in widget.decorations) {
      if (!_draggingIds.contains(decoration.id)) {
        _localPositions[decoration.id] = Offset(
          decoration.positionX,
          decoration.positionY,
        );
      }
      _localScales[decoration.id] = clampDecorationScale(
        decoration.scaleFactor,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final objects =
        widget.decorations
            .where((decoration) => decoration.type != DecorationType.background)
            .toList(growable: false)
          ..sort((a, b) {
            if (a.id == _selectedId) return 1;
            if (b.id == _selectedId) return -1;
            return 0;
          });
    return LayoutBuilder(
      builder: (context, constraints) {
        final children = objects
            .map(
              (decoration) => _buildDecoration(
                decoration,
                constraints.maxWidth,
                constraints.maxHeight,
              ),
            )
            .toList(growable: true);
        final selected = _selectedDecoration(objects);
        if (selected != null) {
          children.add(
            _buildSelectedEditor(
              selected,
              constraints.maxWidth,
              constraints.maxHeight,
            ),
          );
        }
        return Stack(clipBehavior: Clip.none, children: children);
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
    final scale =
        _localScales[decoration.id] ??
        clampDecorationScale(decoration.scaleFactor);
    final size = width * definition.widthFactor * scale;
    final isSelected = _selectedId == decoration.id;

    final child = _buildDecorationGesture(
      decoration: decoration,
      definition: definition,
      position: position,
      width: width,
      height: height,
      isSelected: isSelected,
    );
    return Positioned(
      left: TankDecorationLayout.leftForPosition(
        positionX: position.dx,
        tankWidth: width,
        size: size,
      ),
      top: TankDecorationLayout.topForPosition(
        positionY: position.dy,
        tankHeight: height,
        size: size,
        contentBottomInset: definition.contentBottomInset,
      ),
      width: size,
      height: size,
      child: isSelected
          ? TapRegion(
              groupId: _selectionTapGroup,
              onTapOutside: (_) => setState(() => _selectedId = null),
              child: child,
            )
          : child,
    );
  }

  Widget _buildDecorationGesture({
    required TankDecoration decoration,
    required DecorationDefinition definition,
    required Offset position,
    required double width,
    required double height,
    required bool isSelected,
  }) {
    return Semantics(
      button: true,
      label: isSelected
          ? '${definition.nameZh}已选中；拖动调整位置，可缩放、完成或移出'
          : '${definition.nameZh}；轻点选中，拖动调整位置',
      child: GestureDetector(
        key: Key('placed-decoration-${decoration.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          _selectedId = isSelected ? null : decoration.id;
        }),
        onPanStart: (_) {
          _draggingIds.add(decoration.id);
          setState(() => _selectedId = decoration.id);
        },
        onPanUpdate: (details) {
          final current = _localPositions[decoration.id] ?? position;
          final verticalTravel =
              (height -
                      width *
                          definition.widthFactor *
                          (_localScales[decoration.id] ??
                              clampDecorationScale(decoration.scaleFactor)))
                  .clamp(1.0, double.infinity)
                  .toDouble();
          final next = Offset(
            (current.dx + details.delta.dx / width)
                .clamp(0.06, 0.94)
                .toDouble(),
            (current.dy + details.delta.dy / verticalTravel)
                .clamp(0.0, 1.0)
                .toDouble(),
          );
          setState(() => _localPositions[decoration.id] = next);
        },
        onPanEnd: (_) {
          _draggingIds.remove(decoration.id);
          final finalPosition = _localPositions[decoration.id] ?? position;
          widget.onMove((decoration, finalPosition));
        },
        onPanCancel: () => _draggingIds.remove(decoration.id),
        child: Image.asset(
          definition.assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.landscape_outlined, color: Colors.white54),
        ),
      ),
    );
  }

  TankDecoration? _selectedDecoration(List<TankDecoration> decorations) {
    for (final decoration in decorations) {
      if (decoration.id == _selectedId) return decoration;
    }
    return null;
  }

  Widget _buildSelectedEditor(
    TankDecoration decoration,
    double width,
    double height,
  ) {
    final definition = decorationForCode(decoration.code);
    if (definition == null) return const SizedBox.shrink();
    final position =
        _localPositions[decoration.id] ??
        Offset(decoration.positionX, decoration.positionY);
    final scale =
        _localScales[decoration.id] ??
        clampDecorationScale(decoration.scaleFactor);
    final size = width * definition.widthFactor * scale;
    const editorWidth = 250.0;
    final maxLeft = width > editorWidth + 16 ? width - editorWidth - 8 : 8.0;
    final centerX = (width - size) * position.dx + size / 2;
    final left = (centerX - editorWidth / 2).clamp(8.0, maxLeft).toDouble();
    final top =
        (TankDecorationLayout.topForPosition(
                  positionY: position.dy,
                  tankHeight: height,
                  size: size,
                  contentBottomInset: definition.contentBottomInset,
                ) -
                46)
            .clamp(8.0, height - 44)
            .toDouble();
    return Positioned(
      left: left,
      top: top,
      width: editorWidth,
      height: 36,
      child: TapRegion(
        groupId: _selectionTapGroup,
        child: _DecorationEditor(
          decoration: decoration,
          scale: scale,
          onScaleDown: () => _changeScale(decoration, scale - 0.1),
          onScaleUp: () => _changeScale(decoration, scale + 0.1),
          onConfirm: () => setState(() => _selectedId = null),
          onRemove: () => widget.onRemove(decoration),
        ),
      ),
    );
  }

  void _changeScale(TankDecoration decoration, double nextScale) {
    final scale = clampDecorationScale(nextScale);
    setState(() => _localScales[decoration.id] = scale);
    widget.onResize?.call((decoration, scale));
  }
}

class _DecorationEditor extends StatelessWidget {
  const _DecorationEditor({
    required this.decoration,
    required this.scale,
    required this.onScaleDown,
    required this.onScaleUp,
    required this.onConfirm,
    required this.onRemove,
  });

  final TankDecoration decoration;
  final double scale;
  final VoidCallback onScaleDown;
  final VoidCallback onScaleUp;
  final VoidCallback onConfirm;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: const Color(0xE9163443),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x8A83D9DE)),
          boxShadow: const [
            BoxShadow(color: Color(0x4A020D15), blurRadius: 14),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: Key('decoration-scale-down-${decoration.id}'),
                tooltip: '缩小',
                onPressed: scale <= minDecorationScale ? null : onScaleDown,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                icon: const Icon(Icons.remove_rounded, size: 18),
                color: const Color(0xFFD8F1F1),
              ),
              Text(
                '${(scale * 100).round()}%',
                style: const TextStyle(
                  color: Color(0xFFE0F7F5),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                key: Key('decoration-scale-up-${decoration.id}'),
                tooltip: '放大',
                onPressed: scale >= maxDecorationScale ? null : onScaleUp,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                color: const Color(0xFFD8F1F1),
              ),
              IconButton(
                key: Key('decoration-confirm-${decoration.id}'),
                tooltip: '完成摆放',
                onPressed: onConfirm,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                color: const Color(0xFFB6EBDE),
              ),
              const SizedBox(width: 2),
              IconButton(
                key: Key('decoration-remove-${decoration.id}'),
                tooltip: '移出鱼缸',
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                icon: const Icon(Icons.close_rounded, size: 18),
                color: const Color(0xFFF2CBB8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
