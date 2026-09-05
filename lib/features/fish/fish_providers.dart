import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase.dart';
import 'fish_models.dart';
import 'fish_repository.dart';

final fishRepositoryProvider = Provider<FishRepository>((ref) {
  return SupabaseFishRepository(getSupabase());
});

final fishCatalogProvider = FutureProvider<FishCatalog>((ref) {
  return ref.watch(fishRepositoryProvider).fetchCatalog();
});

final tankFishProvider = StreamProvider.family<List<FishInstance>, String>((
  ref,
  tankId,
) {
  return ref.watch(fishRepositoryProvider).watchFish(tankId);
});
