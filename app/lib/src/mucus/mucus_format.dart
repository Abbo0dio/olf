import 'package:olf_core/olf_core.dart';

/// One-line summary of a mucus observation for a screen-reader label, e.g.
/// `cervical fluid: egg-white`.
String mucusSemantics(CervicalMucusType type) =>
    'cervical fluid: ${type.label.toLowerCase()}';
