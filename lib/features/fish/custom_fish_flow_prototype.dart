import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import 'custom_fish_sprite.dart';
import 'fish_models.dart';

/// PROTOTYPE ONLY — Three complete interaction models for the custom-fish
/// journey, switchable with `?variant=A|B|C` on
/// `/prototype/custom-fish-flow`.
///
/// Research question: which interaction model lets a non-designer create a
/// believable, personal fish without feeling overwhelmed? All state is local
/// and no repository mutation is reachable from this screen.
class CustomFishFlowPrototypeScreen extends StatefulWidget {
  const CustomFishFlowPrototypeScreen({
    super.key,
    required this.initialVariant,
  });

  final String initialVariant;

  @override
  State<CustomFishFlowPrototypeScreen> createState() =>
      _CustomFishFlowPrototypeScreenState();
}

class _CustomFishFlowPrototypeScreenState
    extends State<CustomFishFlowPrototypeScreen> {
  static const _variants = <_PrototypeVariant>[
    _PrototypeVariant(key: 'A', name: '五步引导'),
    _PrototypeVariant(key: 'B', name: '水下工作台'),
    _PrototypeVariant(key: 'C', name: '自然原型'),
  ];

  final _nameController = TextEditingController(text: '云尾');
  late String _variant;
  var _bodyIndex = 4;
  var _tailIndex = 1;
  var _patternIndex = 2;
  var _colorIndex = 0;
  var _guidedStep = 0;
  var _studioCategory = 2;
  var _templateStage = 0;
  var _patternDensity = .58;
  var _patternSoftness = .64;
  var _individualSeed = 37;

  CustomFishAppearance get _appearance => CustomFishAppearance(
    body: customFishBodies[_bodyIndex].id,
    tail: customFishTails[_tailIndex].id,
    pattern: customFishPatterns[_patternIndex].id,
    color: customFishColors[_colorIndex].id,
  );

  @override
  void initState() {
    super.initState();
    _variant = _normalise(widget.initialVariant);
  }

  @override
  void didUpdateWidget(covariant CustomFishFlowPrototypeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _normalise(widget.initialVariant);
    if (next != _variant) setState(() => _variant = next);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _normalise(String value) =>
      _variants.any((item) => item.key == value.toUpperCase())
      ? value.toUpperCase()
      : 'A';

  void _moveVariant(int offset) {
    final index = _variants.indexWhere((item) => item.key == _variant);
    final next = _variants[(index + offset) % _variants.length];
    context.go('/prototype/custom-fish-flow?variant=${next.key}');
  }

  void _showPrototypeFinish() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_nameController.text.trim()} 已完成预览；原型不会写入鱼缸')),
    );
  }

  void _applyTemplate(_FishTemplate template) {
    setState(() {
      _bodyIndex = template.bodyIndex;
      _tailIndex = template.tailIndex;
      _patternIndex = template.patternIndex;
      _colorIndex = template.colorIndex;
      _templateStage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = _variants.firstWhere((item) => item.key == _variant);
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        final focusedWidget =
            FocusManager.instance.primaryFocus?.context?.widget;
        if (focusedWidget is EditableText) return KeyEventResult.ignored;
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _moveVariant(-1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _moveVariant(1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Tokens.primaryBg,
        body: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Color(0xFF07131D))),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: switch (_variant) {
                  'B' => CustomFishStudio(
                    appearance: _appearance,
                    category: _studioCategory,
                    bodyIndex: _bodyIndex,
                    tailIndex: _tailIndex,
                    patternIndex: _patternIndex,
                    colorIndex: _colorIndex,
                    patternDensity: _patternDensity,
                    patternSoftness: _patternSoftness,
                    individualSeed: _individualSeed,
                    nameController: _nameController,
                    onCategoryChanged: (value) =>
                        setState(() => _studioCategory = value),
                    onBodyChanged: (value) =>
                        setState(() => _bodyIndex = value),
                    onTailChanged: (value) =>
                        setState(() => _tailIndex = value),
                    onPatternChanged: (value) =>
                        setState(() => _patternIndex = value),
                    onColorChanged: (value) =>
                        setState(() => _colorIndex = value),
                    onPatternDensityChanged: (value) =>
                        setState(() => _patternDensity = value),
                    onPatternSoftnessChanged: (value) =>
                        setState(() => _patternSoftness = value),
                    onVariationRequested: () =>
                        setState(() => _individualSeed += 1),
                    onFinish: _showPrototypeFinish,
                  ),
                  'C' => _TemplateVariant(
                    appearance: _appearance,
                    stage: _templateStage,
                    bodyIndex: _bodyIndex,
                    tailIndex: _tailIndex,
                    patternIndex: _patternIndex,
                    colorIndex: _colorIndex,
                    nameController: _nameController,
                    onTemplateSelected: _applyTemplate,
                    onBodyChanged: (value) =>
                        setState(() => _bodyIndex = value),
                    onTailChanged: (value) =>
                        setState(() => _tailIndex = value),
                    onPatternChanged: (value) =>
                        setState(() => _patternIndex = value),
                    onColorChanged: (value) =>
                        setState(() => _colorIndex = value),
                    onStageChanged: (value) =>
                        setState(() => _templateStage = value),
                    onFinish: _showPrototypeFinish,
                  ),
                  _ => _GuidedVariant(
                    appearance: _appearance,
                    step: _guidedStep,
                    bodyIndex: _bodyIndex,
                    tailIndex: _tailIndex,
                    patternIndex: _patternIndex,
                    colorIndex: _colorIndex,
                    nameController: _nameController,
                    onBodyChanged: (value) =>
                        setState(() => _bodyIndex = value),
                    onTailChanged: (value) =>
                        setState(() => _tailIndex = value),
                    onPatternChanged: (value) =>
                        setState(() => _patternIndex = value),
                    onColorChanged: (value) =>
                        setState(() => _colorIndex = value),
                    onStepChanged: (value) =>
                        setState(() => _guidedStep = value),
                    onFinish: _showPrototypeFinish,
                  ),
                },
              ),
            ),
            if (kDebugMode && _variant != 'B')
              _PrototypeSwitcher(
                current: current,
                onPrevious: () => _moveVariant(-1),
                onNext: () => _moveVariant(1),
              ),
          ],
        ),
      ),
    );
  }
}

