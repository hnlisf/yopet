import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase.dart';
import 'decoration_repository.dart';
import 'tank_decoration.dart';

final decorationRepositoryProvider = Provider<DecorationRepository>((ref) {
  return SupabaseDecorationRepository(getSupabase());
});

final tankDecorationsProvider =
    StreamProvider.family<List<TankDecoration>, String>((ref, tankId) {
      return ref.watch(decorationRepositoryProvider).watchDecorations(tankId);
    });
