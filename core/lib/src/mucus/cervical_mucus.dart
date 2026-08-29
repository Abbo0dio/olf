import '../db/tables.dart';

/// Display + fertility semantics for [CervicalMucusType].
extension CervicalMucusTypeInfo on CervicalMucusType {
  /// Short, neutral label for a chip.
  String get label => switch (this) {
    CervicalMucusType.dry => 'Dry',
    CervicalMucusType.sticky => 'Sticky',
    CervicalMucusType.creamy => 'Creamy',
    CervicalMucusType.watery => 'Watery',
    CervicalMucusType.eggWhite => 'Egg-white',
  };

  /// A longer hint shown under the picker.
  String get description => switch (this) {
    CervicalMucusType.dry => 'Little or none',
    CervicalMucusType.sticky => 'Thick, tacky, breaks easily',
    CervicalMucusType.creamy => 'Lotion-like, white or cream',
    CervicalMucusType.watery => 'Thin, clear, slippery',
    CervicalMucusType.eggWhite => 'Clear and stretchy — peak fertility',
  };

  /// 0 (driest) … 4 (most fertile). Matches the enum's declared order.
  int get fertilityRank => index;

  /// `true` for qualities associated with the fertile window — creamy and
  /// wetter. These feed the observed fertile-window line on the prediction card.
  bool get isFertileQuality => fertilityRank >= CervicalMucusType.creamy.index;
}