class _GuidedVariant extends StatelessWidget {
  const _GuidedVariant({
    required this.appearance,
    required this.step,
    required this.bodyIndex,
    required this.tailIndex,
    required this.patternIndex,
    required this.colorIndex,
    required this.nameController,
    required this.onBodyChanged,
    required this.onTailChanged,
    required this.onPatternChanged,
    required this.onColorChanged,
    required this.onStepChanged,
    required this.onFinish,
  });

  final CustomFishAppearance appearance;
  final int step;
  final int bodyIndex;
  final int tailIndex;
  final int patternIndex;
  final int colorIndex;
  final TextEditingController nameController;
  final ValueChanged<int> onBodyChanged;
  final ValueChanged<int> onTailChanged;
  final ValueChanged<int> onPatternChanged;
  final ValueChanged<int> onColorChanged;
  final ValueChanged<int> onStepChanged;
  final VoidCallback onFinish;

  static const _steps = ['体型', '尾鳍', '纹样', '水彩', '命名'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const _PrototypeHeader(title: '一步步设计', subtitle: '每次只做一个选择'),
          _StepProgress(labels: _steps, current: step),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FishPreview(
                    appearance: appearance,
                    helper: step == 2 ? '纹样只在鱼身生长，鱼鳍会保持干净' : _steps[step],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    switch (step) {
                      0 => '先选一个看起来舒服的轮廓',
                      1 => '尾鳍决定游动时的气质',
                      2 => '纹样会自动顺着当前体型重新生长',
                      3 => '选一种让你放松的水彩',
                      _ => '最后给它一个只属于你的名字',
                    },
                    style: const TextStyle(
                      color: Tokens.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(switch (step) {
                    0 => '没有专业术语，点击后直接看整体变化。',
                    1 => '所有组合都会使用完整鱼形，不再硬拼接。',
                    2 => '眼睛、头部和所有鱼鳍都是纹样禁区。',
                    3 => '纹样颜色会从鱼身颜色自然推导。',
                    _ => '保存前还能回到任一步重新调整。',
                  }, style: const TextStyle(color: Tokens.textDim)),
                  const SizedBox(height: 16),
                  switch (step) {
                    0 => _ChoiceGrid<CustomFishBody>(
                      items: customFishBodies,
                      selectedIndex: bodyIndex,
                      labelOf: (item) => item.label,
                      noteOf: (item) => item.note,
                      onSelected: onBodyChanged,
                    ),
                    1 => _ChoiceGrid<CustomFishTail>(
                      items: customFishTails,
                      selectedIndex: tailIndex,
                      labelOf: (item) => item.label,
                      noteOf: (item) => switch (item.id) {
                        'petal' => '轻巧活泼',
                        'fan' => '舒展从容',
                        _ => '柔软飘逸',
                      },
                      onSelected: onTailChanged,
                    ),
                    2 => _PatternChoices(
                      selectedIndex: patternIndex,
                      onSelected: onPatternChanged,
                    ),
                    3 => _ColorChoices(
                      selectedIndex: colorIndex,
                      onSelected: onColorChanged,
                    ),
                    _ => _NameAndSummary(
                      appearance: appearance,
                      controller: nameController,
                    ),
                  },
                ],
              ),
            ),
          ),
          _GuidedActions(
            step: step,
            onBack: step == 0 ? null : () => onStepChanged(step - 1),
            onNext: step == _steps.length - 1
                ? onFinish
                : () => onStepChanged(step + 1),
          ),
        ],
      ),
    );
  }
}

/// The approved B workspace, shared by the visual study and the real editor.
class CustomFishStudio extends StatelessWidget {
  const CustomFishStudio({
    super.key,
    required this.appearance,
    required this.category,
    required this.bodyIndex,
    required this.tailIndex,
    required this.patternIndex,
    required this.colorIndex,
    required this.patternDensity,
    required this.patternSoftness,
    required this.individualSeed,
    required this.nameController,
    required this.onCategoryChanged,
    required this.onBodyChanged,
    required this.onTailChanged,
    required this.onPatternChanged,
    required this.onColorChanged,
    required this.onPatternDensityChanged,
    required this.onPatternSoftnessChanged,
    required this.onVariationRequested,
    required this.onFinish,
    this.onBack,
    this.progressLabel = '4 / 5',
    this.finishLabel = '完成这条鱼',
    this.finishEnabled = true,
    this.isFinishing = false,
    this.showIndividualVariation = true,
    this.nameError,
    this.onNameChanged,
    this.adaptiveLayout = false,
  });

