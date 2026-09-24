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
import '../feeding/fish_action_sheet.dart';
import '../feeding/satiety.dart';
import '../feeding/tank_feeding.dart';
import '../fish/custom_fish_sprite.dart';
import '../fish/fish_models.dart';
import '../fish/fish_providers.dart';
import '../fish/fish_sprite.dart';
import '../presence/presence_interaction.dart';
import 'tank.dart';
import '../temperature/temperature_sheet.dart';
import '../temperature/water_temperature.dart';
import '../weather/weather_atmosphere.dart';
import '../weather/weather_models.dart';
import '../weather/weather_sheet.dart';
import 'fish_swim_profile.dart';

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
          return _TankHome(tank: tank);
        },
      ),
    );
  }
}

class _TankHome extends ConsumerStatefulWidget {
  const _TankHome({required this.tank});

  final Tank tank;

  @override
  ConsumerState<_TankHome> createState() => _TankHomeState();
}

class _TankHomeState extends ConsumerState<_TankHome>
    with WidgetsBindingObserver {
  List<FishInstance> _visibleFish = const <FishInstance>[];
  DateTime? _recordedLastSeenAt;
  WeatherSnapshot? _previewWeather;
  int? _previewWaterTemperature;
  var _greetingToken = 0;
  var _feedingToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_syncTankSatiety());
    unawaited(_syncTankGrowth());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final pausedAt = DateTime.now();
      _recordedLastSeenAt = pausedAt;
      unawaited(_recordLastSeen(pausedAt));
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final lastSeenAt = _recordedLastSeenAt;
      _recordedLastSeenAt = null;
      if (lastSeenAt != null &&
          shouldGreetAfterAbsence(
            lastSeenAt: lastSeenAt,
            now: DateTime.now(),
          ) &&
          mounted) {
        setState(() => _greetingToken += 1);
      }
    }
  }

  Future<void> _recordLastSeen(DateTime pausedAt) async {
    try {
      await ref
          .read(fishRepositoryProvider)
          .updateLastSeen(
            fishIds: _visibleFish.map((fish) => fish.id),
            at: pausedAt,
          );
    } catch (_) {
      // Presence is ambient: a transient offline failure must not interrupt
      // the player when they return to the tank.
    }
  }

  Future<void> _syncTankSatiety() async {
    try {
      await ref.read(fishRepositoryProvider).syncTankSatiety(widget.tank.id);
    } catch (_) {
      // The realtime fish stream still renders the last known gentle state.
    }
  }

  Future<void> _syncTankGrowth() async {
    try {
      await ref.read(fishRepositoryProvider).syncTankGrowth(widget.tank.id);
    } catch (_) {
      // Existing realtime rows remain visible if the growth sync is offline.
    }
  }

  @override
  Widget build(BuildContext context) {
    final fishAsync = ref.watch(tankFishProvider(widget.tank.id));
    final catalogAsync = ref.watch(fishCatalogProvider);
    final decorationsAsync = ref.watch(tankDecorationsProvider(widget.tank.id));
    final fish = fishAsync.value ?? const <FishInstance>[];
    final decorations = decorationsAsync.value ?? const <TankDecoration>[];
    final catalog = catalogAsync.value;
    final loading =
        fishAsync.isLoading ||
        catalogAsync.isLoading ||
        decorationsAsync.isLoading;
    _visibleFish = fish;
    final weather = _previewWeather ?? widget.tank.weather;
    final waterTemperature =
        _previewWaterTemperature ?? widget.tank.waterTemperature;
    final residentSpecies = catalog == null
        ? const <FishSpecies>[]
        : _residentSpecies(fish, catalog);

    return SafeArea(
      child: Column(
        children: [
          _HomeHeader(
            count: fish.length,
            weather: weather,
            onWeatherTap: _openWeatherSheet,
            waterTemperature: waterTemperature,
            onTemperatureTap: () => _openTemperatureSheet(residentSpecies),
            onSignOut: () => _signOut(context),
          ),
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
                          onResizeDecoration: _resizeDecoration,
                          onRemoveDecoration: _removeDecoration,
                          onFishTapped: (selectedFish) =>
                              _openFishActions(selectedFish, catalog),
                          greetingToken: _greetingToken,
                          feedingToken: _feedingToken,
                          weather: weather,
                          waterTemperature: waterTemperature,
                        ),
                ),
              ),
            ),
          ),
          _TankNavigation(
            fishCount: fish.length,
            onFeed: () => _openTankFeeding(fish),
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
      builder: (_) => DecorationSheet(tankId: widget.tank.id),
    );
  }

  Future<void> _openFishActions(FishInstance fish, FishCatalog catalog) async {
    final identity = _resolveCatalogIdentity(fish, catalog);
    final traits = catalog.traits
        .where((trait) => fish.traitIds.contains(trait.id))
        .toList(growable: false);
    final released = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FishActionSheet(
        fish: fish,
        traits: traits,
        species: identity?.$1,
        variant: identity?.$2,
        onRelease: () => ref.read(fishRepositoryProvider).releaseFish(fish.id),
      ),
    );
    if (released == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已经和${fish.name}好好说过再见了。')));
    }
  }

  (FishSpecies, FishVariant)? _resolveCatalogIdentity(
    FishInstance fish,
    FishCatalog catalog,
  ) {
    if (fish.speciesId == null || fish.variantId == null) return null;
    for (final species in catalog.species) {
      if (species.id != fish.speciesId) continue;
      for (final variant in species.variants) {
        if (variant.id == fish.variantId) return (species, variant);
      }
    }
    return null;
  }

  Future<void> _openTankFeeding(List<FishInstance> fish) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => TankFeedingSheet(
        tankId: widget.tank.id,
        fish: fish,
        onFed: () {
          if (mounted) setState(() => _feedingToken += 1);
        },
      ),
    );
  }

  Future<void> _openWeatherSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WeatherSheet(
        tank: widget.tank,
        onPreviewChanged: (weather) {
          if (mounted) setState(() => _previewWeather = weather);
        },
      ),
    );
  }

  Future<void> _openTemperatureSheet(List<FishSpecies> residentSpecies) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TemperatureSheet(
        tank: widget.tank,
        residentSpecies: residentSpecies,
        onPreviewChanged: (temperature) {
          if (mounted) setState(() => _previewWaterTemperature = temperature);
        },
      ),
    );
  }

  List<FishSpecies> _residentSpecies(
    List<FishInstance> fish,
    FishCatalog catalog,
  ) {
    final byId = <String, FishSpecies>{
      for (final species in catalog.species) species.id: species,
    };
    return fish
        .map((item) => byId[item.speciesId])
        .whereType<FishSpecies>()
        .toList(growable: false);
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

  Future<void> _resizeDecoration((TankDecoration, double) change) async {
    try {
      await ref
          .read(decorationRepositoryProvider)
          .resizeDecoration(decoration: change.$1, scaleFactor: change.$2);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时没能调整装饰大小，再试一次吧')));
      }
    }
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.count,
    required this.weather,
    required this.onWeatherTap,
    required this.waterTemperature,
    required this.onTemperatureTap,
    required this.onSignOut,
  });

  final int count;
  final WeatherSnapshot? weather;
  final VoidCallback onWeatherTap;
  final int waterTemperature;
  final VoidCallback onTemperatureTap;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 12 : 22,
            10,
            compact ? 4 : 14,
            4,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'yopet',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    color: Tokens.text,
                    fontFamily: 'serif',
                    fontSize: compact ? 30 : 36,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 6 : 10,
                  vertical: compact ? 7 : 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Tokens.tankGlow.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '$count / 5',
                  style: TextStyle(
                    color: Tokens.text,
                    fontSize: compact ? 12 : 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: compact ? 4 : 8),
              _WeatherStatusButton(
                weather: weather,
                onTap: onWeatherTap,
                compact: compact,
              ),
              SizedBox(width: compact ? 3 : 6),
              _TemperatureStatusButton(
                temperature: waterTemperature,
                onTap: onTemperatureTap,
                compact: compact,
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(
                  width: compact ? 34 : 40,
                  height: 40,
                ),
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
      },
    );
  }
}

