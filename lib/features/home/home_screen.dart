import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../core/theme/tokens.dart';
import '../../data/decorations.dart';
import '../auth/auth_providers.dart';
import '../decorations/decoration_layer.dart';
import '../decorations/decoration_providers.dart';
import '../decorations/decoration_sheet.dart';
import '../decorations/tank_decoration.dart';
import '../fish/fish_models.dart';
import '../fish/fish_providers.dart';
import '../fish/fish_sprite.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tankAsync = ref.watch(tankStreamProvider);
    return Scaffold(
      backgroundColor: Tokens.primaryBg,
      body: tankAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Tokens.tankGlow),
        ),
        error: (error, _) => const Center(
          child: Text('鱼缸暂时没有回应', style: TextStyle(color: Tokens.text)),
        ),
        data: (tank) {
          if (tank == null) {
            return const Center(
              child: CircularProgressIndicator(color: Tokens.tankGlow),
            );
          }
          return _TankHome(tankId: tank.id);
        },
      ),
    );
  }
}

class _TankHome extends ConsumerStatefulWidget {
  const _TankHome({required this.tankId});

  final String tankId;

  @override
  ConsumerState<_TankHome> createState() => _TankHomeState();
}

class _TankHomeState extends ConsumerState<_TankHome> {
  @override
  Widget build(BuildContext context) {
    final fishAsync = ref.watch(tankFishProvider(widget.tankId));
    final catalogAsync = ref.watch(fishCatalogProvider);
    final decorationsAsync = ref.watch(tankDecorationsProvider(widget.tankId));
    final fish = fishAsync.value ?? const <FishInstance>[];
    final decorations = decorationsAsync.value ?? const <TankDecoration>[];
    final catalog = catalogAsync.value;
    final loading =
        fishAsync.isLoading ||
        catalogAsync.isLoading ||
        decorationsAsync.isLoading;

    return SafeArea(
      child: Column(
        children: [
          _HomeHeader(count: fish.length, onSignOut: () => _signOut(context)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Color(0xFF0D2636)),
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Tokens.tankGlow,
                          ),
                        )
                      : catalog == null
                      ? const Center(
                          child: Text(
                            '鱼种图鉴加载失败',
                            style: TextStyle(color: Tokens.text),
                          ),
                        )
                      : _TankScene(
                          fish: fish,
                          catalog: catalog,
                          decorations: decorations,
                          onMoveDecoration: _moveDecoration,
                          onRemoveDecoration: _removeDecoration,
                        ),
                ),
              ),
            ),
          ),
          _TankNavigation(
            fishCount: fish.length,
            onAdopt: () {
              if (fish.length >= 5) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('鱼缸已经住满 5 条鱼啦')));
              } else {
                context.go('/pick-fish');
              }
            },
            onDecorate: _openDecorationSheet,
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await getSupabase().auth.signOut();
    } on AuthException catch (_) {
      // Router handles an already-ended session.
    }
    if (context.mounted) context.go('/sign-in');
  }

  Future<void> _openDecorationSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DecorationSheet(tankId: widget.tankId),
    );
  }

  Future<void> _moveDecoration((TankDecoration, Offset) change) async {
    try {
      await ref
          .read(decorationRepositoryProvider)
          .moveDecoration(decoration: change.$1, position: change.$2);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时没能移动装饰，再试一次吧')));
      }
    }
  }

  Future<void> _removeDecoration(TankDecoration decoration) async {
    try {
      await ref
          .read(decorationRepositoryProvider)
          .removeDecoration(decoration.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${decorationForCode(decoration.code)?.nameZh ?? '装饰'}已移出鱼缸',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时没能移除装饰，再试一次吧')));
      }
    }
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.count, required this.onSignOut});

  final int count;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 14, 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'yopet',
              style: TextStyle(
                color: Tokens.text,
                fontFamily: 'serif',
                fontSize: 38,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Tokens.tankGlow.withValues(alpha: 0.4)),
            ),
            child: Text(
              '$count / 5',
              style: const TextStyle(
                color: Tokens.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          PopupMenuButton<String>(
            iconColor: Tokens.textDim,
            color: Tokens.surface,
            onSelected: (_) => onSignOut(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'sign-out', child: Text('退出登录')),
            ],
          ),
        ],
      ),
    );
  }
}

class _TankScene extends StatelessWidget {
  const _TankScene({
    required this.fish,
    required this.catalog,
    required this.decorations,
    required this.onMoveDecoration,
    required this.onRemoveDecoration,
  });

  final List<FishInstance> fish;
  final FishCatalog catalog;
  final List<TankDecoration> decorations;
  final ValueChanged<(TankDecoration, Offset)> onMoveDecoration;
  final ValueChanged<TankDecoration> onRemoveDecoration;

