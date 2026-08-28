import 'package:olf_core/olf_core.dart';

/// Display label for a flow intensity, e.g. `Light`.
extension FlowIntensityLabel on FlowIntensity {
  String get label => switch (this) {
    FlowIntensity.spotting => 'Spotting',
    FlowIntensity.light => 'Light',
    FlowIntensity.medium => 'Medium',
    FlowIntensity.heavy => 'Heavy',
  };
}

/// Display label for a clot size, e.g. `Small`.
extension ClotSizeLabel on ClotSize {
  String get label => switch (this) {
    ClotSize.small => 'Small',
    ClotSize.medium => 'Medium',
    ClotSize.large => 'Large',
  };
}

/// One-line summary of a day's flow for a screen-reader label, e.g.
/// `flow heavy with large clots`.
String flowSemantics(FlowIntensity intensity, ClotSize? clotSize) {
  final base = 'flow ${intensity.label.toLowerCase()}';
  if (clotSize == null) return base;
  return '$base with ${clotSize.label.toLowerCase()} clots';
}