class _WeatherStatusButton extends StatelessWidget {
  const _WeatherStatusButton({
    required this.weather,
    required this.onTap,
    required this.compact,
  });

  final WeatherSnapshot? weather;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: weather == null
          ? '设置天气氛围'
          : '${weather!.cityName}${weather!.labelZh}，${weather!.temperatureLabel}，打开天气氛围设置',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: EdgeInsets.all(compact ? 6 : 9),
          decoration: BoxDecoration(
            color: Tokens.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Tokens.tankGlow.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                weather?.condition.icon ?? Icons.wb_cloudy_outlined,
                size: 17,
                color: Tokens.tankGlowSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemperatureStatusButton extends StatelessWidget {
  const _TemperatureStatusButton({
    required this.temperature,
    required this.onTap,
    required this.compact,
  });

  final int temperature;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '水温$temperature度，打开水温设置',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 5 : 8,
            vertical: compact ? 7 : 8,
          ),
          decoration: BoxDecoration(
            color: Tokens.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Tokens.amber.withValues(alpha: 0.42)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.thermostat_outlined,
                size: compact ? 15 : 17,
                color: Tokens.amber,
              ),
              const SizedBox(width: 2),
              Text(
                '$temperature°',
                style: TextStyle(
                  color: Tokens.text,
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TankScene extends StatefulWidget {
  const _TankScene({
    required this.fish,
    required this.catalog,
    required this.decorations,
    required this.onMoveDecoration,
    required this.onResizeDecoration,
    required this.onRemoveDecoration,
    required this.onFishTapped,
    required this.greetingToken,
    required this.feedingToken,
    required this.weather,
    required this.waterTemperature,
  });

  final List<FishInstance> fish;
  final FishCatalog catalog;
  final List<TankDecoration> decorations;
  final ValueChanged<(TankDecoration, Offset)> onMoveDecoration;
  final ValueChanged<(TankDecoration, double)> onResizeDecoration;
  final ValueChanged<TankDecoration> onRemoveDecoration;
  final ValueChanged<FishInstance> onFishTapped;
  final int greetingToken;
  final int feedingToken;
  final WeatherSnapshot? weather;
  final int waterTemperature;

  @override
  State<_TankScene> createState() => _TankSceneState();
}

class _TankSceneState extends State<_TankScene> {
  final Map<String, Alignment> _fishPositions = <String, Alignment>{};
  FishTapInteraction? _interaction;
  var _interactionId = 0;

  @override
  void didUpdateWidget(covariant _TankScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIds = widget.fish.map((fish) => fish.id).toSet();
    _fishPositions.removeWhere((fishId, _) => !currentIds.contains(fishId));
  }

  @override
  Widget build(BuildContext context) {
    final activeBackground = widget.decorations.where(
      (decoration) => decoration.type == DecorationType.background,
    );
    final backgroundPath = activeBackground.isEmpty
        ? 'assets/tank/background.png'
        : decorationForCode(activeBackground.first.code)?.assetPath ??
              'assets/tank/background.png';
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _onTankTap(details.localPosition, constraints),
        child: Stack(
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
            WeatherAtmosphere(weather: widget.weather),
            Positioned.fill(
              child: TankDecorationsLayer(
                decorations: widget.decorations,
                onMove: widget.onMoveDecoration,
                onResize: widget.onResizeDecoration,
                onRemove: widget.onRemoveDecoration,
              ),
            ),
            if (widget.fish.isEmpty) const _EmptyTankMessage(),
            for (var index = 0; index < widget.fish.length; index += 1)
              _SwimmingFish(
                key: ValueKey(widget.fish[index].id),
                fish: widget.fish[index],
                swimSlot: index,
                species: _resolveSprite(widget.catalog, widget.fish[index])?.$1,
                variant: _resolveSprite(widget.catalog, widget.fish[index])?.$2,
                traits: widget.catalog.traits
                    .where(
                      (trait) => widget.fish[index].traitIds.contains(trait.id),
                    )
                    .toList(growable: false),
                interaction: _interaction,
                greetingToken: widget.greetingToken,
                weather: widget.weather,
                waterTemperature: widget.waterTemperature,
                onPositionChanged: _recordFishPosition,
                onOpenProfile: () => _selectFish(
                  widget.fish[index],
                  _fishPositions[widget.fish[index].id] ?? Alignment.center,
                ),
              ),
            TankFeedingAnimation(token: widget.feedingToken),
          ],
        ),
      ),
    );
  }

  void _onTankTap(Offset offset, BoxConstraints constraints) {
    if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) return;
    final position = Alignment(
      offset.dx / constraints.maxWidth * 2 - 1,
      offset.dy / constraints.maxHeight * 2 - 1,
    );
    final fishId = _hitFish(position);
    if (fishId == null) return;
    FishInstance? fish;
    for (final item in widget.fish) {
      if (item.id == fishId) {
        fish = item;
        break;
      }
    }
    if (fish == null) return;
    _selectFish(fish, position);
  }

