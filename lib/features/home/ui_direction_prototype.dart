import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/tokens.dart';

/// PROTOTYPE ONLY — Three radically different YoPet home directions,
/// switchable with `?variant=A|B|C` on `/prototype/ui-direction`.
///
/// Research question: which home-screen structure turns a five-minute pause
/// into a desirable ritual for a first-time fish keeper?  Everything below is
/// static in-memory research data; it must not be promoted straight to F6.
class UiDirectionPrototypeScreen extends StatefulWidget {
  const UiDirectionPrototypeScreen({super.key, required this.initialVariant});

  final String initialVariant;

  @override
  State<UiDirectionPrototypeScreen> createState() =>
      _UiDirectionPrototypeScreenState();
}

class _UiDirectionPrototypeScreenState
    extends State<UiDirectionPrototypeScreen> {
  static const _variants = <_PrototypeVariant>[
    _PrototypeVariant(key: 'A', name: '沉浸鱼缸', question: '是否应该把“看鱼”放在所有信息之前？'),
    _PrototypeVariant(key: 'B', name: '鱼的肖像馆', question: '是否应该先把每条鱼当作可认识的角色？'),
    _PrototypeVariant(
      key: 'C',
      name: '安静的每日仪式',
      question: '是否应该先给用户一个轻量的回来理由？',
    ),
  ];

  late String _variant;

  @override
  void initState() {
    super.initState();
    _variant = _normalise(widget.initialVariant);
  }

  @override
  void didUpdateWidget(covariant UiDirectionPrototypeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _normalise(widget.initialVariant);
    if (next != _variant) setState(() => _variant = next);
  }

  String _normalise(String value) =>
      _variants.any((variant) => variant.key == value.toUpperCase())
      ? value.toUpperCase()
      : 'A';

  void _move(int offset) {
    final index = _variants.indexWhere((variant) => variant.key == _variant);
    final next = _variants[(index + offset) % _variants.length];
    context.go('/prototype/ui-direction?variant=${next.key}');
  }

  @override
  Widget build(BuildContext context) {
    final current = _variants.firstWhere((variant) => variant.key == _variant);

    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _move(-1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _move(1);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Tokens.primaryBg,
        body: Stack(
          children: [
            switch (_variant) {
              'B' => const _PortraitGalleryVariant(),
              'C' => const _DailyRitualVariant(),
              _ => const _ImmersiveTankVariant(),
            },
            if (kDebugMode)
              _PrototypeSwitcher(
                current: current,
                onPrevious: () => _move(-1),
                onNext: () => _move(1),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImmersiveTankVariant extends StatelessWidget {
  const _ImmersiveTankVariant();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _TankAtmosphere(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 112),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _TopBar(compact: false),
                const Spacer(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _QuietObservation(
                    title: '鱼缸很安静',
                    detail: '三条小鱼正在慢慢游。',
                  ),
                ),
                const SizedBox(height: 24),
                const _ImmersiveActionTray(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PortraitGalleryVariant extends StatelessWidget {
  const _PortraitGalleryVariant();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;
          final rail = _PortraitRail(isWide: isWide);
          final feature = const _FishPortraitFeature();

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
            child: isWide
                ? Row(
                    children: [
                      SizedBox(width: 242, child: rail),
                      const SizedBox(width: 20),
                      Expanded(child: feature),
                    ],
                  )
                : Column(
                    children: [
                      const _TopBar(compact: true),
                      const SizedBox(height: 20),
                      Expanded(child: feature),
                      const SizedBox(height: 16),
                      SizedBox(height: 132, child: rail),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _DailyRitualVariant extends StatelessWidget {
  const _DailyRitualVariant();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 112),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _TopBar(compact: true),
              const SizedBox(height: 38),
              Text(
                '晚一点，\n'
                '来看看它们。',
                style: GoogleFonts.fraunces(
                  color: Tokens.text,
                  fontSize: 36,
                  height: 1.02,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '今天的鱼缸没有需要处理的事。',
                style: TextStyle(color: Tokens.textDim, fontSize: 15),
              ),
              const SizedBox(height: 28),
              const _DailyMomentCard(),
              const SizedBox(height: 18),
              const _SoftStatusRow(),
              const SizedBox(height: 28),
              const _RitualActions(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TankAtmosphere extends StatelessWidget {
  const _TankAtmosphere();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.18, -0.18),
            radius: 1.12,
            colors: [Color(0xFF19394A), Tokens.primaryBg],
          ),
        ),
        child: Stack(
          children: const [
            _SurfaceRipple(),
            Positioned(
              left: 26,
              top: 206,
              child: _SketchFish(
                color: Color(0xFFFFA36B),
                size: 124,
                direction: 1,
                techMarks: true,
              ),
            ),
            Positioned(
              right: 34,
              top: 332,
              child: _SketchFish(
                color: Color(0xFF80C6D0),
                size: 92,
                direction: -1,
              ),
            ),
            Positioned(
              left: 112,
              bottom: 176,
              child: _SketchFish(
                color: Color(0xFFF1C37A),
                size: 76,
                direction: 1,
              ),
            ),
            _PlantSilhouette(),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'yopet',
          style: GoogleFonts.fraunces(
            color: Tokens.text,
            fontSize: compact ? 27 : 31,
            fontWeight: FontWeight.w500,
            letterSpacing: -.5,
          ),
        ),
        const Spacer(),
        const _CapacityPill(),
        const SizedBox(width: 10),
        const _CircleIcon(icon: Icons.tune_rounded),
      ],
    );
  }
}

class _CapacityPill extends StatelessWidget {
  const _CapacityPill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Tokens.surface.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Tokens.tankGlowSoft.withValues(alpha: .18)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '3 / 5',
          style: TextStyle(
            color: Tokens.text,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Tokens.surface.withValues(alpha: .72),
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Icon(icon, size: 18, color: Tokens.textDim),
      ),
    );
  }
}

class _QuietObservation extends StatelessWidget {
  const _QuietObservation({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Tokens.primaryBg.withValues(alpha: .46),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Tokens.text.withValues(alpha: .08)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 18, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Tokens.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(detail, style: const TextStyle(color: Tokens.textDim)),
          ],
        ),
      ),
    );
  }
}

class _ImmersiveActionTray extends StatelessWidget {
  const _ImmersiveActionTray();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Tokens.surface.withValues(alpha: .84),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Tokens.text.withValues(alpha: .08)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        child: Row(
          children: [
            _Action(icon: Icons.water_drop_outlined, label: '看看它们'),
            _Action(icon: Icons.add_rounded, label: '领养一条', active: true),
            _Action(icon: Icons.auto_awesome_outlined, label: '布置鱼缸'),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, this.active = false});

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: active
                  ? Tokens.tankGlow.withValues(alpha: .22)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                icon,
                color: active ? Tokens.tankGlowSoft : Tokens.textDim,
                size: 21,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: active ? Tokens.text : Tokens.textDim,
              fontSize: 11,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PortraitRail extends StatelessWidget {
  const _PortraitRail({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final fish = const [
      _FishItem('团团', Color(0xFFFFA36B), true),
      _FishItem('小满', Color(0xFF80C6D0), false),
      _FishItem('橘子', Color(0xFFF1C37A), false),
    ];
    return isWide
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _TopBar(compact: true),
              const SizedBox(height: 28),
              const Text(
                '你的三条鱼',
                style: TextStyle(
                  color: Tokens.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              ...fish.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FishListTile(item: item),
                ),
              ),
              const Spacer(),
              const _PrototypeNote(text: '研究状态：角色感 · 3 条测试鱼 · 无真实数据'),
            ],
          )
        : ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: fish.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, index) =>
                SizedBox(width: 152, child: _FishListTile(item: fish[index])),
          );
  }
}

class _FishItem {
  const _FishItem(this.name, this.color, this.selected);

  final String name;
  final Color color;
  final bool selected;
}

class _FishListTile extends StatelessWidget {
  const _FishListTile({required this.item});

  final _FishItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: item.selected
            ? Tokens.tankGlow.withValues(alpha: .13)
            : Tokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.selected
              ? Tokens.tankGlowSoft.withValues(alpha: .48)
              : Tokens.text.withValues(alpha: .06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _SketchFish(color: item.color, size: 50, direction: 1),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: Tokens.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    '幼鱼 · 吃饱了',
                    style: TextStyle(color: Tokens.textDim, fontSize: 11),
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

class _FishPortraitFeature extends StatelessWidget {
  const _FishPortraitFeature();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF19394A), Tokens.surface],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Tokens.tankGlowSoft.withValues(alpha: .18)),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: 22,
            top: 22,
            child: _PrototypeNote(text: '选中的鱼 · 团团'),
          ),
          const Center(
            child: _SketchFish(
              color: Color(0xFFFFA36B),
              size: 220,
              direction: 1,
              techMarks: true,
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Tokens.primaryBg.withValues(alpha: .48),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '团团',
                            style: TextStyle(
                              color: Tokens.text,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '好奇 · 爱追着气泡游',
                            style: TextStyle(color: Tokens.textDim),
                          ),
                        ],
                      ),
                    ),
                    _CircleIcon(icon: Icons.arrow_outward_rounded),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyMomentCard extends StatelessWidget {
  const _DailyMomentCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 294,
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Tokens.text.withValues(alpha: .07)),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 20,
            left: 22,
            child: Text(
              '今天的小片刻',
              style: TextStyle(
                color: Tokens.textDim,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Center(
            child: _SketchFish(
              color: Color(0xFFFFA36B),
              size: 156,
              direction: 1,
              techMarks: true,
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 20,
            child: Text(
              '团团刚刚绕过了新的水草。',
              style: GoogleFonts.fraunces(
                color: Tokens.text,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftStatusRow extends StatelessWidget {
  const _SoftStatusRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _SoftStatus(label: '水温', value: '24°', icon: Icons.thermostat),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _SoftStatus(
            label: '小鱼',
            value: '3 条',
            icon: Icons.waves_outlined,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _SoftStatus(
            label: '今天',
            value: '很好',
            icon: Icons.check_circle_outline,
          ),
        ),
      ],
    );
  }
}

class _SoftStatus extends StatelessWidget {
  const _SoftStatus({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: Tokens.tankGlowSoft),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(
                color: Tokens.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Tokens.textDim, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _RitualActions extends StatelessWidget {
  const _RitualActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.water_drop_outlined),
            label: const Text('走进鱼缸'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Tokens.tankGlowSoft,
              side: BorderSide(
                color: Tokens.tankGlowSoft.withValues(alpha: .55),
              ),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_rounded),
            label: const Text('领养一条'),
            style: FilledButton.styleFrom(
              backgroundColor: Tokens.tankGlow,
              foregroundColor: Tokens.primaryBg,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ],
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
      bottom: 16,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF081017).withValues(alpha: .96),
            borderRadius: BorderRadius.circular(99),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
            border: Border.all(
              color: Tokens.tankGlowSoft.withValues(alpha: .32),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '上一个方案（←）',
                    onPressed: onPrevious,
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Tokens.text,
                  ),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${current.key} · ${current.name}',
                          style: const TextStyle(
                            color: Tokens.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          current.question,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Tokens.textDim,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '下一个方案（→）',
                    onPressed: onNext,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    color: Tokens.text,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrototypeVariant {
  const _PrototypeVariant({
    required this.key,
    required this.name,
    required this.question,
  });

  final String key;
  final String name;
  final String question;
}

class _PrototypeNote extends StatelessWidget {
  const _PrototypeNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Tokens.primaryBg.withValues(alpha: .64),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(color: Tokens.textDim, fontSize: 10),
        ),
      ),
    );
  }
}

class _SurfaceRipple extends StatelessWidget {
  const _SurfaceRipple();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 2,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              Tokens.tankGlowSoft,
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _PlantSilhouette extends StatelessWidget {
  const _PlantSilhouette();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 200,
      child: CustomPaint(painter: _PlantPainter()),
    );
  }
}

/// The prototype deliberately draws its own fish instead of consuming an
/// asset.  It lets reviewers assess the line + watercolor + quiet-tech visual
/// language before a production sprite pipeline is selected.
class _SketchFish extends StatelessWidget {
  const _SketchFish({
    required this.color,
    required this.size,
    required this.direction,
    this.techMarks = false,
  });

  final Color color;
  final double size;
  final int direction;
  final bool techMarks;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.72,
      height: size,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(direction.toDouble(), 1, 1),
        child: CustomPaint(
          painter: _SketchFishPainter(color: color, techMarks: techMarks),
        ),
      ),
    );
  }
}

