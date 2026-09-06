/// Pure gestational-age maths for pregnancy mode (p7.2a).
///
/// Everything here is derived from a single [PregnancyStartReference] the user
/// gives once — a last-menstrual-period date, an estimated due date, or a
/// conception date. The reference is normalised to an **LMP anchor**
/// ([PregnancyStartReference.lmpAnchor]) and every number is measured from
/// there, so the three reference kinds share one code path.
///
/// `core` stays `DateTime.now()`-free: the "as of" day is always injected (see
/// `docs/plan/phases/phase-07.md`, "Phase-wide constraints").
library;

import 'package:meta/meta.dart';

import '../date_math.dart';

/// Days from the LMP anchor to the estimated due date — Naegele's rule
/// (LMP + 280 days). A convention, not a clinical promise.
const int kGestationTermDays = 280;

/// Days from the LMP anchor to conception — the usual "two weeks after your
/// last period" approximation.
const int kConceptionToLmpDays = 14;

/// The last week that [kPregnancyWeekNotes] carries a note for; gestational age
/// past this still reports its true week, the note lookup just clamps here.
const int kMaxPregnancyWeek = 42;

/// Which date the user gave as the pregnancy's start reference.
enum PregnancyReferenceKind {
  /// First day of the last menstrual period — the anchor itself.
  lastMenstrualPeriod,

  /// An estimated due date (from a scan or a care provider). The anchor is
  /// [kGestationTermDays] days before it.
  dueDate,

  /// A known or estimated conception date. The anchor is [kConceptionToLmpDays]
  /// days before it.
  conceptionDate,
}

/// The three trimesters, by a common week-based convention: weeks 0–13 are the
/// first, 14–27 the second, 28+ the third. Non-clinical — pregnancy mode uses
/// it only to label the week view.
enum PregnancyTrimester { first, second, third }

/// The trimester a given count of [completedWeeks] falls in.
PregnancyTrimester trimesterForWeek(int completedWeeks) {
  if (completedWeeks <= 13) return PregnancyTrimester.first;
  if (completedWeeks <= 27) return PregnancyTrimester.second;
  return PregnancyTrimester.third;
}

/// The date the user gave, plus which kind of date it is. Normalised to a
/// calendar day; the time-of-day is dropped.
@immutable
class PregnancyStartReference {
  PregnancyStartReference({required this.kind, required DateTime date})
    : date = dateOnly(date);

  final PregnancyReferenceKind kind;

  /// The calendar date the user entered for [kind].
  final DateTime date;

  /// [date] mapped back to a first-day-of-last-period anchor. Every gestational
  /// number is measured from here.
  DateTime get lmpAnchor => switch (kind) {
    PregnancyReferenceKind.lastMenstrualPeriod => date,
    PregnancyReferenceKind.dueDate => addDays(date, -kGestationTermDays),
    PregnancyReferenceKind.conceptionDate => addDays(
      date,
      -kConceptionToLmpDays,
    ),
  };

  /// Estimated due date — [kGestationTermDays] days after [lmpAnchor]. For a
  /// [PregnancyReferenceKind.dueDate] reference this returns [date] unchanged.
  DateTime get estimatedDueDate => addDays(lmpAnchor, kGestationTermDays);

  @override
  bool operator ==(Object other) =>
      other is PregnancyStartReference &&
      other.kind == kind &&
      other.date == date;

  @override
  int get hashCode => Object.hash(kind, date);

  @override
  String toString() => 'PregnancyStartReference(${kind.name}, $date)';
}

/// A point-in-time gestational age: whole weeks completed since the LMP anchor,
/// the days into the current week, and the trimester that lands in.
@immutable
class GestationalAge {
  const GestationalAge({
    required this.completedWeeks,
    required this.daysIntoWeek,
  });

  /// Whole weeks since the LMP anchor. `0` through the first seven days.
  final int completedWeeks;

  /// Days into [completedWeeks] — `0` to `6`.
  final int daysIntoWeek;

  /// Whole days since the LMP anchor.
  int get totalDays => completedWeeks * 7 + daysIntoWeek;

  /// The trimester [completedWeeks] falls in.
  PregnancyTrimester get trimester => trimesterForWeek(completedWeeks);

  /// [completedWeeks] clamped to the range [kPregnancyWeekNotes] covers.
  int get weekForNote => completedWeeks.clamp(0, kMaxPregnancyWeek);

  /// Obstetric shorthand — "24+3" for 24 weeks and 3 days.
  String get compact => '$completedWeeks+$daysIntoWeek';

  @override
  bool operator ==(Object other) =>
      other is GestationalAge &&
      other.completedWeeks == completedWeeks &&
      other.daysIntoWeek == daysIntoWeek;

  @override
  int get hashCode => Object.hash(completedWeeks, daysIntoWeek);

  @override
  String toString() => 'GestationalAge($compact)';
}

/// Gestational age from [reference] as of [asOf] (an injected calendar day —
/// never `DateTime.now()` in `core`).
///
/// Returns `null` when [asOf] falls before [reference]'s LMP anchor: pregnancy
/// mode shows a "check your dates" message rather than a negative week. A
/// conception date entered exactly [kConceptionToLmpDays] days after the anchor
/// still resolves to week 0, not a negative age.
GestationalAge? gestationalAgeAsOf(
  PregnancyStartReference reference, {
  required DateTime asOf,
}) {
  final totalDays = daysBetween(reference.lmpAnchor, asOf);
  if (totalDays < 0) return null;
  return GestationalAge(
    completedWeeks: totalDays ~/ 7,
    daysIntoWeek: totalDays % 7,
  );
}