  void _selectFish(FishInstance fish, Alignment tapPosition) {
    setState(() {
      _interactionId += 1;
      _interaction = FishTapInteraction(
        id: _interactionId,
        fishId: fish.id,
        position: tapPosition,
      );
    });
    widget.onFishTapped(fish);
  }

  String? _hitFish(Alignment tapPosition) {
    String? closestId;
    var closestDistance = double.infinity;
    for (final entry in _fishPositions.entries) {
      final dx = (entry.value.x - tapPosition.x) / 0.34;
      final dy = (entry.value.y - tapPosition.y) / 0.28;
      final distance = dx * dx + dy * dy;
      if (distance <= 1 && distance < closestDistance) {
        closestId = entry.key;
        closestDistance = distance;
      }
    }
    return closestId;
  }

  void _recordFishPosition(String fishId, Alignment position) {
    _fishPositions[fishId] = position;
  }

  (FishSpecies, FishVariant)? _resolveSprite(
    FishCatalog catalog,
    FishInstance fish,
  ) {
    if (fish.speciesId == null || fish.variantId == null) return null;
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
    required this.swimSlot,
    required this.traits,
    required this.interaction,
    required this.greetingToken,
    required this.weather,
    required this.waterTemperature,
    required this.onPositionChanged,
    required this.onOpenProfile,
    super.key,
  });

  final FishInstance fish;
  final FishSpecies? species;
  final FishVariant? variant;
  final int swimSlot;
  final List<PersonalityTrait> traits;
  final FishTapInteraction? interaction;
  final int greetingToken;
  final WeatherSnapshot? weather;
  final int waterTemperature;
  final void Function(String fishId, Alignment position) onPositionChanged;
  final VoidCallback onOpenProfile;

  @override
  State<_SwimmingFish> createState() => _SwimmingFishState();
}