class _SketchFishPainter extends CustomPainter {
  const _SketchFishPainter({required this.color, required this.techMarks});

  final Color color;
  final bool techMarks;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.height;
    final outline = Paint()
      ..color = const Color(0xFF10263A).withValues(alpha: .92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * .036
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final wash = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: .78), color.withValues(alpha: .38)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    final paleWash = Paint()
      ..color = const Color(0xFFF7E8D4).withValues(alpha: .72);

    final body = Path()
      ..moveTo(unit * .20, unit * .50)
      ..cubicTo(
        unit * .30,
        unit * .12,
        unit * .86,
        unit * .08,
        unit * 1.08,
        unit * .44,
      )
      ..cubicTo(
        unit * 1.19,
        unit * .62,
        unit * .82,
        unit * .88,
        unit * .34,
        unit * .78,
      )
      ..cubicTo(
        unit * .22,
        unit * .72,
        unit * .16,
        unit * .62,
        unit * .20,
        unit * .50,
      )
      ..close();
    final tail = Path()
      ..moveTo(unit * 1.01, unit * .40)
      ..cubicTo(
        unit * 1.32,
        unit * .02,
        unit * 1.62,
        unit * .15,
        unit * 1.62,
        unit * .37,
      )
      ..cubicTo(
        unit * 1.60,
        unit * .50,
        unit * 1.38,
        unit * .55,
        unit * 1.21,
        unit * .51,
      )
      ..cubicTo(
        unit * 1.45,
        unit * .67,
        unit * 1.59,
        unit * .93,
        unit * 1.42,
        unit * 1.00,
      )
      ..cubicTo(
        unit * 1.23,
        unit * .96,
        unit * 1.05,
        unit * .73,
        unit * 1.00,
        unit * .57,
      )
      ..close();
    final dorsal = Path()
      ..moveTo(unit * .56, unit * .22)
      ..cubicTo(
        unit * .60,
        unit * .02,
        unit * .86,
        unit * .02,
        unit * .94,
        unit * .31,
      )
      ..close();
    final lowerFin = Path()
      ..moveTo(unit * .55, unit * .73)
      ..cubicTo(
        unit * .63,
        unit * .93,
        unit * .80,
        unit * .95,
        unit * .83,
        unit * .72,
      )
      ..close();