  final CustomFishAppearance appearance;
  final int category;
  final int bodyIndex;
  final int tailIndex;
  final int patternIndex;
  final int colorIndex;
  final double patternDensity;
  final double patternSoftness;
  final int individualSeed;
  final TextEditingController nameController;
  final ValueChanged<int> onCategoryChanged;
  final ValueChanged<int> onBodyChanged;
  final ValueChanged<int> onTailChanged;
  final ValueChanged<int> onPatternChanged;
  final ValueChanged<int> onColorChanged;
  final ValueChanged<double> onPatternDensityChanged;
  final ValueChanged<double> onPatternSoftnessChanged;
  final VoidCallback onVariationRequested;
  final VoidCallback onFinish;
  final VoidCallback? onBack;
  final String progressLabel;
  final String finishLabel;
  final bool finishEnabled;
  final bool isFinishing;
  final bool showIndividualVariation;
  final String? nameError;
  final ValueChanged<String>? onNameChanged;
  final bool adaptiveLayout;

  Widget _adaptiveStudio(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Window width, not platform identity, controls the layout: a narrow
          // Windows window must be just as usable as a phone.
          final wide = constraints.maxWidth >= 960;
          final inset = wide ? 24.0 : 12.0;
          final minHeight = wide ? 660.0 : 620.0;
          final workspace = SizedBox(
            height: constraints.maxHeight < minHeight
                ? minHeight
                : constraints.maxHeight,
            child: Container(
              decoration: wide
                  ? const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/tank/studio_canvas.png'),
                        fit: BoxFit.cover,
                        opacity: .85,
                      ),
                    )
                  : null,
              padding: EdgeInsets.all(inset),
              child: Column(
                children: [
                  _PrototypeHeader(
                    title: '水下工作台',
                    subtitle: '鱼一直留在画布中央',
                    transparent: true,
                    onBack: onBack,
                    progressLabel: progressLabel,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: wide
                        ? Row(
                            key: const Key('studio-desktop-layout'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(width: 76, child: _desktopRail()),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _adaptivePreview(immersive: true),
                              ),
                              const SizedBox(width: 20),
                              SizedBox(
                                width: (constraints.maxWidth * .27).clamp(
                                  310.0,
                                  380.0,
                                ),
                                child: _adaptiveTools(desktop: true),
                              ),
                            ],
                          )
                        : Column(
                            key: const Key('studio-mobile-layout'),
                            children: [
                              SizedBox(
                                height: (constraints.maxHeight * .33).clamp(
                                  180.0,
                                  300.0,
                                ),
                                width: double.infinity,
                                child: _adaptivePreview(),
                              ),
                              const SizedBox(height: 12),
                              Expanded(child: _adaptiveTools()),
                            ],
                          ),
                  ),
                  if (wide) ...[const SizedBox(height: 16), _desktopFooter()],
                ],
              ),
            ),
          );
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 1440 : 760),
              child: constraints.maxHeight < minHeight
                  ? SingleChildScrollView(child: workspace)
                  : workspace,
            ),
          );
        },
      ),
    );
  }

  static const _labels = ['体型', '尾鳍', '纹样', '水彩', '名字'];
  static const _icons = [
    Icons.water_rounded,
    Icons.air_rounded,
    Icons.blur_on_rounded,
    Icons.palette_outlined,
    Icons.edit_outlined,
  ];

  Widget _desktopRail() => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: _floatingSurface(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          _labels.length,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _ToolButton(
              icon: _icons[index],
              label: _labels[index],
            selected: category == index,
            prominent: true,
            onTap: () => onCategoryChanged(index),
            ),
          ),
        ),
      ),
    ),
  );

  BoxDecoration _floatingSurface() => BoxDecoration(
    color: Tokens.primaryBg.withValues(alpha: .94),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Tokens.tankGlow.withValues(alpha: .3)),
  );

  Widget _desktopFooter() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _floatingSurface(),
        child: Row(
          children: [
            const Icon(Icons.water_rounded, color: Tokens.tankGlowSoft),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                appearance.summary,
                style: const TextStyle(color: Tokens.text, fontSize: 14),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(width: 300, child: _finishButton()),
          ],
        ),
      ),
    ),
  );

  Widget _finishButton() => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton.icon(
      key: const Key('save-custom-fish'),
      onPressed: finishEnabled && !isFinishing ? onFinish : null,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFD4BFFF),
        foregroundColor: const Color(0xFF332356),
        disabledBackgroundColor: Tokens.surface,
        disabledForegroundColor: Tokens.textDim,
      ),
      icon: isFinishing
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_awesome_rounded),
      label: Text(finishLabel),
    ),
  );

  Widget _adaptivePreview({bool immersive = false}) {
    return Container(
      key: const Key('studio-preview'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: immersive ? Colors.transparent : const Color(0xFF07131D),
        borderRadius: BorderRadius.circular(24),
        border: immersive
            ? null
            : Border.all(color: Tokens.tankGlow.withValues(alpha: .32)),
        image: immersive
            ? null
            : const DecorationImage(
                image: AssetImage('assets/tank/studio_canvas.png'),
                fit: BoxFit.cover,
                opacity: .8,
              ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _WaterRingsPainter()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _NaturalFitBadge(),
                  const SizedBox(height: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: CustomFishSprite(
                        appearance: appearance,
                        width: (constraints.maxWidth * .84).clamp(240.0, 640.0),
                        patternTuning: CustomFishPatternTuning(
                          density: patternDensity,
                          softness: patternSoftness,
                          individualSeed: individualSeed,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    appearance.summary,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Tokens.tankGlowSoft,
                      fontSize: 14,
                    ),
                  ),
                  if (showIndividualVariation)
                    TextButton.icon(
                      onPressed: onVariationRequested,
                      icon: const Icon(Icons.casino_outlined, size: 18),
                      label: const Text('每条都不同 · 换个个体'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adaptiveTools({bool desktop = false}) {
    const labels = ['体型', '尾鳍', '纹样', '水彩', '名字'];
    const icons = [
      Icons.water_rounded,
      Icons.air_rounded,
      Icons.blur_on_rounded,
      Icons.palette_outlined,
      Icons.edit_outlined,
    ];
    return Container(
      key: const Key('studio-controls'),
      padding: const EdgeInsets.all(16),
      decoration: _floatingSurface(),
      child: Column(
        children: [
          if (desktop)
            Row(
              children: [
                Icon(icons[category], color: Tokens.tankGlowSoft),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(labels[category], style: const TextStyle(color: Tokens.text,
                      fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(const ['调整鱼身的自然轮廓', '让尾鳍轻盈舒展',
                      '为鱼选择独特的纹路', '选择你喜欢的水彩',
                      '给新伙伴一个名字'][category],
                      style: const TextStyle(color: Tokens.textDim, fontSize: 12)),
                  ],
                )),
              ],
            )
          else
            Row(
              children: List.generate(
                labels.length,
                (index) => Expanded(
                  child: _ToolButton(
                    icon: icons[index],
                    label: labels[index],
                      selected: category == index,
                      prominent: true,
                    onTap: () => onCategoryChanged(index),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              key: const Key('studio-options-scroll'),
              child: switch (category) {
                0 => _CompactChips<CustomFishBody>(
                  items: customFishBodies,
                  selectedIndex: bodyIndex,
                  labelOf: (item) => item.label,
                  onSelected: onBodyChanged,
                ),
                1 => _CompactChips<CustomFishTail>(
                  items: customFishTails,
                  selectedIndex: tailIndex,
                  labelOf: (item) => item.label,
                  onSelected: onTailChanged,
                ),
                2 => _StudioPatternPanel(
                  appearance: appearance,
                  selectedIndex: patternIndex,
                  onSelected: onPatternChanged,
                  density: patternDensity,
                  softness: patternSoftness,
                  individualSeed: individualSeed,
                  onDensityChanged: onPatternDensityChanged,
                  onSoftnessChanged: onPatternSoftnessChanged,
                  useGrid: desktop,
                  largeCards: true,
                ),
                3 => _ColorChoices(
                  selectedIndex: colorIndex,
                  onSelected: onColorChanged,
                  compact: true,
                ),
                _ => TextField(
                  key: const Key('custom-fish-name'),
                  controller: nameController,
                  maxLength: 20,
                  style: const TextStyle(color: Tokens.text),
                  onChanged: onNameChanged,
                  decoration: _prototypeInputDecoration(
                    '给它起个名字',
                    errorText: nameError,
                  ),
                ),
              },
            ),
          ),
          if (!desktop) ...[const SizedBox(height: 12), _finishButton()],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['体型', '尾鳍', '纹样', '水彩', '名字'];
    if (adaptiveLayout) return _adaptiveStudio(context);
    const icons = [
      Icons.water_rounded,
      Icons.air_rounded,
      Icons.blur_on_rounded,
      Icons.palette_outlined,
      Icons.edit_outlined,
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/tank/background.png'),
          fit: BoxFit.cover,
          opacity: .70,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _PrototypeHeader(
              title: '水下工作台',
              subtitle: '鱼一直留在画布中央',
              transparent: true,
              onBack: onBack,
              progressLabel: progressLabel,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // A shallow window (or a landscape phone) must keep the
                  // preview complete and the tool tray usable. The artwork
                  // scales down before any text or CTA can be clipped.
                  final compactPreview = constraints.maxHeight < 350;
                  final fishWidth = compactPreview ? 185.0 : 300.0;
                  final spacing = compactPreview ? 5.0 : 18.0;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: _WaterRingsPainter()),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _NaturalFitBadge(),
                          SizedBox(height: spacing),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween(
                                      begin: .97,
                                      end: 1.0,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            child: CustomFishSprite(
                              key: ValueKey(
                                '${appearance.summary}/$patternDensity/'
                                '$patternSoftness/$individualSeed',
                              ),
                              appearance: appearance,
                              width: fishWidth,
                              patternTuning: CustomFishPatternTuning(
                                density: patternDensity,
                                softness: patternSoftness,
                                individualSeed: individualSeed,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            appearance.summary,
                            style: const TextStyle(color: Tokens.tankGlowSoft),
                          ),
                          if (showIndividualVariation)
                            TextButton.icon(
                              onPressed: onVariationRequested,
                              icon: const Icon(Icons.casino_outlined, size: 15),
                              label: const Text('每条都不同 · 换个个体'),
                              style: TextButton.styleFrom(
                                foregroundColor: Tokens.textDim,
                                textStyle: const TextStyle(fontSize: 11),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              decoration: BoxDecoration(
                color: Tokens.primaryBg.withValues(alpha: .96),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                border: Border(
                  top: BorderSide(
                    color: Tokens.tankGlow.withValues(alpha: .28),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      labels.length,
                      (index) => _ToolButton(
                        icon: icons[index],
                        label: labels[index],
                        selected: category == index,
                        onTap: () => onCategoryChanged(index),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: switch (category) {
                      2 => 186,
                      3 => 94,
                      4 => 92,
                      _ => 72,
                    },
                    child: SingleChildScrollView(
                      child: switch (category) {
                        0 => _CompactChips<CustomFishBody>(
                          items: customFishBodies,
                          selectedIndex: bodyIndex,
                          labelOf: (item) => item.label,
                          onSelected: onBodyChanged,
                        ),
                        1 => _CompactChips<CustomFishTail>(
                          items: customFishTails,
                          selectedIndex: tailIndex,
                          labelOf: (item) => item.label,
                          onSelected: onTailChanged,
                        ),
                        2 => _StudioPatternPanel(
                          appearance: appearance,
                          selectedIndex: patternIndex,
                          onSelected: onPatternChanged,
                          density: patternDensity,
                          softness: patternSoftness,
                          individualSeed: individualSeed,
                          onDensityChanged: onPatternDensityChanged,
                          onSoftnessChanged: onPatternSoftnessChanged,
                        ),
                        3 => _ColorChoices(
                          selectedIndex: colorIndex,
                          onSelected: onColorChanged,
                          compact: true,
                        ),
                        _ => TextField(
                          key: const Key('custom-fish-name'),
                          controller: nameController,
                          maxLength: 20,
                          style: const TextStyle(color: Tokens.text),
                          onChanged: onNameChanged,
                          decoration: _prototypeInputDecoration(
                            '给它起个名字',
                            errorText: nameError,
                          ),
                        ),
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      key: const Key('save-custom-fish'),
                      onPressed: finishEnabled && !isFinishing
                          ? onFinish
                          : null,
                      icon: isFinishing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Tokens.primaryBg,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(finishLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateVariant extends StatelessWidget {
  const _TemplateVariant({
    required this.appearance,
    required this.stage,
    required this.bodyIndex,
    required this.tailIndex,
    required this.patternIndex,
    required this.colorIndex,
    required this.nameController,
    required this.onTemplateSelected,
    required this.onBodyChanged,
    required this.onTailChanged,
    required this.onPatternChanged,
    required this.onColorChanged,
    required this.onStageChanged,
    required this.onFinish,
  });

  final CustomFishAppearance appearance;
  final int stage;
  final int bodyIndex;
  final int tailIndex;
  final int patternIndex;
  final int colorIndex;
  final TextEditingController nameController;
  final ValueChanged<_FishTemplate> onTemplateSelected;
  final ValueChanged<int> onBodyChanged;
  final ValueChanged<int> onTailChanged;
  final ValueChanged<int> onPatternChanged;
  final ValueChanged<int> onColorChanged;
  final ValueChanged<int> onStageChanged;
  final VoidCallback onFinish;

  static const _templates = <_FishTemplate>[
    _FishTemplate(
      name: '珊瑚圆盘',
      note: '亲切 · 舒展',
      bodyIndex: 3,
      tailIndex: 0,
      patternIndex: 1,
      colorIndex: 3,
    ),
    _FishTemplate(
      name: '青苔灯影',
      note: '安静 · 轻盈',
      bodyIndex: 1,
      tailIndex: 1,
      patternIndex: 4,
      colorIndex: 5,
    ),
    _FishTemplate(
      name: '月光神仙',
      note: '优雅 · 从容',
      bodyIndex: 2,
      tailIndex: 2,
      patternIndex: 5,
      colorIndex: 1,
    ),
    _FishTemplate(
      name: '湖水鳗尾',
      note: '好奇 · 灵动',
      bodyIndex: 7,
      tailIndex: 2,
      patternIndex: 3,
      colorIndex: 7,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PrototypeHeader(
              title: '从自然原型开始',
              subtitle: '先喜欢上它，再慢慢调整',
              outsidePadding: false,
            ),
            const SizedBox(height: 10),
            if (stage == 0) ...[
              const Text(
                '哪一种最接近你心里的鱼？',
                style: TextStyle(
                  color: Tokens.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '每个原型已经搭配好自然体型、尾鳍和纹样。',
                style: TextStyle(color: Tokens.textDim),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: .86,
                ),
                itemCount: _templates.length,
                itemBuilder: (_, index) {
                  final template = _templates[index];
                  return _TemplateCard(
                    template: template,
                    onTap: () => onTemplateSelected(template),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => onTemplateSelected(_templates.first),
                child: const Text('帮我随机选一条'),
              ),
            ] else ...[
              _FishPreview(
                appearance: appearance,
                helper: stage == 1 ? '只调整你在意的地方' : '放进鱼缸前的最后一眼',
              ),
              const SizedBox(height: 18),
              if (stage == 1) ...[
                const Text(
                  '想让它更像你一点吗？',
                  style: TextStyle(
                    color: Tokens.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '可以只改一项，也可以直接使用现在的搭配。',
                  style: TextStyle(color: Tokens.textDim),
                ),
                const SizedBox(height: 18),
                _RefineRow(
                  title: '轮廓',
                  current: customFishBodies[bodyIndex].label,
                  onPrevious: () => onBodyChanged(
                    (bodyIndex - 1 + customFishBodies.length) %
                        customFishBodies.length,
                  ),
                  onNext: () =>
                      onBodyChanged((bodyIndex + 1) % customFishBodies.length),
                ),
                _RefineRow(
                  title: '尾鳍',
                  current: customFishTails[tailIndex].label,
                  onPrevious: () => onTailChanged(
                    (tailIndex - 1 + customFishTails.length) %
                        customFishTails.length,
                  ),
                  onNext: () =>
                      onTailChanged((tailIndex + 1) % customFishTails.length),
                ),
                _RefineRow(
                  title: '纹样',
                  current: customFishPatterns[patternIndex].label,
                  onPrevious: () => onPatternChanged(
                    (patternIndex - 1 + customFishPatterns.length) %
                        customFishPatterns.length,
                  ),
                  onNext: () => onPatternChanged(
                    (patternIndex + 1) % customFishPatterns.length,
                  ),
                ),
                _RefineRow(
                  title: '水彩',
                  current: customFishColors[colorIndex].label,
                  dotColor: customFishColors[colorIndex].color,
                  onPrevious: () => onColorChanged(
                    (colorIndex - 1 + customFishColors.length) %
                        customFishColors.length,
                  ),
                  onNext: () => onColorChanged(
                    (colorIndex + 1) % customFishColors.length,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => onStageChanged(2),
                  child: const Text('这样很好，去取名字'),
                ),
                TextButton(
                  onPressed: () => onStageChanged(0),
                  child: const Text('换一个自然原型'),
                ),
              ] else ...[
                _NameAndSummary(
                  appearance: appearance,
                  controller: nameController,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: onFinish,
                    icon: const Icon(Icons.waves_rounded),
                    label: const Text('预览放入鱼缸'),
                  ),
                ),
                TextButton(
                  onPressed: () => onStageChanged(1),
                  child: const Text('再调整一下'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PrototypeHeader extends StatelessWidget {
  const _PrototypeHeader({
    required this.title,
    required this.subtitle,
    this.transparent = false,
    this.outsidePadding = true,
    this.onBack,
    this.progressLabel = '4 / 5',
  });

  final String title;
  final String subtitle;
  final bool transparent;
  final bool outsidePadding;
  final VoidCallback? onBack;
  final String progressLabel;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        IconButton.filledTonal(
          onPressed: onBack ?? () {},
          tooltip: onBack == null ? '原型中不离开此页' : '返回领养列表',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Tokens.text,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Tokens.textDim, fontSize: 11),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: transparent
                ? Tokens.primaryBg.withValues(alpha: .42)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Tokens.tankGlow.withValues(alpha: .40)),
          ),
          child: Text(
            progressLabel,
            style: const TextStyle(
              color: Tokens.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
    if (!outsidePadding) return content;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: content,
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.labels, required this.current});

  final List<String> labels;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: Column(
        children: [
          Row(
            children: List.generate(labels.length, (index) {
              final active = index <= current;
              return Expanded(
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? Tokens.tankGlowSoft : Tokens.textDim,
                    fontSize: 11,
                    fontWeight: index == current
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (current + 1) / labels.length,
              minHeight: 4,
              backgroundColor: Tokens.surface,
              color: Tokens.tankGlowSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _FishPreview extends StatelessWidget {
  const _FishPreview({required this.appearance, required this.helper});

  final CustomFishAppearance appearance;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 235,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        image: const DecorationImage(
          image: AssetImage('assets/tank/background.png'),
          fit: BoxFit.cover,
          opacity: .58,
        ),
        border: Border.all(color: Tokens.tankGlow.withValues(alpha: .32)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomFishSprite(appearance: appearance, width: 255),
          const Positioned(top: 12, right: 12, child: _NaturalFitBadge()),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Text(
              helper,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Tokens.tankGlowSoft,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NaturalFitBadge extends StatelessWidget {
  const _NaturalFitBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Tokens.primaryBg.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Tokens.tankGlow.withValues(alpha: .28)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.eco_outlined, size: 13, color: Tokens.tankGlowSoft),
          SizedBox(width: 4),
          Text(
            '自然适配',
            style: TextStyle(color: Tokens.tankGlowSoft, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ChoiceGrid<T> extends StatelessWidget {
  const _ChoiceGrid({
    required this.items,
    required this.selectedIndex,
    required this.labelOf,
    required this.noteOf,
    required this.onSelected,
  });

  final List<T> items;
  final int selectedIndex;
  final String Function(T item) labelOf;
  final String Function(T item) noteOf;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.25,
      ),
      itemCount: items.length,
      itemBuilder: (_, index) {
        final selected = index == selectedIndex;
        return InkWell(
          onTap: () => onSelected(index),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? Tokens.tankGlow.withValues(alpha: .18)
                  : Tokens.surface.withValues(alpha: .80),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? Tokens.tankGlowSoft
                    : Tokens.tankGlow.withValues(alpha: .18),
              ),
            ),
            child: Row(
              children: [
                if (selected) ...[
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: Tokens.tankGlowSoft,
                  ),
                  const SizedBox(width: 7),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        labelOf(items[index]),
                        maxLines: 1,
                        style: TextStyle(
                          color: selected ? Tokens.text : Tokens.textDim,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        noteOf(items[index]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Tokens.textDim,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PatternChoices extends StatelessWidget {
  const _PatternChoices({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CompactChips<CustomFishPattern>(
          items: customFishPatterns,
          selectedIndex: selectedIndex,
          labelOf: (item) => item.label,
          onSelected: onSelected,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Tokens.surface.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            children: [
              Icon(Icons.eco_outlined, color: Tokens.tankGlowSoft),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '同一种纹样会根据体型重新分布；双色腹沿腹线生长，鞍斑从背线向下生长。',
                  style: TextStyle(color: Tokens.textDim, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudioPatternPanel extends StatelessWidget {
  const _StudioPatternPanel({
    required this.appearance,
    required this.selectedIndex,
    required this.onSelected,
    required this.density,
    required this.softness,
    required this.individualSeed,
    required this.onDensityChanged,
    required this.onSoftnessChanged,
    this.useGrid = false,
    this.largeCards = false,
  });

  final CustomFishAppearance appearance;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double density;
  final double softness;
  final int individualSeed;
  final ValueChanged<double> onDensityChanged;
  final ValueChanged<double> onSoftnessChanged;
  final bool useGrid;
  final bool largeCards;

  Widget _tile(int index) {
    final item = customFishPatterns[index];
    final selected = index == selectedIndex;
    return Semantics(
      button: true,
      selected: selected,
      label: '${item.label}纹样',
      child: InkWell(
        key: ValueKey('studio-pattern-${item.id}'),
        onTap: () => onSelected(index),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? Tokens.tankGlow.withValues(alpha: .18)
                : Tokens.surface.withValues(alpha: .7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? Tokens.tankGlowSoft
                  : Tokens.tankGlow.withValues(alpha: .2),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: CustomFishSprite(
                      appearance: CustomFishAppearance(
                        body: appearance.body,
                        tail: appearance.tail,
                        pattern: item.id,
                        color: appearance.color,
                      ),
                      width: 130,
                      patternTuning: CustomFishPatternTuning(
                        density: density,
                        softness: softness,
                        individualSeed: individualSeed,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 13,
                  color: selected ? Tokens.text : Tokens.textDim,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (largeCards) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (useGrid)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 104,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: customFishPatterns.length,
              itemBuilder: (_, index) => _tile(index),
            )
          else
            SizedBox(
              height: 104,
              child: ScrollConfiguration(
                behavior: const MaterialScrollBehavior().copyWith(
                  dragDevices: const {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.stylus,
                  },
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: customFishPatterns.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, index) =>
                      SizedBox(width: 108, child: _tile(index)),
                ),
              ),
            ),
          const SizedBox(height: 16),
          _NaturalPatternSlider(
            label: '疏密',
            value: density,
            semanticsLabel: '纹样疏密',
            onChanged: onDensityChanged,
          ),
          const SizedBox(height: 4),
          _NaturalPatternSlider(
            label: '柔和度',
            value: softness,
            semanticsLabel: '纹样边缘柔和度',
            onChanged: onSoftnessChanged,
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 82,
          child: ScrollConfiguration(
            behavior: const MaterialScrollBehavior().copyWith(
              dragDevices: const {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.stylus,
              },
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: customFishPatterns.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final item = customFishPatterns[index];
                final selected = index == selectedIndex;
                final previewAppearance = CustomFishAppearance(
                  body: appearance.body,
                  tail: appearance.tail,
                  pattern: item.id,
                  color: appearance.color,
                );
                return Semantics(
                  button: true,
                  selected: selected,
                  label: '${item.label}纹样',
                  child: InkWell(
                    key: ValueKey('studio-pattern-${item.id}'),
                    onTap: () => onSelected(index),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 84,
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
                      decoration: BoxDecoration(
                        color: selected
                            ? Tokens.tankGlow.withValues(alpha: .15)
                            : Tokens.surface.withValues(alpha: .74),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? Tokens.tankGlowSoft
                              : Tokens.tankGlow.withValues(alpha: .14),
                        ),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: CustomFishSprite(
                                appearance: previewAppearance,
                                width: 65,
                                patternTuning: CustomFishPatternTuning(
                                  density: density,
                                  softness: softness,
                                  individualSeed: individualSeed + index * 17,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            item.label,
                            maxLines: 1,
                            style: TextStyle(
                              color: selected ? Tokens.text : Tokens.textDim,
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        _NaturalPatternSlider(
          label: '疏密',
          value: density,
          semanticsLabel: '纹样疏密',
          onChanged: onDensityChanged,
        ),
        _NaturalPatternSlider(
          label: '柔和度',
          value: softness,
          semanticsLabel: '纹样边缘柔和度',
          onChanged: onSoftnessChanged,
        ),
      ],
    );
  }
}

class _NaturalPatternSlider extends StatelessWidget {
  const _NaturalPatternSlider({
    required this.label,
    required this.value,
    required this.semanticsLabel,
    required this.onChanged,
  });

  final String label;
  final double value;
  final String semanticsLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 43,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: const TextStyle(
                color: Tokens.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Tokens.tankGlowSoft,
                inactiveTrackColor: Tokens.tankGlow.withValues(alpha: .18),
                thumbColor: Tokens.tankGlowSoft,
                overlayColor: Tokens.tankGlow.withValues(alpha: .10),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 15),
              ),
              child: Semantics(
                label: semanticsLabel,
                value: '${(value * 100).round()}%',
                child: Slider(value: value, onChanged: onChanged),
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '${(value * 100).round()}',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Tokens.textDim, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactChips<T> extends StatelessWidget {
  const _CompactChips({
    required this.items,
    required this.selectedIndex,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> items;
  final int selectedIndex;
  final String Function(T item) labelOf;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(items.length, (index) {
        return ChoiceChip(
          key: ValueKey('studio-choice-${labelOf(items[index])}'),
          selected: selectedIndex == index,
          onSelected: (_) => onSelected(index),
          label: Text(labelOf(items[index])),
          selectedColor: Tokens.tankGlow.withValues(alpha: .20),
          backgroundColor: Tokens.surface,
          side: BorderSide(
            color: selectedIndex == index
                ? Tokens.tankGlowSoft
                : Tokens.tankGlow.withValues(alpha: .16),
          ),
          labelStyle: TextStyle(
            color: selectedIndex == index ? Tokens.text : Tokens.textDim,
          ),
        );
      }),
    );
  }
}

class _ColorChoices extends StatelessWidget {
  const _ColorChoices({
    required this.selectedIndex,
    required this.onSelected,
    this.compact = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(customFishColors.length, (index) {
        final item = customFishColors[index];
        final selected = index == selectedIndex;
        return InkWell(
          key: ValueKey('studio-color-${item.id}'),
          onTap: () => onSelected(index),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: compact ? 42 : null,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 12,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? item.color.withValues(alpha: .18)
                  : Tokens.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? item.color
                    : Tokens.tankGlow.withValues(alpha: .15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 7),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? Tokens.text : Tokens.textDim,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _NameAndSummary extends StatelessWidget {
  const _NameAndSummary({required this.appearance, required this.controller});

  final CustomFishAppearance appearance;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          maxLength: 20,
          style: const TextStyle(color: Tokens.text),
          decoration: _prototypeInputDecoration('例如：云尾'),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Tokens.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Tokens.tankGlow.withValues(alpha: .18)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Tokens.tankGlowSoft),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${appearance.summary}\n纹样自然适配 · 个体差异已保留',
                  style: const TextStyle(color: Tokens.textDim, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuidedActions extends StatelessWidget {
  const _GuidedActions({
    required this.step,
    required this.onBack,
    required this.onNext,
  });

  final int step;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
      decoration: BoxDecoration(
        color: Tokens.primaryBg.withValues(alpha: .97),
        border: Border(
          top: BorderSide(color: Tokens.tankGlow.withValues(alpha: .15)),
        ),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            OutlinedButton(onPressed: onBack, child: const Text('上一步')),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: FilledButton(
              onPressed: onNext,
              child: Text(step == 4 ? '预览放入鱼缸' : '继续'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.prominent = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('studio-tool-$label'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: EdgeInsets.symmetric(horizontal: 5, vertical: prominent ? 9 : 7),
        decoration: BoxDecoration(
          color: prominent && selected ? Tokens.tankGlow.withValues(alpha: .12) : null,
          borderRadius: BorderRadius.circular(14),
          border: prominent && selected ? Border.all(color: Tokens.tankGlowSoft) : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: prominent ? 22 : 19,
              color: selected ? Tokens.tankGlowSoft : Tokens.textDim,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected ? Tokens.text : Tokens.textDim,
                fontSize: prominent ? 12 : 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onTap});

  final _FishTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appearance = CustomFishAppearance(
      body: customFishBodies[template.bodyIndex].id,
      tail: customFishTails[template.tailIndex].id,
      pattern: customFishPatterns[template.patternIndex].id,
      color: customFishColors[template.colorIndex].id,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/tank/background.png'),
            fit: BoxFit.cover,
            opacity: .38,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Tokens.tankGlow.withValues(alpha: .24)),
        ),
        child: Column(
          children: [
            Expanded(
              child: CustomFishSprite(appearance: appearance, width: 130),
            ),
            Text(
              template.name,
              style: const TextStyle(
                color: Tokens.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              template.note,
              style: const TextStyle(color: Tokens.textDim, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefineRow extends StatelessWidget {
  const _RefineRow({
    required this.title,
    required this.current,
    required this.onPrevious,
    required this.onNext,
    this.dotColor,
  });

  final String title;
  final String current;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Tokens.surface,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            SizedBox(
              width: 48,
              child: Text(title, style: const TextStyle(color: Tokens.textDim)),
            ),
            IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (dotColor != null) ...[
                    Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    current,
                    style: const TextStyle(
                      color: Tokens.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _PrototypeSwitcher extends StatelessWidget {
  const _PrototypeSwitcher({
    required this.current,
    required this.onPrevious,
    required this.onNext,
  });

  final _PrototypeVariant current;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 14,
      child: SafeArea(
        top: false,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF07131D).withValues(alpha: .98),
              borderRadius: BorderRadius.circular(31),
              border: Border.all(color: Tokens.tankGlowSoft),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: onPrevious,
                  tooltip: '上一版',
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${current.key} · ${current.name}',
                        style: const TextStyle(
                          color: Tokens.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        '左右箭头切换完整体验',
                        style: TextStyle(color: Tokens.textDim, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onNext,
                  tooltip: '下一版',
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaterRingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Tokens.tankGlow.withValues(alpha: .08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var index = 0; index < 4; index++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * .5, size.height * .48),
          width: size.width * (.44 + index * .18),
          height: size.height * (.16 + index * .07),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

InputDecoration _prototypeInputDecoration(String hint, {String? errorText}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Tokens.textDim),
      errorText: errorText,
      counterStyle: const TextStyle(color: Tokens.textDim),
      filled: true,
      fillColor: Tokens.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Tokens.tankGlow.withValues(alpha: .18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Tokens.tankGlowSoft),
      ),
    );

class _PrototypeVariant {
  const _PrototypeVariant({required this.key, required this.name});

  final String key;
  final String name;
}

class _FishTemplate {
  const _FishTemplate({
    required this.name,
    required this.note,
    required this.bodyIndex,
    required this.tailIndex,
    required this.patternIndex,
    required this.colorIndex,
  });

  final String name;
  final String note;
  final int bodyIndex;
  final int tailIndex;
  final int patternIndex;
  final int colorIndex;
}
