import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/decorations.dart';
import 'tank_decoration.dart';

abstract class DecorationRepository {
  Stream<List<TankDecoration>> watchDecorations(String tankId);

  Future<TankDecoration> placeDecoration({
    required String tankId,
    required DecorationDefinition decoration,
    Offset? position,
  });

  Future<void> moveDecoration({
    required TankDecoration decoration,
    required Offset position,
  });

  Future<void> resizeDecoration({
    required TankDecoration decoration,
    required double scaleFactor,
  });

  Future<void> removeDecoration(String decorationId);
}

class SupabaseDecorationRepository implements DecorationRepository {
  SupabaseDecorationRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<List<TankDecoration>> watchDecorations(String tankId) {
    return _client
        .from('tank_decorations')
        .stream(primaryKey: ['id'])
        .eq('tank_id', tankId)
        .order('placed_at')
        .map(
          (rows) => rows.map(TankDecoration.fromMap).toList(growable: false),
        );
  }

  @override
  Future<TankDecoration> placeDecoration({
    required String tankId,
    required DecorationDefinition decoration,
    Offset? position,
  }) async {
    final point = position ?? decoration.defaultPosition;
    final values = <String, dynamic>{
      'tank_id': tankId,
      'decoration_code': decoration.code,
      'decoration_type': decoration.type.name,
      'position_x': point.dx.clamp(0.0, 1.0),
      'position_y': point.dy.clamp(0.0, 1.0),
    };

    if (decoration.type != DecorationType.background) {
      final row = await _client
          .from('tank_decorations')
          .upsert(values, onConflict: 'tank_id,decoration_code')
          .select()
          .single();
      return TankDecoration.fromMap(row);
    }

    final existing = await _client
        .from('tank_decorations')
        .select('id')
        .eq('tank_id', tankId)
        .eq('decoration_type', DecorationType.background.name)
        .maybeSingle();
    final row = existing == null
        ? await _client
              .from('tank_decorations')
              .insert(values)
              .select()
              .single()
        : await _client
              .from('tank_decorations')
              .update(values)
              .eq('id', existing['id'] as String)
              .select()
              .single();
    return TankDecoration.fromMap(row);
  }

  @override
  Future<void> moveDecoration({
    required TankDecoration decoration,
    required Offset position,
  }) {
    return _client
        .from('tank_decorations')
        .update({
          'position_x': position.dx.clamp(0.0, 1.0),
          'position_y': position.dy.clamp(0.0, 1.0),
        })
        .eq('id', decoration.id);
  }

  @override
  Future<void> resizeDecoration({
    required TankDecoration decoration,
    required double scaleFactor,
  }) {
    return _client
        .from('tank_decorations')
        .update({'scale_factor': clampDecorationScale(scaleFactor)})
        .eq('id', decoration.id);
  }

  @override
  Future<void> removeDecoration(String decorationId) {
    return _client.from('tank_decorations').delete().eq('id', decorationId);
  }
}