    canvas.drawPath(tail, wash);
    canvas.drawPath(dorsal, paleWash);
    canvas.drawPath(lowerFin, paleWash);
    canvas.drawPath(body, wash);
    canvas.drawPath(tail, outline);
    canvas.drawPath(dorsal, outline);
    canvas.drawPath(lowerFin, outline);
    canvas.drawPath(body, outline);

    final eye = Offset(unit * .35, unit * .45);
    canvas.drawCircle(
      eye,
      unit * .065,
      Paint()..color = const Color(0xFFF7E8D4),
    );
    canvas.drawCircle(
      eye,
      unit * .030,
      Paint()..color = const Color(0xFF10263A),
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(unit * .26, unit * .52),
        width: unit * .17,
        height: unit * .14,
      ),
      -.7,
      1.35,
      false,
      outline,
    );

    final finLine = Paint()
      ..color = outline.color.withValues(alpha: .55)
      ..strokeWidth = unit * .018
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final x = unit * (.68 + (i * .09));
      canvas.drawLine(
        Offset(x, unit * .28),
        Offset(x + unit * .04, unit * .13),
        finLine,
      );
    }
    for (var i = 0; i < 2; i++) {
      final x = unit * (1.14 + (i * .12));
      canvas.drawLine(
        Offset(x, unit * .48),
        Offset(x + unit * .17, unit * (.29 + (i * .18))),
        finLine,
      );
    }

    if (techMarks) {
      final tech = Paint()
        ..color = Tokens.tankGlowSoft.withValues(alpha: .75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * .014;
      canvas.drawArc(
        Rect.fromLTWH(unit * .05, unit * .02, unit * 1.44, unit * .91),
        3.85,
        1.27,
        false,
        tech,
      );
      final node = Paint()..color = Tokens.tankGlowSoft.withValues(alpha: .86);
      canvas.drawCircle(Offset(unit * .22, unit * .10), unit * .032, node);
      canvas.drawCircle(Offset(unit * 1.43, unit * .24), unit * .026, node);
      canvas.drawCircle(Offset(unit * 1.36, unit * .80), unit * .021, node);
    }
  }

  @override
  bool shouldRepaint(covariant _SketchFishPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.techMarks != techMarks;
}

class _PlantPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = Tokens.plant.withValues(alpha: .30)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final leaf = Paint()..color = Tokens.plant.withValues(alpha: .17);
    for (var i = 0; i < 11; i++) {
      final x = (i / 10) * size.width;
      final height = 42 + (i % 4) * 27.0;
      final bend = i.isEven ? 22.0 : -22.0;
      final start = Offset(x, size.height);
      final control = Offset(x + bend, size.height - height * .45);
      final end = Offset(x + bend * .55, size.height - height);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
      canvas.drawPath(path, stem);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(end.dx + 9, end.dy + 7),
          width: 16,
          height: 32,
        ),
        leaf,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PlantPainter oldDelegate) => false;
}
