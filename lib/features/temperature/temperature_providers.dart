import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase.dart';
import 'temperature_repository.dart';

final tankTemperatureRepositoryProvider = Provider<TankTemperatureRepository>(
  (ref) => SupabaseTankTemperatureRepository(getSupabase()),
);
