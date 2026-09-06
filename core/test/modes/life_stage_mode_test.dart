import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  test('every mode has a distinct, namespaced app_settings key', () {
    final keys = LifeStageMode.values.map((m) => m.settingKey).toSet();
    expect(keys.length, LifeStageMode.values.length);
    for (final key in keys) {
      expect(key, startsWith('mode.'));
    }
  });

  test('key is derived from the enum name', () {
    expect(LifeStageMode.postpartum.settingKey, 'mode.postpartum');
    expect(
      LifeStageMode.birthControlSwitch.settingKey,
      'mode.birthControlSwitch',
    );
  });

  test('only the exact string "true" counts as enabled', () {
    expect(lifeStageModeEnabled('true'), isTrue);
    expect(lifeStageModeEnabled('false'), isFalse);
    expect(lifeStageModeEnabled(null), isFalse);
    expect(lifeStageModeEnabled(''), isFalse);
    expect(lifeStageModeEnabled('TRUE'), isFalse);
    expect(lifeStageModeEnabled('1'), isFalse);
  });

  test('lifeStageModeValue round-trips through lifeStageModeEnabled', () {
    expect(lifeStageModeEnabled(lifeStageModeValue(enabled: true)), isTrue);
    expect(lifeStageModeEnabled(lifeStageModeValue(enabled: false)), isFalse);
  });
}
