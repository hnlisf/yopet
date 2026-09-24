import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../fish/fish_models.dart';
import '../home/tank.dart';
import 'temperature_providers.dart';
import 'water_temperature.dart';

class TemperatureSheet extends ConsumerStatefulWidget {
  const TemperatureSheet({
    required this.tank,
    required this.residentSpecies,
    required this.onPreviewChanged,
    super.key,
  });

  final Tank tank;
  final List<FishSpecies> residentSpecies;
  final ValueChanged<int?> onPreviewChanged;

  @override
  ConsumerState<TemperatureSheet> createState() => _TemperatureSheetState();
}

class _TemperatureSheetState extends ConsumerState<TemperatureSheet> {
  late int _temperature = widget.tank.waterTemperature;
  var _isSaving = false;
  String? _error;

  @override
  void dispose() {
    widget.onPreviewChanged(null);
    super.dispose();
  }

  void _setTemperature(int value) {
    final next = value.clamp(minWaterTemperature, maxWaterTemperature).toInt();
    if (next == _temperature) return;
    setState(() {
      _temperature = next;
      _error = null;
    });
    widget.onPreviewChanged(next);
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref
          .read(tankTemperatureRepositoryProvider)
          .setWaterTemperature(
            tankId: widget.tank.id,
            temperature: _temperature,
          );
      widget.onPreviewChanged(null);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('水温已调到 $_temperature°C，鱼缸会慢慢适应。')));
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = '水温暂时没有保存成功，再试一次吧。');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = widget.residentSpecies
        .map(
          (species) => (
            species: species,
            comfort: comfortForWaterTemperature(
              temperature: _temperature,
              preferredMin: species.preferredTemperatureMin,
              preferredMax: species.preferredTemperatureMax,
            ),
          ),
        )
        .toList(growable: false);
    final comfortable = preferences
        .where((item) => item.comfort == WaterTemperatureComfort.comfortable)
        .length;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 22),
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
            const SizedBox(height: 18),
            const Text(
              '水温',
              style: TextStyle(
                color: Tokens.text,
                fontSize: 23,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              preferences.isEmpty
                  ? '先为鱼缸留下一点舒适的暖意。'
                  : '$comfortable / ${preferences.length} 条小鱼此刻觉得舒适。',
              style: const TextStyle(color: Tokens.textDim, fontSize: 14),
            ),
            const SizedBox(height: 22),
            Center(
              child: Text(
                '$_temperature°C',
                style: const TextStyle(
                  color: Tokens.text,
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Row(
              children: [
                _TemperatureStepButton(
                  icon: Icons.remove_rounded,
                  tooltip: '降低水温',
                  onPressed: _isSaving
                      ? null
                      : () => _setTemperature(_temperature - 1),
                ),
                Expanded(
                  child: Slider(
                    value: _temperature.toDouble(),
                    min: minWaterTemperature.toDouble(),
                    max: maxWaterTemperature.toDouble(),
                    divisions: maxWaterTemperature - minWaterTemperature,
                    label: '$_temperature°C',
                    activeColor: Tokens.amber,
                    inactiveColor: Tokens.textDim.withValues(alpha: 0.25),
                    onChanged: _isSaving
                        ? null
                        : (value) => _setTemperature(value.round()),
                  ),
                ),
                _TemperatureStepButton(
                  icon: Icons.add_rounded,
                  tooltip: '提高水温',
                  onPressed: _isSaving
                      ? null
                      : () => _setTemperature(_temperature + 1),
                ),
              ],
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('18°C', style: TextStyle(color: Tokens.textDim)),
                Text('30°C', style: TextStyle(color: Tokens.textDim)),
              ],
            ),
            if (preferences.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Divider(color: Color(0x335BA8B5), height: 1),
              ),
              const Text(
                '小鱼的感受',
                style: TextStyle(
                  color: Tokens.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: preferences
                    .map(
                      (item) => _FishTemperatureCue(
                        species: item.species,
                        comfort: item.comfort,
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            if (_error case final error?) ...[
              const SizedBox(height: 14),
              Text(error, style: const TextStyle(color: Tokens.amber)),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: Tokens.tankGlow,
                  foregroundColor: Tokens.primaryBg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存水温'),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                '水温只会轻轻影响游动节奏，不会影响成长或饱腹。',
                style: TextStyle(color: Tokens.textDim, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemperatureStepButton extends StatelessWidget {
  const _TemperatureStepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      color: Tokens.tankGlowSoft,
    );
  }
}

class _FishTemperatureCue extends StatelessWidget {
  const _FishTemperatureCue({required this.species, required this.comfort});

  final FishSpecies species;
  final WaterTemperatureComfort comfort;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Tokens.primaryBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Tokens.tankGlow.withValues(alpha: 0.2)),
      ),
      child: Text(
        '${species.nameZh} · ${comfort.labelZh}',
        style: const TextStyle(color: Tokens.textDim),
      ),
    );
  }
}
