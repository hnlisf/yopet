import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../home/tank.dart';
import 'weather_models.dart';
import 'weather_providers.dart';

class WeatherSheet extends ConsumerStatefulWidget {
  const WeatherSheet({
    required this.tank,
    required this.onPreviewChanged,
    super.key,
  });

  final Tank tank;
  final ValueChanged<WeatherSnapshot?> onPreviewChanged;

  @override
  ConsumerState<WeatherSheet> createState() => _WeatherSheetState();
}

class _WeatherSheetState extends ConsumerState<WeatherSheet> {
  final _cityController = TextEditingController();
  List<WeatherCity> _results = const <WeatherCity>[];
  var _isSearching = false;
  String? _loadingCity;
  String? _error;

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _cityController.text.trim();
    if (query.length < 2) {
      setState(() => _error = '输入至少两个字的城市名');
      return;
    }
    setState(() {
      _isSearching = true;
      _error = null;
      _results = const <WeatherCity>[];
    });
    try {
      final results = await ref
          .read(weatherRepositoryProvider)
          .searchCities(query);
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) setState(() => _error = '城市暂时没有回应，请检查网络后再试。');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _chooseCity(WeatherCity city) async {
    setState(() {
      _loadingCity = city.name;
      _error = null;
    });
    try {
      final snapshot = await ref
          .read(weatherRepositoryProvider)
          .refreshWeather(tankId: widget.tank.id, city: city);
      widget.onPreviewChanged(null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${snapshot.cityName}此刻${snapshot.labelZh}')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = '天气暂时没有回应，会保留原来的鱼缸氛围。');
    } finally {
      if (mounted) setState(() => _loadingCity = null);
    }
  }

  void _preview(WeatherCondition condition) {
    widget.onPreviewChanged(WeatherSnapshot.preview(condition));
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final weather = widget.tank.weather;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.74,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 22),
          decoration: const BoxDecoration(
            color: Tokens.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
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
              const SizedBox(height: 18),
              const Text(
                '天气氛围',
                style: TextStyle(
                  color: Tokens.text,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                weather == null
                    ? '选一座城市，让鱼缸跟着此刻的天空呼吸。'
                    : '${weather.cityName} · ${weather.labelZh} · ${weather.temperatureLabel}',
                style: const TextStyle(color: Tokens.textDim, fontSize: 14),
              ),
              const SizedBox(height: 18),
              const Text(
                '先看看不同天气',
                style: TextStyle(
                  color: Tokens.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: WeatherCondition.values
                    .map(
                      (condition) => ActionChip(
                        avatar: Icon(condition.icon, size: 17),
                        label: Text(condition.labelZh(isDay: true)),
                        onPressed: () => _preview(condition),
                        backgroundColor: Tokens.primaryBg,
                        side: BorderSide(
                          color: Tokens.tankGlow.withValues(alpha: 0.25),
                        ),
                        labelStyle: const TextStyle(color: Tokens.textDim),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 5),
              const Text(
                '预览只在当前会话生效，不会改动鱼缸数据。',
                style: TextStyle(color: Tokens.textDim, fontSize: 12),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Color(0x335BA8B5), height: 1),
              ),
              const Text(
                '选择真实城市',
                style: TextStyle(
                  color: Tokens.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cityController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      style: const TextStyle(color: Tokens.text),
                      decoration: const InputDecoration(
                        hintText: '输入城市，例如：上海',
                        hintStyle: TextStyle(color: Tokens.textDim),
                        filled: true,
                        fillColor: Tokens.primaryBg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    tooltip: '查找城市',
                    onPressed: _isSearching ? null : _search,
                    style: IconButton.styleFrom(
                      backgroundColor: Tokens.tankGlow,
                      foregroundColor: Tokens.primaryBg,
                    ),
                    icon: _isSearching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search_rounded),
                  ),
                ],
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 10),
                Text(error, style: const TextStyle(color: Tokens.amber)),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: _results.isEmpty
                    ? const Center(
                        child: Text(
                          '输入城市后，选中结果即可同步此刻天气。',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Tokens.textDim),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, _) =>
                            const Divider(color: Color(0x225BA8B5), height: 1),
                        itemBuilder: (_, index) {
                          final city = _results[index];
                          final loading = _loadingCity == city.name;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.location_on_outlined,
                              color: Tokens.tankGlowSoft,
                            ),
                            title: Text(
                              city.name,
                              style: const TextStyle(color: Tokens.text),
                            ),
                            subtitle: Text(
                              city.subtitle,
                              style: const TextStyle(color: Tokens.textDim),
                            ),
                            trailing: loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Tokens.textDim,
                                  ),
                            onTap: _loadingCity == null
                                ? () => _chooseCity(city)
                                : null,
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
