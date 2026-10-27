import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../fish/fish_models.dart';
import '../fish/fish_providers.dart';
import 'satiety.dart';

/// A single, calm action for the whole aquarium. The database still records a
/// meal per fish, but the player experiences feeding as sprinkling food into
/// the water once.
class TankFeedingSheet extends ConsumerStatefulWidget {
  const TankFeedingSheet({
    required this.tankId,
    required this.fish,
    required this.onFed,
    super.key,
  });

  final String tankId;
  final List<FishInstance> fish;
  final VoidCallback onFed;

  @override
  ConsumerState<TankFeedingSheet> createState() => _TankFeedingSheetState();
}

class _TankFeedingSheetState extends ConsumerState<TankFeedingSheet> {
  var _isFeeding = false;

  bool get _everyoneSatisfied =>
      widget.fish.isNotEmpty &&
      widget.fish.every((fish) => fish.satiety >= 100);

  Future<void> _feedTank() async {
    if (_isFeeding || widget.fish.isEmpty || _everyoneSatisfied) return;
    setState(() => _isFeeding = true);
    try {
      await ref.read(fishRepositoryProvider).feedTank(widget.tankId);
      widget.onFed();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${widget.fish.length} 条小鱼一起开饭啦')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时没能投喂，检查网络后再试试。')));
      }
    } finally {
      if (mounted) setState(() => _isFeeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hungryCount = widget.fish
        .where((fish) => isLowSatiety(fish.satiety))
        .length;
    final average = widget.fish.isEmpty
        ? 0
        : widget.fish.map((fish) => fish.satiety).reduce((a, b) => a + b) ~/
              widget.fish.length;
    final available = widget.fish.isNotEmpty && !_everyoneSatisfied;
    final buttonLabel = widget.fish.isEmpty
        ? '先领养一条鱼'
        : _everyoneSatisfied
        ? '大家都吃得很满足'
        : '撒下鱼食 · 全缸 +$defaultFeedAmount';

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        decoration: const BoxDecoration(
          color: Tokens.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Tokens.textDim.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '一起喂食',
                    style: TextStyle(
                      color: Tokens.text,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Tokens.textDim),
                ),
              ],
            ),
            Text(
              widget.fish.isEmpty
                  ? '鱼缸还在等第一位住客。'
                  : '把鱼食撒进水里，让 ${widget.fish.length} 条小鱼各自慢慢游来。',
              style: const TextStyle(color: Tokens.textDim, height: 1.45),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Tokens.primaryBg.withValues(alpha: 0.55),
                border: Border.all(
                  color: Tokens.tankGlow.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Tokens.tankGlowSoft,
                    ),
                    child: const Icon(
                      Icons.restaurant_rounded,
                      color: Tokens.primaryBg,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '全缸平均饱腹度 $average%',
                          style: const TextStyle(
                            color: Tokens.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hungryCount == 0
                              ? '大家精神都不错。'
                              : '$hungryCount 条小鱼有点饿了。',
                          style: TextStyle(
                            color: hungryCount == 0
                                ? Tokens.textDim
                                : Tokens.amber,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                key: const Key('feed-tank-confirm'),
                onPressed: available && !_isFeeding ? _feedTank : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Tokens.tankGlow,
                  foregroundColor: Tokens.primaryBg,
                  disabledBackgroundColor: Tokens.textDim.withValues(
                    alpha: 0.28,
                  ),
                  disabledForegroundColor: Tokens.textDim,
                ),
                icon: _isFeeding
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.grain_rounded),
                label: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A short visual acknowledgement after the owner has successfully fed the
/// tank. It is intentionally non-blocking; the tank also signals each fish to
/// approach its separate portion with a personality-specific delay.
class TankFeedingAnimation extends StatefulWidget {
  const TankFeedingAnimation({required this.token, super.key});

  final int token;

  @override
  State<TankFeedingAnimation> createState() => _TankFeedingAnimationState();
}

class _TankFeedingAnimationState extends State<TankFeedingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    // The initial token is a baseline, not a fresh meal. Mode switches remount
    // this layer with the last token and must not replay historical feeding.
  }

  @override
  void didUpdateWidget(covariant TankFeedingAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.token != oldWidget.token && widget.token > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final time = _controller.value;
          if (time == 0 || time == 1) return const SizedBox.expand();
          return LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                for (var index = 0; index < _pellets.length; index += 1)
                  _FallingPellet(
                    time: time,
                    spec: _pellets[index],
                    size: constraints.biggest,
                  ),
                Align(
                  alignment: const Alignment(0, -0.55),
                  child: Opacity(
                    opacity: sin(pi * (time / 0.75).clamp(0, 1)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Tokens.primaryBg.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Tokens.tankGlow.withValues(alpha: 0.42),
                        ),
                      ),
                      child: const Text(
                        '大家开饭啦',
                        style: TextStyle(
                          color: Tokens.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PelletSpec {
  const _PelletSpec(this.x, this.delay, this.destination, this.size);

  final double x;
  final double delay;
  final double destination;
  final double size;
}

const _pellets = <_PelletSpec>[
  _PelletSpec(0.18, 0.00, 0.58, 8),
  _PelletSpec(0.31, 0.06, 0.72, 6),
  _PelletSpec(0.46, 0.13, 0.53, 7),
  _PelletSpec(0.59, 0.03, 0.68, 8),
  _PelletSpec(0.72, 0.18, 0.59, 6),
  _PelletSpec(0.82, 0.10, 0.76, 7),
  _PelletSpec(0.39, 0.23, 0.66, 5),
  _PelletSpec(0.66, 0.27, 0.48, 6),
];

class _FallingPellet extends StatelessWidget {
  const _FallingPellet({
    required this.time,
    required this.spec,
    required this.size,
  });

  final double time;
  final _PelletSpec spec;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final progress = ((time - spec.delay) / 0.55).clamp(0.0, 1.0);
    if (progress == 0 || progress == 1) return const SizedBox.shrink();
    final eased = Curves.easeIn.transform(progress);
    final opacity = progress < 0.78 ? 1.0 : (1 - progress) / 0.22;
    return Positioned(
      left: size.width * spec.x - spec.size / 2,
      top: size.height * (0.10 + (spec.destination - 0.10) * eased),
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: progress * pi,
          child: Container(
            width: spec.size,
            height: spec.size * 0.72,
            decoration: BoxDecoration(
              color: Tokens.amber,
              borderRadius: BorderRadius.circular(spec.size),
              boxShadow: [
                BoxShadow(
                  color: Tokens.amber.withValues(alpha: 0.36),
                  blurRadius: 7,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
