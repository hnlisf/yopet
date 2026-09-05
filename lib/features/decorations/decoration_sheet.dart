import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../data/decorations.dart';
import 'decoration_providers.dart';
import 'tank_decoration.dart';

class DecorationSheet extends ConsumerStatefulWidget {
  const DecorationSheet({required this.tankId, super.key});

  final String tankId;

  @override
  ConsumerState<DecorationSheet> createState() => _DecorationSheetState();
}

class _DecorationSheetState extends ConsumerState<DecorationSheet> {
  DecorationType _activeType = DecorationType.plant;
  String? _savingCode;

  @override
  Widget build(BuildContext context) {
    final decorationsAsync = ref.watch(tankDecorationsProvider(widget.tankId));
    final placed = decorationsAsync.value ?? const <TankDecoration>[];
    final choices = decorationCatalog
        .where((decoration) => decoration.type == _activeType)
        .toList(growable: false);
    final selectedCodes = placed.map((decoration) => decoration.code).toSet();
    final backgrounds = placed
        .where((decoration) => decoration.type == DecorationType.background)
        .toList(growable: false);
    final activeBackground = backgrounds.isEmpty ? null : backgrounds.first;

    return SafeArea(
      top: false,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Tokens.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Tokens.textDim.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '布置鱼缸',
                          style: TextStyle(
                            color: Tokens.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '随心摆放，只改变眼前的风景。',
                          style: TextStyle(color: Tokens.textDim),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: Tokens.textDim,
                    tooltip: '关闭布置',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: DecorationType.values
                      .map(
                        (type) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(type.label),
                            selected: _activeType == type,
                            onSelected: (_) =>
                                setState(() => _activeType = type),
                            selectedColor: Tokens.tankGlow.withValues(
                              alpha: 0.2,
                            ),
                            backgroundColor: Tokens.primaryBg,
                            side: BorderSide(
                              color: _activeType == type
                                  ? Tokens.tankGlowSoft
                                  : Colors.transparent,
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '${_activeType.label}预设',
                    style: const TextStyle(
                      color: Tokens.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${choices.length} 件',
                    style: const TextStyle(color: Tokens.textDim),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.86,
                ),
                itemCount: choices.length,
                itemBuilder: (context, index) {
                  final choice = choices[index];
                  final selected = selectedCodes.contains(choice.code);
                  final saving = _savingCode == choice.code;
                  return _DecorationTile(
                    decoration: choice,
                    selected: selected,
                    saving: saving,
                    onTap: () => _place(choice),
                  );
                },
              ),
              if (_activeType == DecorationType.background &&
                  activeBackground != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _savingCode == activeBackground.code
                      ? null
                      : () => _removeBackground(activeBackground),
                  icon: const Icon(Icons.layers_clear_outlined),
                  label: const Text('恢复默认背景'),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: Tokens.tankGlowSoft,
                    foregroundColor: Tokens.primaryBg,
                  ),
                  child: const Text('完成布置'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _place(DecorationDefinition decoration) async {
    setState(() => _savingCode = decoration.code);
    try {
      await ref
          .read(decorationRepositoryProvider)
          .placeDecoration(tankId: widget.tankId, decoration: decoration);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时没能放进鱼缸，再试一次吧')));
      }
    } finally {
      if (mounted) setState(() => _savingCode = null);
    }
  }

  Future<void> _removeBackground(TankDecoration background) async {
    setState(() => _savingCode = background.code);
    try {
      await ref
          .read(decorationRepositoryProvider)
          .removeDecoration(background.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时没能恢复默认背景')));
      }
    } finally {
      if (mounted) setState(() => _savingCode = null);
    }
  }
}

class _DecorationTile extends StatelessWidget {
  const _DecorationTile({
    required this.decoration,
    required this.selected,
    required this.saving,
    required this.onTap,
  });

  final DecorationDefinition decoration;
  final bool selected;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('decoration-${decoration.code}'),
      onTap: saving ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? Tokens.tankGlow.withValues(alpha: 0.16)
              : Tokens.primaryBg.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? Tokens.tankGlowSoft
                : Tokens.tankGlow.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: saving
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Tokens.tankGlow,
                      ),
                    )
                  : Image.asset(
                      decoration.assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.auto_awesome_outlined,
                        color: Tokens.tankGlowSoft,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              decoration.nameZh,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Tokens.text : Tokens.textDim,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