class _SwimmingFishState extends State<_SwimmingFish>
    with SingleTickerProviderStateMixin {
  late final Random _random;
  late final FishSwimProfile _swimProfile;
  late Alignment _position;
  Timer? _timer;
  Timer? _reactionTimer;
  bool _facingLeft = false;
  FishReaction? _activeReaction;
  late final AnimationController _tailController;

  @override
  void initState() {
    super.initState();
    _swimProfile = FishSwimProfile.forFish(
      widget.fish.id,
      swimSlot: widget.swimSlot,
    );
    _random = Random(_swimProfile.routeSeed);
    _position = _nextPosition(initial: true);
    _tailController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    widget.onPositionChanged(widget.fish.id, _position);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer ??= Timer(_swimProfile.initialDelay, _move);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reactionTimer?.cancel();
    _tailController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SwimmingFish oldWidget) {
    super.didUpdateWidget(oldWidget);
    final interaction = widget.interaction;
    if (interaction != null &&
        interaction.id != oldWidget.interaction?.id &&
        interaction.fishId == widget.fish.id) {
      _reactToTap(interaction.position);
    }
    if (widget.greetingToken != oldWidget.greetingToken &&
        widget.greetingToken > 0) {
      _greet();
    }
  }

  void _move() {
    if (!mounted) return;
    if (!MediaQuery.disableAnimationsOf(context)) {
      final next = _nextPosition();
      setState(() {
        _facingLeft = next.x < _position.x;
        _position = next;
      });
      widget.onPositionChanged(widget.fish.id, next);
    }
    final lazy = widget.traits.any((trait) => trait.code == 'lazy');
    final sad = isLowSatiety(widget.fish.satiety);
    final seconds = (sad ? 8 : (lazy ? 7 : 4)) + _random.nextInt(4);
    _timer = Timer(_activityAdjustedDuration(seconds), _move);
  }

  void _reactToTap(Alignment tapPosition) {
    final reaction = reactionForTraitCodes(
      widget.traits.map((trait) => trait.code),
    );
    if (reaction == FishReaction.lazy) return;
    _startReaction(
      reaction: reaction,
      destination: reactionDestination(
        reaction: reaction,
        currentPosition: _position,
        tapPosition: tapPosition,
      ),
      duration: const Duration(milliseconds: 1500),
    );
  }

  void _greet() {
    _startReaction(
      reaction: FishReaction.greeting,
      destination: reactionDestination(
        reaction: FishReaction.greeting,
        currentPosition: _position,
        tapPosition: _position,
      ),
      duration: const Duration(seconds: 2),
    );
  }

  void _startReaction({
    required FishReaction reaction,
    required Alignment destination,
    required Duration duration,
  }) {
    _timer?.cancel();
    _reactionTimer?.cancel();
    _tailController.repeat(reverse: true);
    setState(() {
      _activeReaction = reaction;
      _facingLeft = destination.x < _position.x;
      _position = destination;
    });
    widget.onPositionChanged(widget.fish.id, destination);
    _reactionTimer = Timer(duration, () {
      if (!mounted) return;
      _tailController
        ..stop()
        ..value = 0;
      setState(() => _activeReaction = null);
      _move();
    });
  }

  Alignment _nextPosition({bool initial = false}) {
    if (isLowSatiety(widget.fish.satiety)) {
      final seed = _swimProfile.routeSeed;
      final cornerX = seed.isEven ? -0.66 : 0.66;
      final cornerY = seed % 3 == 0 ? -0.54 : 0.5;
      return Alignment(
        cornerX + (_random.nextDouble() - 0.5) * 0.16,
        cornerY + (_random.nextDouble() - 0.5) * 0.12,
      );
    }
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
    final x =
        (_swimProfile.horizontalCenter +
                (_random.nextDouble() - 0.5) * _swimProfile.horizontalSpan)
            .clamp(-0.78, 0.78)
            .toDouble();
    final y =
        (minY +
                _random.nextDouble() * (maxY - minY) +
                _swimProfile.verticalBias)
            .clamp(minY, maxY)
            .toDouble();
    return Alignment(initial ? x * 0.85 : x, y);
  }

  Duration _activityAdjustedDuration(int seconds) {
    final weatherMultiplier =
        widget.weather?.condition.activityMultiplier ?? 1.0;
    final temperatureMultiplier = comfortForWaterTemperature(
      temperature: widget.waterTemperature,
      preferredMin: widget.species?.preferredTemperatureMin ?? 22,
      preferredMax: widget.species?.preferredTemperatureMax ?? 26,
    ).activityMultiplier;
    final multiplier =
        (weatherMultiplier *
                temperatureMultiplier *
                _swimProfile.tempoMultiplier)
            .clamp(0.65, 1.18);
    final milliseconds = (seconds * 1000 / multiplier).round().clamp(
      2200,
      14000,
    );
    return Duration(milliseconds: milliseconds);
  }

  @override
  Widget build(BuildContext context) {
    final fast = widget.traits.any((trait) => trait.code == 'bold');
    final lazy = widget.traits.any((trait) => trait.code == 'lazy');
    final sad = isLowSatiety(widget.fish.satiety);
    final duration = _activeReaction == null
        ? _activityAdjustedDuration(sad ? 10 : (lazy ? 7 : (fast ? 3 : 5)))
        : _activeReaction == FishReaction.greeting
        ? const Duration(seconds: 2)
        : const Duration(milliseconds: 1500);
    final appearance = widget.fish.customAppearance;
    final activityLabel = sad
        ? '${widget.fish.name}正在角落缓缓游动'
        : widget.weather == null
        ? '${widget.fish.name}正在鱼缸里游动'
        : '${widget.weather!.labelZh}时，${widget.fish.name}正在鱼缸里游动';
    final Widget sprite;
    if (appearance != null) {
      sprite = CustomFishSprite(
        appearance: appearance,
        growthStage: widget.fish.growthStage,
        facingLeft: _facingLeft,
        width: 108,
      );
    } else if (widget.species != null && widget.variant != null) {
      sprite = FishSprite(
        species: widget.species!,
        variant: widget.variant!,
        growthStage: widget.fish.growthStage,
        facingLeft: _facingLeft,
        width: 108,
      );
    } else {
      sprite = const Icon(
        Icons.set_meal_rounded,
        color: Tokens.tankGlow,
        size: 64,
      );
    }
    return AnimatedAlign(
      alignment: _position,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : duration,
      curve: _swimProfile.curve,
      child: Semantics(
        button: true,
        label: '$activityLabel，打开档案',
        onTap: widget.onOpenProfile,
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _tailController,
                child: sprite,
                builder: (context, child) => Transform.rotate(
                  alignment: const Alignment(0.62, 0),
                  angle: sin(_tailController.value * pi * 2) * 0.045,
                  child: child,
                ),
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
    required this.onFeed,
    required this.onAdopt,
    required this.onDecorate,
  });

  final int fishCount;
  final VoidCallback onFeed;
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
          _NavItem(
            key: const Key('feed-tank'),
            icon: Icons.restaurant_rounded,
            label: '一起喂食',
            onTap: onFeed,
          ),
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
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
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
        ),
      ),
    );
  }
}
