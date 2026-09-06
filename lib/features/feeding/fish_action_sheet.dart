import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../fish/fish_models.dart';
import '../fish/fish_providers.dart';
import 'satiety.dart';

class FishActionSheet extends ConsumerStatefulWidget {
  const FishActionSheet({required this.fish, super.key});

  final FishInstance fish;

  @override
  ConsumerState<FishActionSheet> createState() => _FishActionSheetState();
}

class _FishActionSheetState extends ConsumerState<FishActionSheet> {
  late FishInstance _fish = widget.fish;
  var _isFeeding = false;

  Future<void> _feed() async {
    if (_isFeeding || _fish.satiety >= 100) return;
    setState(() => _isFeeding = true);
    try {
      final fedFish = await ref.read(fishRepositoryProvider).feedFish(_fish.id);
      if (mounted) setState(() => _fish = fedFish);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时没能喂食，检查网络后再试试。')));
      }
    } finally {
      if (mounted) setState(() => _isFeeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lowSatiety = isLowSatiety(_fish.satiety);
    final progressColor = lowSatiety ? Tokens.amber : Tokens.tankGlow;
    final feedLabel = _fish.satiety >= 100
        ? '它现在吃得很满足'
        : '喂食 +$defaultFeedAmount';

    return SafeArea(
      top: false,
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
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _fish.name,
                    style: const TextStyle(
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
            const SizedBox(height: 12),
            Text(
              '阶段：${_fish.growthStage.nameZh}',
              style: const TextStyle(color: Tokens.textDim, fontSize: 14),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  '饱腹度',
                  style: TextStyle(color: Tokens.textDim, fontSize: 14),
                ),
                const Spacer(),
                Text(
                  '${_fish.satiety}%',
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
                value: _fish.satiety / 100,
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
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isFeeding || _fish.satiety >= 100 ? null : _feed,
                style: FilledButton.styleFrom(
                  backgroundColor: Tokens.tankGlow,
                  foregroundColor: Tokens.primaryBg,
                  disabledBackgroundColor: Tokens.textDim.withValues(
                    alpha: 0.28,
                  ),
                  disabledForegroundColor: Tokens.textDim,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _isFeeding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restaurant_rounded),
                label: Text(feedLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
