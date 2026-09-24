import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/auth/auth_providers.dart';

void main() {
  test('uses the SDK session during the auth-stream handoff after sign-in', () {
    const signedInUser = 'user-now-present-in-sdk';

    expect(
      resolveCurrentIdentity<String>(
        authEventIdentity: null,
        clientIdentity: signedInUser,
      ),
      signedInUser,
    );
  });
}
