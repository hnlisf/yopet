import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'custom_fish_sprite.dart';
import 'fish_models.dart';

/// PROTOTYPE ONLY — three fish-skin art directions on one comparison route.
/// Question: which pattern language stays natural and readable across bodies?
/// Switchable at /prototype/fish-patterns?variant=A|B|C; no state is persisted.
class CustomFishPatternPrototypeScreen extends StatefulWidget {
  const CustomFishPatternPrototypeScreen({
    super.key,
    required this.initialVariant,
  });

  final String initialVariant;

  @override
  State<CustomFishPatternPrototypeScreen> createState() =>
      _CustomFishPatternPrototypeScreenState();
}

class _CustomFishPatternPrototypeScreenState
    extends State<CustomFishPatternPrototypeScreen> {
  static const _names = ['水彩漫染', '鳞片共生', '清晰观赏'];
  static const _notes = [
    '纹样以水彩颜料自然扩散，边缘柔和但保留清晰形态。',
    '纹理随着鳞片和身体走向生长，细节更丰富。',
    '强化每种纹样的标志性轮廓，缩小后也容易辨认。',
  ];

  late int _direction;
  var _bodyIndex = 0;
  var _tailIndex = 2;
  var _colorIndex = 0;
  var _patternIndex = 0;
  var _showCurrent = false;

  @override
  void initState() {
    super.initState();
    _direction = _parseVariant(widget.initialVariant);
  }

  @override
  void didUpdateWidget(covariant CustomFishPatternPrototypeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _parseVariant(widget.initialVariant);
    if (_direction != next) setState(() => _direction = next);
  }

  int _parseVariant(String value) {
    final index = 'ABC'.indexOf(value.toUpperCase());
    return index < 0 ? 1 : index + 1;
  }

  void _move(int offset) {
    final next = (_direction - 1 + offset + 3) % 3;
    context.go('/prototype/fish-patterns?variant=${'ABC'[next]}');
  }

  CustomFishAppearance _appearance(int patternIndex) => CustomFishAppearance(
    body: customFishBodies[_bodyIndex].id,
    tail: customFishTails[_tailIndex].id,
    pattern: customFishPatterns[patternIndex].id,
    color: customFishColors[_colorIndex].id,
  );

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        final focused = FocusManager.instance.primaryFocus?.context?.widget;
        if (focused is EditableText || event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _move(-1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _move(1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF091D2B),
        body: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 720;
                  final contentWidth =
                      (constraints.maxWidth - (compact ? 32 : 64)).clamp(
                        0.0,
                        1060.0,
                      );
                  return SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 114),
                    child: Center(
                      child: SizedBox(
                        width: contentWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                IconButton.filledTonal(
                                  onPressed: () => context.go(
                                    '/prototype/custom-fish-flow?variant=B',
                                  ),
                                  icon: const Icon(Icons.arrow_back),
                                  tooltip: '返回水下工作台',
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '鱼身纹样对比',
                                        style: TextStyle(
                                          color: Color(0xFFF3F7FB),
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '原型研究 · ${_names[_direction - 1]}',
                                        style: const TextStyle(
                                          color: Color(0xFFA8C1CD),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Text(
                                  '8 种纹样',
                                  style: TextStyle(
                                    color: Color(0xFF9BD5E1),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Text(
                              _notes[_direction - 1],
                              style: const TextStyle(
                                color: Color(0xFFA8C1CD),
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 15),
                            _controls(compact),
                            const SizedBox(height: 20),
                            if (compact) ...[
                              _hero(contentWidth),
                              const SizedBox(height: 22),
                              _gallery(contentWidth, compact: true),
                            ] else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: contentWidth * .44,
                                    child: _hero(contentWidth * .44),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: _gallery(
                                      contentWidth * .56 - 18,
                                      compact: false,
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 22),
                            const Text(
                              'A「水彩漫染」已接入自定义鱼种。这里保留原版对照；'
                              '箭头可切换三种方向，体型、尾鳍和颜色用于检查组合效果。',
                              style: TextStyle(
                                color: Color(0xFF8CA8B7),
                                fontSize: 12,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (kDebugMode)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Center(child: _switcher()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gallery(double width, {required bool compact}) => Column(
    children: [
      Row(
        children: [
          const Text(
            '全部纹样',
            style: TextStyle(
              color: Color(0xFFF3F7FB),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          const Text(
            '点选可放大查看',
            style: TextStyle(color: Color(0xFF91ADBB), fontSize: 12),
          ),
        ],
      ),
      const SizedBox(height: 12),
      GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: customFishPatterns.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: compact ? 2 : 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: compact ? 1.32 : 1.10,
        ),
        itemBuilder: (context, index) =>
            _tile(index, (width - (compact ? 10 : 30)) / (compact ? 2 : 4)),
      ),
    ],
  );

  Widget _controls(bool compact) {
    Widget selector(
      String label,
      int value,
      int length,
      String Function(int) itemLabel,
      ValueChanged<int> onChanged,
    ) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF152A38),
          border: Border.all(color: const Color(0xFF315264)),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label  ',
              style: const TextStyle(color: Color(0xFF91ADBB), fontSize: 13),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: value,
                dropdownColor: const Color(0xFF152A38),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                iconEnabledColor: const Color(0xFF9BD5E1),
                items: List.generate(
                  length,
                  (index) => DropdownMenuItem(
                    value: index,
                    child: Text(itemLabel(index)),
                  ),
                ),
                onChanged: (next) {
                  if (next != null) onChanged(next);
                },
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        selector(
          '体型',
          _bodyIndex,
          customFishBodies.length,
          (i) => customFishBodies[i].label,
          (i) => setState(() => _bodyIndex = i),
        ),
        selector(
          '尾鳍',
          _tailIndex,
          customFishTails.length,
          (i) => customFishTails[i].label,
          (i) => setState(() => _tailIndex = i),
        ),
        selector(
          '水彩',
          _colorIndex,
          customFishColors.length,
          (i) => customFishColors[i].label,
          (i) => setState(() => _colorIndex = i),
        ),
      ],
    );
  }

  Widget _hero(double width) {
    final fishWidth = (width - 35).clamp(220.0, 500.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 15),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2636),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFF335366)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '放大预览',
                style: TextStyle(color: Color(0xFF9BD5E1), fontSize: 13),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _showCurrent = !_showCurrent),
                child: Text(_showCurrent ? '返回所选方案' : '对照原版本'),
              ),
            ],
          ),
          CustomFishSprite(
            appearance: _appearance(_patternIndex),
            width: fishWidth,
            patternStudyDirection: _showCurrent ? 0 : _direction,
          ),
          const SizedBox(height: 3),
          Text(
            '${customFishPatterns[_patternIndex].label} · '
            '${_showCurrent ? '原版本' : _names[_direction - 1]}',
            style: const TextStyle(
              color: Color(0xFFF3F7FB),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(int index, double width) {
    final selected = index == _patternIndex;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() {
        _patternIndex = index;
        _showCurrent = false;
      }),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1B3543) : const Color(0xFF132A38),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFFA2DBE7) : const Color(0xFF355365),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomFishSprite(
              appearance: _appearance(index),
              width: (width - 18).clamp(100.0, 210.0),
              patternStudyDirection: _direction,
            ),
            Text(
              customFishPatterns[index].label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFFC1D3DC),
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switcher() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFE2D5FF),
      borderRadius: BorderRadius.circular(100),
      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 18)],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _move(-1),
          icon: const Icon(Icons.arrow_back),
          tooltip: '上一个方案',
          color: const Color(0xFF37285F),
        ),
        const SizedBox(width: 8),
        Text(
          '${'ABC'[_direction - 1]} · ${_names[_direction - 1]}',
          style: const TextStyle(
            color: Color(0xFF37285F),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _move(1),
          icon: const Icon(Icons.arrow_forward),
          tooltip: '下一个方案',
          color: const Color(0xFF37285F),
        ),
      ],
    ),
  );
}
