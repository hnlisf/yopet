import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../auth/auth_providers.dart';
import 'fish_models.dart';
import 'fish_providers.dart';
import 'fish_repository.dart';
import 'fish_sprite.dart';

class FishPickerScreen extends ConsumerStatefulWidget {
  const FishPickerScreen({super.key});

  @override
  ConsumerState<FishPickerScreen> createState() => _FishPickerScreenState();
}

class _FishPickerScreenState extends ConsumerState<FishPickerScreen> {
  final _nameController = TextEditingController();
  String? _speciesId;
  String? _variantId;
  bool _saving = false;
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tankAsync = ref.watch(tankStreamProvider);
    return Scaffold(
      backgroundColor: Tokens.primaryBg,
      body: SafeArea(
        child: tankAsync.when(
          loading: _loading,
          error: (error, _) => _FailureState(
            message: '鱼缸暂时没有回应',
            onRetry: () => ref.invalidate(tankStreamProvider),
          ),
          data: (tank) {
            if (tank == null) return _loading();
            return _buildCatalog(context, tank.id);
          },
        ),
      ),
    );
  }

  Widget _buildCatalog(BuildContext context, String tankId) {
    final catalogAsync = ref.watch(fishCatalogProvider);
    final fishAsync = ref.watch(tankFishProvider(tankId));
    return catalogAsync.when(
      loading: _loading,
      error: (error, _) => _FailureState(
        message: '鱼种图鉴加载失败',
        onRetry: () => ref.invalidate(fishCatalogProvider),
      ),
      data: (catalog) {
        if (catalog.species.isEmpty || catalog.traits.isEmpty) {
          return const _FailureState(message: '鱼种图鉴还没有准备好');
        }
        final species = catalog.species.firstWhere(
          (item) => item.id == _speciesId,
          orElse: () => catalog.species.first,
        );
        final variant = species.variants.firstWhere(
          (item) => item.id == _variantId,
          orElse: () => species.variants.first,
        );
        final fishCount = fishAsync.value?.length ?? 0;
        final full = fishCount >= 5;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              sliver: SliverList.list(
                children: [
                  _PickerHeader(
                    count: fishCount,
                    onBack: () => context.go('/home'),
                  ),
                  const SizedBox(height: 20),
                  _Preview(species: species, variant: variant),
                  const SizedBox(height: 28),
                  const _SectionTitle(
                    index: '01',
                    title: '选一个熟悉的轮廓',
                    caption: '保留真实鱼种辨识度，再加一点想象。',
                  ),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.9,
                        ),
                    itemCount: catalog.species.length,
                    itemBuilder: (context, index) {
                      final item = catalog.species[index];
                      final selected = item.id == species.id;
                      return _SpeciesTile(
                        species: item,
                        selected: selected,
                        onTap: () => setState(() {
                          _speciesId = item.id;
                          _variantId = item.variants.first.id;
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _CustomFishEntry(onTap: () => context.go('/custom-fish')),
                  const SizedBox(height: 28),
                  const _SectionTitle(
                    index: '02',
                    title: '挑一种水彩',
                    caption: '每种颜色都沿用同一个鱼种轮廓。',
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: species.variants
                        .map(
                          (item) => _VariantChip(
                            variant: item,
                            selected: item.id == variant.id,
                            onTap: () => setState(() => _variantId = item.id),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle(
                    index: '03',
                    title: '给它一个名字',
                    caption: '确认后会随机获得 1–3 个不重复的性格。',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nameController,
                    maxLength: 20,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: Tokens.text),
                    decoration: InputDecoration(
                      hintText: '例如：泡泡',
                      hintStyle: const TextStyle(color: Tokens.textDim),
                      errorText: _nameError,
                      counterStyle: const TextStyle(color: Tokens.textDim),
                      filled: true,
                      fillColor: Tokens.surface.withValues(alpha: 0.84),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: Tokens.tankGlow.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Tokens.tankGlow),
                      ),
                    ),
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                    onSubmitted: (_) {
                      if (!full && !_saving) {
                        _adopt(tankId, catalog, species, variant);
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: full ? () => _showFullMessage(context) : null,
                    child: SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        key: const Key('confirm-adoption'),
                        onPressed: full || _saving
                            ? null
                            : () => _adopt(tankId, catalog, species, variant),
                        style: FilledButton.styleFrom(
                          backgroundColor: Tokens.tankGlowSoft,
                          disabledBackgroundColor: Tokens.surface,
                          foregroundColor: Tokens.primaryBg,
                          disabledForegroundColor: Tokens.textDim,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Tokens.primaryBg,
                                ),
                              )
                            : const Icon(Icons.add_rounded),
                        label: Text(full ? '鱼缸住满了（5 / 5）' : '让它游进鱼缸'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _adopt(
    String tankId,
    FishCatalog catalog,
    FishSpecies species,
    FishVariant variant,
  ) async {
    final name = _nameController.text.trim();
    final length = name.runes.length;
    if (length < 1 || length > 20) {
      setState(() => _nameError = '请输入 1–20 个字符的名字');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(fishRepositoryProvider)
          .adoptFish(
            tankId: tankId,
            species: species,
            variant: variant,
            name: name,
            availableTraits: catalog.traits,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name 已经游进鱼缸了')));
      context.go('/home');
    } on TankFullException {
      if (mounted) _showFullMessage(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂时没能领养，再试一次吧')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showFullMessage(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('鱼缸已经住满 5 条鱼啦')));
  }

  Widget _loading() =>
      const Center(child: CircularProgressIndicator(color: Tokens.tankGlow));
}

class _PickerHeader extends StatelessWidget {
  const _PickerHeader({required this.count, required this.onBack});

  final int count;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '领养一条鱼',
                style: TextStyle(
                  color: Tokens.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text('慢慢选，不着急。', style: TextStyle(color: Tokens.textDim)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Tokens.tankGlow.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            '$count / 5',
            style: const TextStyle(
              color: Tokens.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.species, required this.variant});

  final FishSpecies species;
  final FishVariant variant;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF102838), Color(0xFF153747)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Tokens.tankGlow.withValues(alpha: 0.18)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.2,
              child: Image.asset(
                'assets/tank/background.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Center(
            child: FishSprite(species: species, variant: variant, width: 175),
          ),
          Positioned(
            left: 18,
            bottom: 14,
            child: Text(
              '${species.nameZh} · ${variant.label}',
              style: const TextStyle(
                color: Tokens.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.index,
    required this.title,
    required this.caption,
  });

  final String index;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(index, style: const TextStyle(color: Tokens.tankGlowSoft)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Tokens.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(caption, style: const TextStyle(color: Tokens.textDim)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpeciesTile extends StatelessWidget {
  const _SpeciesTile({
    required this.species,
    required this.selected,
    required this.onTap,
  });

  final FishSpecies species;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? Tokens.tankGlow.withValues(alpha: 0.14)
              : Tokens.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? Tokens.tankGlowSoft
                : Tokens.tankGlow.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: FishSprite(
                species: species,
                variant: species.variants.first,
                width: 82,
              ),
            ),
            Text(
              species.nameZh,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Tokens.text : Tokens.textDim,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariantChip extends StatelessWidget {
  const _VariantChip({
    required this.variant,
    required this.selected,
    required this.onTap,
  });

  final FishVariant variant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Tokens.tankGlow.withValues(alpha: 0.2),
      backgroundColor: Tokens.surface,
      side: BorderSide(
        color: selected ? Tokens.tankGlowSoft : Colors.transparent,
      ),
      avatar: CircleAvatar(backgroundColor: variant.color, radius: 8),
      label: Text(
        variant.label,
        style: TextStyle(color: selected ? Tokens.text : Tokens.textDim),
      ),
    );
  }
}

class _CustomFishEntry extends StatelessWidget {
  const _CustomFishEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '组合式自定义鱼',
      child: InkWell(
        key: const Key('custom-fish-entry'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Tokens.tankGlow.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Tokens.tankGlow.withValues(alpha: 0.35)),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                backgroundColor: Tokens.tankGlowSoft,
                foregroundColor: Tokens.primaryBg,
                child: Icon(Icons.auto_awesome_rounded),
              ),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '组合式自定义鱼',
                      style: TextStyle(
                        color: Tokens.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '体型、尾鳍、纹样和水彩都由你决定',
                      style: TextStyle(color: Tokens.textDim, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: Tokens.tankGlowSoft),
            ],
          ),
        ),
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.water_drop_outlined, color: Tokens.tankGlowSoft),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: Tokens.text)),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('再试一次')),
            ],
          ],
        ),
      ),
    );
  }
}