  @override
  Widget build(BuildContext context) {
    final activeBackground = decorations.where(
      (decoration) => decoration.type == DecorationType.background,
    );
    final backgroundPath = activeBackground.isEmpty
        ? 'assets/tank/background.png'
        : decorationForCode(activeBackground.first.code)?.assetPath ??
              'assets/tank/background.png';
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(backgroundPath, fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0x44030D18), Color(0x11030D18)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned.fill(
          child: TankDecorationsLayer(
            decorations: decorations,
            onMove: onMoveDecoration,
            onRemove: onRemoveDecoration,
          ),
        ),
        if (fish.isEmpty) const _EmptyTankMessage(),
        for (final item in fish)
          if (_resolveSprite(catalog, item) case final sprite?)
            _SwimmingFish(
              key: ValueKey(item.id),
              fish: item,
              species: sprite.$1,
              variant: sprite.$2,
              traits: catalog.traits
                  .where((trait) => item.traitIds.contains(trait.id))
                  .toList(growable: false),
            ),
      ],
    );
  }

  (FishSpecies, FishVariant)? _resolveSprite(
    FishCatalog catalog,
    FishInstance fish,
  ) {
    for (final species in catalog.species) {
      if (species.id != fish.speciesId) continue;
      for (final variant in species.variants) {
        if (variant.id == fish.variantId) return (species, variant);
      }
    }
    return null;
  }
}

class _SwimmingFish extends StatefulWidget {
  const _SwimmingFish({
    required this.fish,
    required this.species,
    required this.variant,
    required this.traits,
    super.key,
  });

  final FishInstance fish;
  final FishSpecies species;
  final FishVariant variant;
  final List<PersonalityTrait> traits;

  @override
  State<_SwimmingFish> createState() => _SwimmingFishState();
}

class _SwimmingFishState extends State<_SwimmingFish> {
  late final Random _random;
  late Alignment _position;
  Timer? _timer;
  bool _facingLeft = false;

  @override
  void initState() {
    super.initState();
    _random = Random(_stableSeed(widget.fish.id));
    _position = _nextPosition(initial: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer ??= Timer(const Duration(milliseconds: 600), _move);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _move() {
    if (!mounted) return;
    if (!MediaQuery.disableAnimationsOf(context)) {
      final next = _nextPosition();
      setState(() {
        _facingLeft = next.x < _position.x;
        _position = next;
      });
    }
    final lazy = widget.traits.any((trait) => trait.code == 'lazy');
    final seconds = (lazy ? 7 : 4) + _random.nextInt(4);
    _timer = Timer(Duration(seconds: seconds), _move);
  }

  Alignment _nextPosition({bool initial = false}) {
    final codes = widget.traits.map((trait) => trait.code).toSet();
    var minY = -0.7;
    var maxY = 0.62;
    if (codes.contains('shy')) {
      minY = 0.15;
      maxY = 0.72;
    } else if (codes.contains('bold')) {
      minY = -0.78;
      maxY = 0.05;
    } else if (codes.contains('lazy')) {
      minY = 0.05;
      maxY = 0.48;
    } else if (codes.contains('curious')) {
      minY = -0.42;
      maxY = 0.42;
    }
    final x = -0.78 + _random.nextDouble() * 1.56;
    final y = minY + _random.nextDouble() * (maxY - minY);
    return Alignment(initial ? x * 0.85 : x, y);
  }

  static int _stableSeed(String value) {
    var result = 17;
    for (final unit in value.codeUnits) {
      result = 37 * result + unit;
    }
    return result & 0x7fffffff;
  }

  @override
  Widget build(BuildContext context) {
    final fast = widget.traits.any((trait) => trait.code == 'bold');
    final lazy = widget.traits.any((trait) => trait.code == 'lazy');
    final duration = Duration(seconds: lazy ? 7 : (fast ? 3 : 5));
    return AnimatedAlign(
      alignment: _position,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : duration,
      curve: Curves.easeInOutSine,
      child: Semantics(
        label: '${widget.fish.name}正在鱼缸里游动',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FishSprite(
              species: widget.species,
              variant: widget.variant,
              growthStage: widget.fish.growthStage,
              facingLeft: _facingLeft,
              width: 108,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Tokens.primaryBg.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.fish.name,
                style: const TextStyle(color: Tokens.text, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTankMessage extends StatelessWidget {
  const _EmptyTankMessage();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment(-0.45, 0.05),
      child: Text(
        '鱼缸很安静\n领养第一条鱼吧。',
        style: TextStyle(color: Tokens.text, fontSize: 18, height: 1.65),
      ),
    );
  }
}

class _TankNavigation extends StatelessWidget {
  const _TankNavigation({
    required this.fishCount,
    required this.onAdopt,
    required this.onDecorate,
  });

  final int fishCount;
  final VoidCallback onAdopt;
  final VoidCallback onDecorate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Tokens.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Tokens.tankGlow.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const _NavItem(icon: Icons.water_drop_outlined, label: '看看它们'),
          Semantics(
            button: true,
            label: fishCount >= 5 ? '鱼缸已满' : '领养一条鱼',
            child: InkWell(
              key: const Key('adopt-fish'),
              onTap: onAdopt,
              borderRadius: BorderRadius.circular(32),
              child: Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Tokens.tankGlowSoft,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Tokens.primaryBg,
                  size: 32,
                ),
              ),
            ),
          ),
          _NavItem(
            key: const Key('decorate-tank'),
            icon: Icons.auto_awesome_outlined,
            label: '布置鱼缸',
            onTap: onDecorate,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: onTap == null ? Tokens.textDim : Tokens.tankGlowSoft,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: onTap == null ? Tokens.textDim : Tokens.tankGlowSoft,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
