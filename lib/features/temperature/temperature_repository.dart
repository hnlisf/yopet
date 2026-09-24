import 'package:supabase_flutter/supabase_flutter.dart';

import 'water_temperature.dart';

abstract class TankTemperatureRepository {
  Future<void> setWaterTemperature({
    required String tankId,
    required int temperature,
  });
}

class SupabaseTankTemperatureRepository implements TankTemperatureRepository {
  SupabaseTankTemperatureRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> setWaterTemperature({
    required String tankId,
    required int temperature,
  }) async {
    if (!isSupportedWaterTemperature(temperature)) {
      throw ArgumentError.value(
        temperature,
        'temperature',
        '水温需要在 $minWaterTemperature–$maxWaterTemperature°C 之间',
      );
    }
    await _client
        .from('tanks')
        .update({'water_temperature_c': temperature})
        .eq('id', tankId);
  }
}
