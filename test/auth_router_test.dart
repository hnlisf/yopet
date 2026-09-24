import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/core/router.dart';

void main() {
  test('a just-authenticated user is allowed into the tank immediately', () {
    expect(
      redirectForCurrentAuthState(
        matchedLocation: '/home',
        isAuthenticated: true,
      ),
      isNull,
    );
  });

  test('auth entry routes send an established session to the tank', () {
    expect(
      redirectForCurrentAuthState(
        matchedLocation: '/sign-in',
        isAuthenticated: true,
      ),
      '/home',
    );
  });

  test('a signed-out user remains at sign-in', () {
    expect(
      redirectForCurrentAuthState(
        matchedLocation: '/sign-in',
        isAuthenticated: false,
      ),
      isNull,
    );
  });
}
