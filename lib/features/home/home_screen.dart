import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
import '../presence/companion_behavior.dart';
import '../presence/idle_routine.dart';
import '../presence/desktop_routine.dart';
import 'tank.dart';
import '../temperature/temperature_sheet.dart';
import '../temperature/water_temperature.dart';
import '../weather/weather_atmosphere.dart';
import '../weather/weather_models.dart';
import '../weather/weather_sheet.dart';
import 'fish_swim_profile.dart';
import 'fish_motion.dart';
import 'fish_turn.dart';
import 'desktop_companion.dart';
import 'company_approach.dart';
import 'companion_diagnostics.dart';
import 'companion_surface.dart';

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
  bool _desktopCompanion = false;
  FishTapInteraction? _desktopInteraction;
  DateTime? _lastCompany;
  int _companyIndex = 0;
  final Map<String, Alignment> _desktopPositions = {};
  final _startupGreeting = StartupGreetingGate();
  bool _startupPresenceRecorded = false;
  Timer? _presenceHeartbeat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (DesktopCompanion.supported) {
      DesktopCompanion.channel.setMethodCallHandler((call) async {
        if (call.method == 'restored' && mounted) {
          setState(() => _desktopCompanion = false);
        }
        if (call.method == 'company' &&
            mounted &&
            _desktopCompanion &&
            _visibleFish.isNotEmpty) {
          final now = DateTime.now();
          if (_lastCompany != null &&
              now.difference(_lastCompany!) < const Duration(seconds: 90)) {
            return;
          }
          _lastCompany = now;
          final fish = _visibleFish[_companyIndex++ % _visibleFish.length];
          setState(
            () => _desktopInteraction = FishTapInteraction(
              id: now.microsecondsSinceEpoch,
              fishId: fish.id,
              position: const Alignment(.68, .2),
              isCompany: true,
            ),
          );
        }
      });
    }
    _presenceHeartbeat = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted &&
          _visibleFish.isNotEmpty &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_recordLastSeen(DateTime.now()));
      }
    });
    unawaited(_syncTankSatiety());
    unawaited(_syncTankGrowth());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_desktopCompanion && DesktopCompanion.supported) {
      unawaited(
        DesktopCompanion.channel.invokeMethod<void>('exit').catchError((
          Object error,
        ) {
          debugPrint('[DEBUG-companion-stall] restore on home dispose failed');
        }),
      );
      debugPrint('[DEBUG-companion-stall] home disposed during companion mode');
    }
    if (DesktopCompanion.supported) {
      DesktopCompanion.channel.setMethodCallHandler(null);
    }
    _presenceHeartbeat?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
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
    if (!loading &&
        catalog != null &&
        fish.isNotEmpty &&
        !_startupPresenceRecorded) {
      _startupPresenceRecorded = true;
      final now = DateTime.now();
      final greet = _startupGreeting.check(fish.map((f) => f.lastSeenAt), now);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (greet) setState(() => _greetingToken += 1);
        unawaited(_recordLastSeen(now));
      });
    }
    final weather = _previewWeather ?? widget.tank.weather;
    final waterTemperature =
        _previewWaterTemperature ?? widget.tank.waterTemperature;
    final residentSpecies = catalog == null
        ? const <FishSpecies>[]
        : _residentSpecies(fish, catalog);

    if (_desktopCompanion && catalog != null) {
      return SizedBox(
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              for (var index = 0; index < fish.length; index++)
                _SwimmingFish(
                  key: ValueKey(fish[index].id),
                  fish: fish[index],
                  species: _resolveCatalogIdentity(fish[index], catalog)?.$1,
                  variant: _resolveCatalogIdentity(fish[index], catalog)?.$2,
                  swimSlot: index,
                  tankSize: constraints.biggest,
                  neighbours: _desktopPositions,
                  traits: catalog.traits
                      .where((t) => fish[index].hasPersonalityTrait(t))
                      .toList(),
                  interaction: _desktopInteraction,
                  greetingToken: 0,
                  feedingToken: 0,
                  weather: weather,
                  waterTemperature: waterTemperature,
                  onPositionChanged: (id, position) =>
                      _desktopPositions[id] = position,
                  onOpenProfile: () {},
                  hideName: true,
                ),
            ],
          ),
        ),
      );
    }

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
            onDesktopCompanion:
                DesktopCompanion.supported && fish.isNotEmpty && catalog != null
                ? _enterDesktopCompanion
                : null,
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
        .where(fish.hasPersonalityTrait)
        .toList(growable: false);
    final released = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FishActionSheet(
        fish: fish,
        traits: traits,
        availableTraits: catalog.traits,
        onUpdatePersonality: (traits) async {
          await ref
              .read(fishRepositoryProvider)
              .updatePersonality(fish.id, traits);
          ref.invalidate(tankFishProvider(fish.tankId));
        },
        species: identity?.$1,
        variant: identity?.$2,
        onRelease: () async {
          await ref.read(fishRepositoryProvider).releaseFish(fish.id);
          // A confirmed mutation must refresh the list even when realtime
          // DELETE delivery is delayed or unavailable on this connection.
          ref.invalidate(tankFishProvider(fish.tankId));
        },
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

  Future<void> _enterDesktopCompanion() async {
    setState(() => _desktopCompanion = true);
    await WidgetsBinding.instance.endOfFrame;
    try {
      await DesktopCompanion.enter();
    } catch (_) {
      if (!mounted) return;
      setState(() => _desktopCompanion = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂时无法进入桌面陪伴，请确认托盘和 Ctrl+Alt+Y 快捷键可用。')),
      );
    }
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
      if (mounted) ref.invalidate(tankDecorationsProvider(change.$1.tankId));
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
        // A successful local write must not depend on realtime delivery.
        ref.invalidate(tankDecorationsProvider(decoration.tankId));
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
      if (mounted) ref.invalidate(tankDecorationsProvider(change.$1.tankId));
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
    this.onDesktopCompanion,
  });

  final int count;
  final WeatherSnapshot? weather;
  final VoidCallback onWeatherTap;
  final int waterTemperature;
  final VoidCallback onTemperatureTap;
  final VoidCallback onSignOut;
  final VoidCallback? onDesktopCompanion;

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
              if (onDesktopCompanion != null)
                IconButton(
                  tooltip: '桌面陪伴 · Ctrl+Alt+Y 返回',
                  onPressed: onDesktopCompanion,
                  icon: const Icon(
                    Icons.desktop_windows_outlined,
                    color: Tokens.tankGlowSoft,
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
      builder: (context, constraints) => SizedBox(
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
              child: MouseRegion(
                onHover: (event) => _followPointer(
                  event.localPosition,
                  Size(constraints.maxWidth, constraints.maxHeight),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPressStart: (details) => _followPointer(
                    details.localPosition,
                    Size(constraints.maxWidth, constraints.maxHeight),
                  ),
                  onLongPressMoveUpdate: (details) => _followPointer(
                    details.localPosition,
                    Size(constraints.maxWidth, constraints.maxHeight),
                  ),
                  onTapUp: (details) => _callCompanions(
                    details.localPosition,
                    Size(constraints.maxWidth, constraints.maxHeight),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: TankDecorationsLayer(
                decorations: widget.decorations,
                onMove: widget.onMoveDecoration,
                onResize: widget.onResizeDecoration,
                onRemove: widget.onRemoveDecoration,
              ),
            ),
            if (widget.fish.isEmpty) const _EmptyTankMessage(),
            if (_interaction?.isCall == true)
              Positioned(
                left:
                    (_interaction!.position.x + 1) * constraints.maxWidth / 2 -
                    36,
                top:
                    (_interaction!.position.y + 1) * constraints.maxHeight / 2 -
                    36,
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('companion-call-${_interaction!.id}'),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1300),
                    builder: (context, value, _) => Opacity(
                      opacity: (1 - value) * .45,
                      child: Transform.scale(
                        scale: .25 + value * .75,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Tokens.tankGlowSoft,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            for (var index = 0; index < widget.fish.length; index += 1)
              _SwimmingFish(
                key: ValueKey(widget.fish[index].id),
                fish: widget.fish[index],
                swimSlot: index,
                tankSize: Size(constraints.maxWidth, constraints.maxHeight),
                neighbours: _fishPositions,
                species: _resolveSprite(widget.catalog, widget.fish[index])?.$1,
                variant: _resolveSprite(widget.catalog, widget.fish[index])?.$2,
                traits: widget.catalog.traits
                    .where(
                      (trait) => widget.fish[index].hasPersonalityTrait(trait),
                    )
                    .toList(growable: false),
                interaction: _interaction,
                greetingToken: widget.greetingToken,
                feedingToken: widget.feedingToken,
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

  DateTime? _lastCall;
  DateTime? _lastFollow;
  Offset? _lastPointer;
  final _followSelector = CompanionFollowSelector();
  void _followPointer(Offset point, Size size) {
    if (size.isEmpty || MediaQuery.disableAnimationsOf(context)) return;
    final now = DateTime.now();
    final previous = _lastPointer;
    final previousTime = _lastFollow;
    if (previousTime != null &&
        now.difference(previousTime).inMilliseconds < 350) {
      return;
    }
    _lastFollow = now;
    _lastPointer = point;
    if (previous == null || previousTime == null) return;
    final elapsed = now.difference(previousTime).inMilliseconds / 1000;
    if ((point - previous).distance / elapsed > 500) return;
    final nearby = <String, double>{};
    for (final fish in widget.fish) {
      final traits = widget.catalog.traits.where(fish.hasPersonalityTrait);
      if (!CompanionBehavior(traits.map((t) => t.code)).followsPointer) {
        continue;
      }
      final position = _fishPositions[fish.id];
      if (position == null) continue;
      final distance =
          (Offset(
                    (position.x + 1) * size.width / 2,
                    (position.y + 1) * size.height / 2,
                  ) -
                  point)
              .distance;
      if (distance < size.shortestSide * .48) {
        nearby[fish.id] = distance;
      }
    }
    final ordered = nearby.keys.toList()
      ..sort((a, b) => nearby[a]!.compareTo(nearby[b]!));
    final selected = _followSelector.select(ordered, now);
    if (selected == null) return;
    setState(
      () => _interaction = FishTapInteraction(
        id: ++_interactionId,
        fishId: selected,
        position: Alignment(
          point.dx / size.width * 2 - 1,
          point.dy / size.height * 2 - 1,
        ),
        isFollow: true,
      ),
    );
  }

  void _callCompanions(Offset point, Size size) {
    if (size.isEmpty || MediaQuery.disableAnimationsOf(context)) return;
    final now = DateTime.now();
    final cooling =
        _lastCall != null &&
        now.difference(_lastCall!) < const Duration(seconds: 5);
    final call = Alignment(
      point.dx / size.width * 2 - 1,
      point.dy / size.height * 2 - 1,
    );
    final nearby =
        widget.fish
            .where((fish) => _fishPositions.containsKey(fish.id))
            .toList()
          ..sort((a, b) {
            double distance(FishInstance fish) {
              final p = _fishPositions[fish.id]!;
              return Offset(
                (p.x - call.x) * size.width / 2,
                (p.y - call.y) * size.height / 2,
              ).distance;
            }

            return distance(a).compareTo(distance(b));
          });
    final ids = nearby
        .where((fish) {
          final p = _fishPositions[fish.id]!;
          return Offset(
                (p.x - call.x) * size.width / 2,
                (p.y - call.y) * size.height / 2,
              ).distance <
              size.shortestSide * .60;
        })
        .take(2)
        .map((fish) => fish.id)
        .toSet();
    if (cooling) ids.clear();
    if (ids.isNotEmpty) _lastCall = now;
    setState(
      () => _interaction = FishTapInteraction(
        id: ++_interactionId,
        fishId: ids.isEmpty ? '' : ids.first,
        position: call,
        companionIds: ids,
        isCall: true,
      ),
    );
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
    required this.tankSize,
    required this.neighbours,
    required this.traits,
    required this.interaction,
    required this.greetingToken,
    required this.feedingToken,
    required this.weather,
    required this.waterTemperature,
    required this.onPositionChanged,
    required this.onOpenProfile,
    this.hideName = false,
    super.key,
  });

  final FishInstance fish;
  final FishSpecies? species;
  final FishVariant? variant;
  final int swimSlot;
  final Size tankSize;
  final Map<String, Alignment> neighbours;
  final List<PersonalityTrait> traits;
  final FishTapInteraction? interaction;
  final int greetingToken;
  final int feedingToken;
  final WeatherSnapshot? weather;
  final int waterTemperature;
  final void Function(String fishId, Alignment position) onPositionChanged;
  final VoidCallback onOpenProfile;
  final bool hideName;

  @override
  State<_SwimmingFish> createState() => _SwimmingFishState();
}

class _SwimmingFishState extends State<_SwimmingFish>
    with TickerProviderStateMixin {
  late final Random _random;
  late final FishSwimProfile _swimProfile;
  late Alignment _position;
  late Alignment _target;
  late FishMotion _motion;
  late final Ticker _motionTicker;
  Duration? _lastTick;
  double _swimPhase = 0;
  Timer? _timer;
  Timer? _reactionTimer;
  Timer? _attentionTimer;
  double _restSeconds = 0;
  double _reactionSeconds = 0;
  bool _dwelling = false;
  bool _following = false;
  bool _company = false;
  CompanyApproach? _companyApproach;
  Alignment? _approachFinal;
  IdleRoutine? _idleRoutine;
  int _routineStep = 0;
  double _routineElapsed = 0;
  double _routineDuration = 1;
  CompanionBehavior get _behavior =>
      CompanionBehavior(widget.traits.map((t) => t.code));
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
    // Spread arrivals over the usable water column, including low-satiety fish.
    _position = Alignment(
      widget.swimSlot.isEven ? -.48 : .48,
      -.60 + (widget.swimSlot % 5) * .26,
    );
    _target = _nextPosition(initial: true);
    _motion = FishMotion(_toPixels(_position));
    _motionTicker = createTicker(_tick)..start();
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
    _motionTicker.dispose();
    _timer?.cancel();
    _reactionTimer?.cancel();
    _attentionTimer?.cancel();
    _tailController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SwimmingFish oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tankSize != widget.tankSize) {
      _motion.position = _toPixels(_position);
    }
    final interaction = widget.interaction;
    if (_following &&
        interaction != null &&
        interaction.isFollow &&
        interaction.fishId != widget.fish.id) {
      _reactionTimer?.cancel();
      _following = false;
      _activeReaction = null;
      _dwelling = false;
      _move();
    }
    if (interaction != null &&
        interaction.id != oldWidget.interaction?.id &&
        (interaction.fishId == widget.fish.id ||
            interaction.companionIds.contains(widget.fish.id))) {
      if (interaction.isCompany) {
        final approach = CompanyApproach(
          (_toPixels(interaction.position) - _motion.position).distance,
        );
        _startReaction(
          reaction: FishReaction.greeting,
          destination: interaction.position,
          duration: approach.timeout,
        );
        _company = true;
        _companyApproach = approach;
      } else if (interaction.isFollow) {
        _follow(interaction.position);
      } else if (interaction.isCall) {
        _respondToCall(interaction.position);
      } else {
        _reactToTap(interaction.position);
      }
    }
    if (widget.greetingToken != oldWidget.greetingToken &&
        widget.greetingToken > 0) {
      _greet();
    }
    if (widget.feedingToken != oldWidget.feedingToken &&
        widget.feedingToken > 0 &&
        !MediaQuery.disableAnimationsOf(context)) {
      _respondToFeeding();
    }
  }

  void _respondToFeeding() {
    _following = false;
    _timer?.cancel();
    _reactionTimer?.cancel();
    _attentionTimer?.cancel();
    _activeReaction = null;
    _dwelling = false;
    _attentionTimer = Timer(_behavior.feedingDelay(widget.swimSlot), () {
      _attentionTimer = null;
      if (!mounted) return;
      _restSeconds = 0;
      _startReaction(
        reaction: FishReaction.curious,
        destination: _behavior.feedingDestination(widget.swimSlot),
        duration: const Duration(seconds: 14),
      );
    });
  }

  void _move() {
    if (!mounted) return;
    _company = false;
    _companyApproach = null;
    _approachFinal = null;
    final profile = _behavior.profile;
    if (profile != null &&
        (widget.hideName || !isLowSatiety(widget.fish.satiety)) &&
        !MediaQuery.disableAnimationsOf(context)) {
      final step = _routineStep++ + widget.swimSlot * 2;
      final routine = widget.hideName
          ? desktopRoutine(
              profile,
              step,
              _position,
              widget.tankSize,
              30 *
                  _behavior.speedFor(
                    lowSatiety: isLowSatiety(widget.fish.satiety),
                  ),
            )
          : IdleRoutine.plan(
              profile,
              step,
              _position,
              Alignment(
                _swimProfile.horizontalCenter,
                _swimProfile.verticalBias,
              ),
            );
      _idleRoutine = routine;
      _routineElapsed = 0;
      _target = routine.target;
      _restSeconds = routine.pause;
      final duration = widget.hideName
          ? Duration(
              milliseconds:
                  (routine.seconds *
                          _activityAdjustedDuration(5).inMilliseconds /
                          5)
                      .round(),
            )
          : _activityAdjustedDuration(routine.seconds);
      _routineDuration = duration.inMilliseconds / 1000;
      _timer = Timer(duration, _move);
      return;
    }
    _idleRoutine = null;
    if (!MediaQuery.disableAnimationsOf(context)) {
      final next = _nextPosition();
      _target = next;
      _restSeconds = _behavior.routineRestSeconds;
    }
    final lazy = widget.traits.any((trait) => trait.code == 'lazy');
    final sad = isLowSatiety(widget.fish.satiety);
    final seconds =
        (sad
            ? 8
            : _behavior.profile != null
            ? _behavior.routeSeconds
            : (lazy ? 7 : 4)) +
        _random.nextInt(4);
    _timer = Timer(_activityAdjustedDuration(seconds), _move);
  }

  void _respondToCall(Alignment call) {
    if (_activeReaction != null || _attentionTimer != null) return;
    _timer?.cancel();
    _attentionTimer = Timer(
      _behavior.attentionDelay + Duration(milliseconds: widget.swimSlot * 160),
      () {
        _attentionTimer = null;
        if (!mounted) return;
        _restSeconds = 0;
        _dwelling = false;
        _reactionSeconds = 0;
        _startReaction(
          reaction: reactionForTraitCodes(_behavior.codes),
          destination: _behavior.approach(_position, call, widget.swimSlot),
          duration: const Duration(seconds: 16),
        );
        final waypoint = _behavior.approachWaypoint(
          _position,
          _target,
          widget.swimSlot,
        );
        if (waypoint != null) {
          _approachFinal = _target;
          _target = waypoint;
        }
      },
    );
  }

  void _follow(Alignment pointer) {
    if (!_behavior.followsPointer ||
        _attentionTimer != null ||
        (_activeReaction != null && !_following)) {
      return;
    }
    _following = true;
    _timer?.cancel();
    _reactionTimer?.cancel();
    _target = _behavior.approach(_position, pointer, widget.swimSlot);
    _activeReaction = reactionForTraitCodes(_behavior.codes);
    _dwelling = false;
    _reactionSeconds = 0;
    _restSeconds = 0;
    _reactionTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _following = false;
        _activeReaction = null;
        _dwelling = false;
      });
      _move();
    });
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
    if (MediaQuery.disableAnimationsOf(context) ||
        _activeReaction != null ||
        _attentionTimer != null) {
      return;
    }
    _timer?.cancel();
    _attentionTimer = Timer(_behavior.greetingDelay(widget.swimSlot), () {
      _attentionTimer = null;
      if (!mounted) return;
      _restSeconds = 0;
      _startReaction(
        reaction: FishReaction.greeting,
        destination: _behavior.greetingDestination(_position, widget.swimSlot),
        duration: const Duration(seconds: 4),
      );
    });
  }

  void _startReaction({
    required FishReaction reaction,
    required Alignment destination,
    required Duration duration,
  }) {
    _following = false;
    _attentionTimer?.cancel();
    _company = false;
    _approachFinal = null;
    _attentionTimer = null;
    _timer?.cancel();
    _reactionTimer?.cancel();
    _tailController.repeat(reverse: true);
    setState(() {
      _activeReaction = reaction;
      _target = destination;
      _dwelling = false;
      _reactionSeconds = 0;
    });
    _reactionTimer = Timer(duration, () {
      if (!mounted) return;
      _tailController
        ..stop()
        ..value = 0;
      setState(() {
        _activeReaction = null;
        _dwelling = false;
      });
      _move();
    });
  }

  Offset _toPixels(Alignment value) => Offset(
    (value.x + 1) * widget.tankSize.width / 2,
    (value.y + 1) * widget.tankSize.height / 2,
  );

  void _tick(Duration elapsed) {
    if (widget.hideName) CompanionDiagnostics.count('motionTick');
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == null ||
        !mounted ||
        widget.tankSize.isEmpty ||
        MediaQuery.disableAnimationsOf(context)) {
      if (widget.hideName) {
        CompanionDiagnostics.count('motionGuard');
      }
      return;
    }
    final dt = ((elapsed - previous).inMicroseconds / 1000000).clamp(0.0, .05);
    if (widget.hideName) {
      CompanionDiagnostics.count(dt <= 0 ? 'zeroDelta' : 'advancingDelta');
    }
    if (_activeReaction == null && _attentionTimer == null) {
      _routineElapsed += dt;
    }
    _restSeconds = (_restSeconds - dt).clamp(0, 10);
    if (_activeReaction != null) {
      _reactionSeconds += dt;
      if (_approachFinal != null &&
          ((_toPixels(_target) - _motion.position).distance < 20 ||
              _reactionSeconds > 5)) {
        _target = _approachFinal!;
        _approachFinal = null;
      }
      if (!_following &&
          _approachFinal == null &&
          !_dwelling &&
          (_company
              ? CompanyApproach.reached(
                  (_toPixels(_target) - _motion.position).distance,
                )
              : ((_toPixels(_target) - _motion.position).distance < 10 ||
                    _reactionSeconds > 12))) {
        _dwelling = true;
        _target = _position;
        _reactionTimer?.cancel();
        _reactionTimer = Timer(
          _company ? const Duration(seconds: 20) : _behavior.dwell,
          () {
            if (!mounted) return;
            _tailController
              ..stop()
              ..value = 0;
            setState(() {
              _activeReaction = null;
              _dwelling = false;
            });
            _move();
          },
        );
      }
    }
    final traitSpeed = _behavior.speedFor(
      lowSatiety: isLowSatiety(widget.fish.satiety),
      responding: _activeReaction != null,
    );
    final routineSpeed = _activeReaction == null
        ? (_idleRoutine?.speedEnvelope(
                _routineElapsed * _idleRoutine!.seconds / _routineDuration,
              ) ??
              1.0)
        : 1.0;
    final speed = _company
        ? (_companyApproach?.speed ?? 45)
        : (_activeReaction != null ? 42 : 30) *
              traitSpeed *
              routineSpeed *
              5000 /
              _activityAdjustedDuration(5).inMilliseconds;
    final holding =
        _dwelling ||
        _attentionTimer != null ||
        (_activeReaction == null &&
            (_restSeconds > 0 || (_idleRoutine?.stationary ?? false)));
    if (holding) {
      // Brake visibly rather than creeping toward the distant route target.
      _motion.velocity *= exp(-5 * dt);
    }
    final space = 108 * FishSprite.scaleForStage(widget.fish.growthStage) + 28;
    _motion.step(
      dt,
      target: holding ? _motion.position : _toPixels(_target),
      tank: widget.tankSize,
      speed: holding ? 3 : speed,
      personalSpace: space,
      steering: _activeReaction == null ? _behavior.steering : .9,
      neighbours: widget.neighbours.entries
          .where((entry) => entry.key != widget.fish.id)
          .map((entry) => _toPixels(entry.value))
          .toList(growable: false),
    );
    setState(() {
      _position = Alignment(
        _motion.position.dx / widget.tankSize.width * 2 - 1,
        _motion.position.dy / widget.tankSize.height * 2 - 1,
      );
      // Hysteresis prevents repeated side swaps near a nearly vertical turn.
      if (_motion.velocity.dx.abs() > 1.5) {
        _facingLeft = _motion.velocity.dx < 0;
      }
      _swimPhase +=
          dt *
          (3 + _motion.velocity.distance / 12) *
          (_activeReaction == null ? _behavior.finTempo : 1);
    });
    widget.onPositionChanged(widget.fish.id, _position);
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
    if (_behavior.profile != null && _behavior.curious) {
      minY = -.65;
      maxY = .62;
    } else if (codes.contains('shy')) {
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
    return _behavior.routeDestination(
      Alignment(initial ? x * 0.85 : x, y),
      Alignment(_swimProfile.horizontalCenter, _swimProfile.verticalBias),
    );
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
    final sad = isLowSatiety(widget.fish.satiety);
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
        facingLeft: false,
        width: 108,
        finPhase: _swimPhase,
        finStrength: MediaQuery.disableAnimationsOf(context)
            ? 0
            : ((.30 + _motion.velocity.distance / 45).clamp(.30, 1.0) *
                  (_activeReaction == null ? _behavior.finPower : 1)),
      );
    } else if (widget.species != null && widget.variant != null) {
      sprite = FishSprite(
        species: widget.species!,
        variant: widget.variant!,
        growthStage: widget.fish.growthStage,
        facingLeft: false,
        width: 108,
        finPhase: _swimPhase,
        finStrength: MediaQuery.disableAnimationsOf(context)
            ? 0
            : ((.30 + _motion.velocity.distance / 45).clamp(.30, 1.0) *
                  (_activeReaction == null ? _behavior.finPower : 1)),
      );
    } else {
      sprite = const Icon(
        Icons.set_meal_rounded,
        color: Tokens.tankGlow,
        size: 64,
      );
    }
    return Align(
      alignment: _position,
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
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onOpenProfile,
                  child: widget.hideName
                      ? CompanionSurface(
                          fishId: widget.fish.id,
                          onAttention: (pointer) => _respondToCall(
                            Alignment(
                              pointer.dx / widget.tankSize.width * 2 - 1,
                              pointer.dy / widget.tankSize.height * 2 - 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: FishTurn(
                              facingLeft: _facingLeft,
                              child: sprite,
                            ),
                          ),
                        )
                      : FishTurn(facingLeft: _facingLeft, child: sprite),
                ),
                builder: (context, child) => Transform.rotate(
                  alignment: const Alignment(0.62, 0),
                  angle: MediaQuery.disableAnimationsOf(context)
                      ? 0
                      : sin(_swimPhase + _tailController.value * pi * 2) *
                                (_activeReaction == null
                                    ? _behavior.bodySway
                                    : .004) +
                            (_motion.velocity.dy / 180).clamp(-.10, .10),
                  child: child,
                ),
              ),
              if (!widget.hideName)
                AnimatedOpacity(
                  opacity:
                      widget.neighbours.entries.any(
                        (entry) =>
                            entry.key != widget.fish.id &&
                            (_toPixels(entry.value) - _motion.position)
                                    .distance <
                                80,
                      )
                      ? .25
                      : 1,
                  duration: const Duration(milliseconds: 350),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Tokens.primaryBg.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.fish.name,
                      style: const TextStyle(color: Tokens.text, fontSize: 12),
                    ),
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
