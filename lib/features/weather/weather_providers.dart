import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase.dart';
import 'weather_repository.dart';

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return OpenMeteoWeatherRepository(getSupabase());
});
