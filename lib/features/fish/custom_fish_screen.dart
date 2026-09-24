import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../auth/auth_providers.dart';
import '../home/tank.dart';
import 'custom_fish_flow_prototype.dart';
import 'fish_models.dart';
import 'fish_providers.dart';
import 'fish_repository.dart';

/// The production version of the approved combination-fish prototype.
///
/// It keeps the four choices explicit and previews their real layered artwork
/// before any data is stored, so a custom fish is never merely a renamed
/// catalogue fish.
class CustomFishScreen extends ConsumerStatefulWidget {
  const CustomFishScreen({super.key});

  @override
  ConsumerState<CustomFishScreen> createState() => _CustomFishScreenState();
}

class _CustomFishScreenState extends ConsumerState<CustomFishScreen> {
  final _nameController = TextEditingController(text: '云尾');
  var _bodyIndex = 4;
  var _tailIndex = 1;
  var _patternIndex = 2;
  var _colorIndex = 0;
  var _studioCategory = 2;
  var _patternDensity = .58;
  var _patternSoftness = .64;
  var _saving = false;
  String? _nameError;

  CustomFishAppearance get _appearance => CustomFishAppearance(
    body: customFishBodies[_bodyIndex].id,
    tail: customFishTails[_tailIndex].id,
    pattern: customFishPatterns[_patternIndex].id,
    color: customFishColors[_colorIndex].id,
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tankAsync = ref.watch(tankStreamProvider);
    final catalogAsync = ref.watch(fishCatalogProvider);
    return Scaffold(
      backgroundColor: Tokens.primaryBg,
      body: tankAsync.when(
        loading: () => SafeArea(child: _loading()),
        error: (_, _) => SafeArea(
          child: _FailureState(
            message: '鱼缸暂时没有回应',
            onRetry: () => ref.invalidate(tankStreamProvider),
          ),
        ),
        data: (tank) {
          if (tank == null) return SafeArea(child: _loading());
          return catalogAsync.when(
            loading: () => SafeArea(child: _loading()),
            error: (_, _) => SafeArea(
              child: _FailureState(
                message: '鱼种图鉴加载失败',
                onRetry: () => ref.invalidate(fishCatalogProvider),
              ),
            ),
            data: (catalog) => _buildEditor(context, tank, catalog),
          );
        },
      ),
    );
  }

  Widget _buildEditor(BuildContext context, Tank tank, FishCatalog catalog) {
    final fishAsync = ref.watch(tankFishProvider(tank.id));
    final fishCount = fishAsync.value?.length ?? 0;
    final full = fishCount >= 5;
    return ColoredBox(
      color: const Color(0xFF07131D),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: CustomFishStudio(
            appearance: _appearance,
            category: _studioCategory,
            bodyIndex: _bodyIndex,
            tailIndex: _tailIndex,
            patternIndex: _patternIndex,
            colorIndex: _colorIndex,
            patternDensity: _patternDensity,
            patternSoftness: _patternSoftness,
            individualSeed: 0,
            nameController: _nameController,
            progressLabel: '$fishCount / 5',
            finishLabel: full ? '鱼缸住满了（5 / 5）' : '完成并放入鱼缸',
            isFinishing: _saving,
            finishEnabled: !full && !_saving,
            showIndividualVariation: false,
            nameError: _nameError,
            onBack: () => context.go('/pick-fish'),
            onCategoryChanged: (value) =>
                setState(() => _studioCategory = value),
            onBodyChanged: (value) => setState(() => _bodyIndex = value),
            onTailChanged: (value) => setState(() => _tailIndex = value),
            onPatternChanged: (value) => setState(() => _patternIndex = value),
            onColorChanged: (value) => setState(() => _colorIndex = value),
            onPatternDensityChanged: (value) =>
                setState(() => _patternDensity = value),
            onPatternSoftnessChanged: (value) =>
                setState(() => _patternSoftness = value),
            onVariationRequested: () {},
            onNameChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
            onFinish: () => _save(tank, catalog),
          ),
        ),
      ),
    );
  }

  Future<void> _save(Tank tank, FishCatalog catalog) async {
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
          .adoptCustomFish(
            tankId: tank.id,
            name: name,
            appearance: _appearance,
            availableTraits: catalog.traits,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name 已经成为你的专属鱼种')));
      context.go('/home');
    } on TankFullException {
      if (mounted) _showFullMessage(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂时没能保存，再试一次吧')));
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
