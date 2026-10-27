import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../fish/custom_fish_sprite.dart';
import '../fish/fish_models.dart';
import '../fish/fish_repository.dart';
import '../fish/fish_sprite.dart';
import '../presence/personality_profile.dart';
import 'satiety.dart';

class FishActionSheet extends StatefulWidget {
  const FishActionSheet({
    required this.fish,
    required this.traits,
    required this.onRelease,
    this.species,
    this.variant,
    this.now,
    this.availableTraits = const [],
    this.onUpdatePersonality,
    super.key,
  });

  final FishInstance fish;
  final List<PersonalityTrait> traits;
  final FishSpecies? species;
  final FishVariant? variant;
  final Future<void> Function() onRelease;
  final DateTime? now;
  final List<PersonalityTrait> availableTraits;
  final Future<void> Function(List<PersonalityTrait>)? onUpdatePersonality;

  @override
  State<FishActionSheet> createState() => _FishActionSheetState();
}

class _FishActionSheetState extends State<FishActionSheet> {
  Future<void> _editPersonality() async {
    final selected = widget.traits.map((t) => t.id).toSet();
    var saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('调整性格'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('选择一个性格。取消不会改变现有设置。'),
                for (final preset in PersonalityProfile.presets)
                  ListTile(
                    title: Text(preset.name),
                    subtitle: Text(preset.summary),
                    trailing:
                        selected.length == preset.legacyCodes.length &&
                            widget.availableTraits
                                .where((t) => selected.contains(t.id))
                                .map((t) => t.code)
                                .toSet()
                                .containsAll(preset.legacyCodes)
                        ? const Icon(Icons.check)
                        : null,
                    onTap: saving
                        ? null
                        : () => update(() {
                            final traits = widget.availableTraits
                                .where(
                                  (t) => preset.legacyCodes.contains(t.code),
                                )
                                .toList();
                            if (traits.length != preset.legacyCodes.length) {
                              error = '性格目录暂未加载完整';
                              return;
                            }
                            selected
                              ..clear()
                              ..addAll(traits.map((t) => t.id));
                            error = null;
                          }),
                  ),
                if (error != null) Text(error!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final traits = widget.availableTraits
                          .where((t) => selected.contains(t.id))
                          .toList();
                      if (!isValidPersonality(traits) ||
                          PersonalityProfile.fromLegacy(
                                traits.map((t) => t.code).toSet(),
                              ) ==
                              null) {
                        update(() => error = '请选择一个性格');
                        return;
                      }
                      update(() => saving = true);
                      try {
                        await widget.onUpdatePersonality!(traits);
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (mounted) Navigator.pop(this.context);
                      } catch (_) {
                        if (dialogContext.mounted) {
                          update(() {
                            saving = false;
                            error = '暂时没能保存，请再试一次';
                          });
                        }
                      }
                    },
              child: Text(saving ? '保存中…' : '保存'),
            ),
          ],
        ),
      ),
    );
  }

  var _releasing = false;
  String? _releaseError;

  Future<void> _confirmRelease() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Tokens.surface,
        title: Text(
          '和${widget.fish.name}说再见？',
          style: const TextStyle(color: Tokens.text),
        ),
        content: const Text(
          '它会离开这个鱼缸，成长与投喂记录也会一起移除。这个操作无法撤回。',
          style: TextStyle(color: Tokens.textDim, height: 1.55),
        ),
        actions: [
          TextButton(
            key: const Key('keep-fish'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              '再陪它一会儿',
              style: TextStyle(color: Tokens.tankGlowSoft),
            ),
          ),
          FilledButton(
            key: const Key('confirm-release-fish'),
            style: FilledButton.styleFrom(
              backgroundColor: Tokens.amber,
              foregroundColor: Tokens.primaryBg,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认送别'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _releasing = true;
      _releaseError = null;
    });
    try {
      await widget.onRelease();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _releasing = false;
        _releaseError = '暂时没能送别，再试一次吧。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fish = widget.fish;
    final lowSatiety = isLowSatiety(fish.satiety);
    final progressColor = lowSatiety ? Tokens.amber : Tokens.tankGlow;
    final residentDays = _residentDays(
      createdAt: fish.createdAt,
      now: widget.now ?? DateTime.now(),
    );

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 26),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FishPortrait(
                    fish: fish,
                    species: widget.species,
                    variant: widget.variant,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fish.name,
                            style: const TextStyle(
                              color: Tokens.text,
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _identityLabel(
                              fish,
                              widget.species,
                              widget.variant,
                            ),
                            style: const TextStyle(
                              color: Tokens.tankGlowSoft,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${fish.growthStage.nameZh} · 来到鱼缸第 $residentDays 天',
                            style: const TextStyle(
                              color: Tokens.textDim,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Tokens.textDim,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                '它的性格',
                style: TextStyle(
                  color: Tokens.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (PersonalityProfile.fromLegacy(
                    widget.traits.map((t) => t.code).toSet(),
                  )
                  case final profile?)
                ListTile(
                  title: Text(profile.name),
                  subtitle: Text(profile.summary),
                ),
              if (PersonalityProfile.fromLegacy(
                    widget.traits.map((t) => t.code).toSet(),
                  ) ==
                  null)
                const Text(
                  '保留原有性格，可通过“调整性格”选择一个新性格。',
                  style: TextStyle(color: Tokens.textDim),
                ),
              const SizedBox(height: 20),
              if (widget.onUpdatePersonality != null)
                TextButton.icon(
                  onPressed: _editPersonality,
                  icon: const Icon(Icons.tune),
                  label: const Text('调整性格'),
                ),
              Row(
                children: [
                  const Text(
                    '饱腹度',
                    style: TextStyle(color: Tokens.textDim, fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    '${fish.satiety}%',
                    style: TextStyle(
                      color: progressColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: fish.satiety / 100,
                  minHeight: 10,
                  backgroundColor: Tokens.primaryBg.withValues(alpha: 0.72),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              if (lowSatiety) ...[
                const SizedBox(height: 10),
                const Text(
                  '小鱼有点饿了。',
                  style: TextStyle(color: Tokens.amber, fontSize: 14),
                ),
              ],
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Tokens.tankGlow.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.groups_rounded, color: Tokens.tankGlowSoft),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '投喂时，鱼缸里的小鱼会一起慢慢享用。',
                        style: TextStyle(color: Tokens.textDim, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              if (_releaseError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _releaseError!,
                  key: const Key('release-fish-error'),
                  style: const TextStyle(color: Tokens.amber, fontSize: 13),
                ),
              ],
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  key: const Key('release-fish'),
                  onPressed: _releasing ? null : _confirmRelease,
                  icon: _releasing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Tokens.textDim,
                          ),
                        )
                      : const Icon(Icons.waves_rounded, size: 18),
                  label: Text(_releasing ? '正在送别…' : '让它去新的水域'),
                  style: TextButton.styleFrom(foregroundColor: Tokens.textDim),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FishPortrait extends StatelessWidget {
  const _FishPortrait({
    required this.fish,
    required this.species,
    required this.variant,
  });

  final FishInstance fish;
  final FishSpecies? species;
  final FishVariant? variant;

  @override
  Widget build(BuildContext context) {
    final appearance = fish.customAppearance;
    final Widget sprite;
    if (appearance != null) {
      sprite = CustomFishSprite(
        appearance: appearance,
        growthStage: fish.growthStage,
        width: 96,
      );
    } else if (species != null && variant != null) {
      sprite = FishSprite(
        species: species!,
        variant: variant!,
        growthStage: fish.growthStage,
        width: 96,
      );
    } else {
      sprite = const Icon(
        Icons.set_meal_rounded,
        color: Tokens.tankGlow,
        size: 54,
      );
    }

    return Container(
      width: 112,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Tokens.primaryBg.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Tokens.tankGlow.withValues(alpha: 0.25)),
      ),
      child: sprite,
    );
  }
}

int _residentDays({required DateTime createdAt, required DateTime now}) {
  final elapsed = now.toUtc().difference(createdAt.toUtc()).inDays;
  return elapsed.clamp(0, 99999) + 1;
}

String _identityLabel(
  FishInstance fish,
  FishSpecies? species,
  FishVariant? variant,
) {
  final appearance = fish.customAppearance;
  if (appearance != null) return '组合式自定义鱼 · ${appearance.summary}';
  if (species == null) return '住在你的安静水域';
  if (variant == null) return species.nameZh;
  return '${species.nameZh} · ${variant.label}';
}
