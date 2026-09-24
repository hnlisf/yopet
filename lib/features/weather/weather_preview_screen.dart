import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../fish/fish_models.dart';
import '../fish/fish_sprite.dart';
import 'weather_atmosphere.dart';
import 'weather_models.dart';

/// A deliberately data-free local review surface. It lets a product reviewer
/// feel F11 before creating an account or connecting a weather service.
class WeatherPreviewScreen extends StatefulWidget {
  const WeatherPreviewScreen({super.key});

  @override
  State<WeatherPreviewScreen> createState() => _WeatherPreviewScreenState();
}

class _WeatherPreviewScreenState extends State<WeatherPreviewScreen> {
  static const _positions = <Alignment>[
    Alignment(-0.55, -0.38),
    Alignment(0.42, -0.1),
    Alignment(-0.18, 0.42),
    Alignment(0.56, 0.36),
    Alignment(-0.48, 0.08),
  ];

  WeatherCondition _condition = WeatherCondition.clear;
  Timer? _moveTimer;
  var _positionIndex = 0;

  @override
  void initState() {
    super.initState();
    _scheduleMove();
  }

  @override
  void dispose() {
    _moveTimer?.cancel();
    super.dispose();
  }

  void _setCondition(WeatherCondition condition) {
    setState(() => _condition = condition);
    _moveTimer?.cancel();
    _scheduleMove();
  }

  void _scheduleMove() {
    final delay = Duration(
      milliseconds: (5800 / _condition.activityMultiplier).round(),
    );
    _moveTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _positionIndex = (_positionIndex + 1) % _positions.length);
      _scheduleMove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = WeatherSnapshot.preview(_condition);
    final motionDuration = Duration(
      milliseconds: (3500 / _condition.activityMultiplier).round(),
    );
    return Scaffold(
      backgroundColor: Tokens.primaryBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'yopet',
                style: TextStyle(
                  color: Tokens.text,
                  fontFamily: 'serif',
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'F11 · 天气氛围试阅',
                style: TextStyle(color: Tokens.textDim, fontSize: 14),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/tank/background.png',
                        fit: BoxFit.cover,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0x66030D18), Color(0x16030D18)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      WeatherAtmosphere(weather: snapshot),
                      AnimatedAlign(
                        alignment: _positions[_positionIndex],
                        curve: Curves.easeInOutSine,
                        duration: motionDuration,
                        child: const _PreviewFish(),
                      ),
                      Positioned(
                        top: 18,
                        left: 18,
                        right: 18,
                        child: Row(
                          children: [
                            Icon(_condition.icon, color: Tokens.tankGlowSoft),
                            const SizedBox(width: 7),
                            Text(
                              '${snapshot.labelZh} · ${snapshot.temperatureLabel}',
                              style: const TextStyle(
                                color: Tokens.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Positioned(
                        left: 18,
                        right: 18,
                        bottom: 18,
                        child: Text(
                          '预览不会保存数据。观察水光、纹理与小鱼的游动节奏。',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Tokens.textDim, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: WeatherCondition.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final condition = WeatherCondition.values[index];
                    return ChoiceChip(
                      avatar: Icon(condition.icon, size: 17),
                      label: Text(condition.labelZh(isDay: true)),
                      selected: condition == _condition,
                      onSelected: (_) => _setCondition(condition),
                      selectedColor: Tokens.tankGlow.withValues(alpha: 0.25),
                      backgroundColor: Tokens.surface,
                      side: BorderSide(
                        color: condition == _condition
                            ? Tokens.tankGlowSoft
                            : Tokens.tankGlow.withValues(alpha: 0.18),
                      ),
                      labelStyle: TextStyle(
                        color: condition == _condition
                            ? Tokens.text
                            : Tokens.textDim,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewFish extends StatelessWidget {
  const _PreviewFish();

  @override
  Widget build(BuildContext context) {
    const species = FishSpecies(
      id: 'goldfish',
      nameZh: '金鱼',
      nameEn: 'Goldfish',
      variants: [],
    );
    const variant = FishVariant(
      id: 'goldfish_classic',
      speciesId: 'goldfish',
      label: '水彩橙',
      colorHex: '#F39A5A',
      assetFilename: 'base.png',
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const FishSprite(
          species: species,
          variant: variant,
          growthStage: GrowthStage.adult,
          width: 148,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: Tokens.primaryBg.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('泡泡', style: TextStyle(color: Tokens.text)),
        ),
      ],
    );
  }
}
