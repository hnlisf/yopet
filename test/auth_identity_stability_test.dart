import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yopet/features/auth/auth_providers.dart';

void main() {
  test('same-account token refresh does not notify identity dependants', () {
    User user(String id) => User(
      id: id,
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-10-23T00:00:00Z',
    );
    final container = ProviderContainer(
      overrides: [currentUserProvider.overrideWithValue(user('a'))],
    );
    addTearDown(container.dispose);
    final changes = <String?>[];
    container.listen(
      currentUserIdProvider,
      (_, next) => changes.add(next),
      fireImmediately: true,
    );
    container.updateOverrides([
      currentUserProvider.overrideWithValue(user('a')),
    ]);
    expect(container.read(currentUserIdProvider), 'a');
    expect(changes, ['a']);
    container.updateOverrides([
      currentUserProvider.overrideWithValue(user('b')),
    ]);
    expect(container.read(currentUserIdProvider), 'b');
    expect(changes, ['a', 'b']);
  });
}
