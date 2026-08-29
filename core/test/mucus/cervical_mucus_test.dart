import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  test('every type has a non-empty label and description', () {
    for (final t in CervicalMucusType.values) {
      expect(t.label, isNotEmpty);
      expect(t.description, isNotEmpty);
    }
  });

  test('fertilityRank is the enum order, driest to wettest', () {
    expect(CervicalMucusType.values.map((t) => t.fertilityRank), [
      0,
      1,
      2,
      3,
      4,
    ]);
    expect(CervicalMucusType.dry.fertilityRank, 0);
    expect(CervicalMucusType.eggWhite.fertilityRank, 4);
  });

  test('creamy and wetter count as fertile-quality', () {
    expect(CervicalMucusType.dry.isFertileQuality, isFalse);
    expect(CervicalMucusType.sticky.isFertileQuality, isFalse);
    expect(CervicalMucusType.creamy.isFertileQuality, isTrue);
    expect(CervicalMucusType.watery.isFertileQuality, isTrue);
    expect(CervicalMucusType.eggWhite.isFertileQuality, isTrue);
  });
}
