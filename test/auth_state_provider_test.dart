import 'package:flutter_test/flutter_test.dart';
import 'package:pushin_reload/state/auth_state_provider.dart';

void main() {
  test('setGuestCompletedSetup sets flag and keeps guest mode', () {
    final provider = AuthStateProvider();

    // initial state
    expect(provider.isGuestMode, isFalse);
    expect(provider.guestCompletedSetup, isFalse);

    // enter guest mode
    provider.enterGuestMode();
    expect(provider.isGuestMode, isTrue);

    // set completed
    provider.setGuestCompletedSetup();
    expect(provider.guestCompletedSetup, isTrue);
  });
}
