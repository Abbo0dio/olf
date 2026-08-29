import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  final stamp = DateTime(2026, 7, 1);
  CervicalMucusEntry entry(DateTime date, CervicalMucusType type) =>
      CervicalMucusEntry(
        date: date,
        type: type,
        createdAt: stamp,
        updatedAt: stamp,
      );

  final cycleStart = DateTime(2026, 7, 1);
  final today = DateTime(2026, 7, 20);

  test('returns null when nothing fertile-quality is logged', () {
    final entries = [
      entry(DateTime(2026, 7, 3), CervicalMucusType.dry),
      entry(DateTime(2026, 7, 8), CervicalMucusType.sticky),
    ];
    expect(
      observedFertileWindow(entries, cycleStart: cycleStart, today: today),
      isNull,
    );
  });

  test('spans first fertile-quality day to a bit past the last', () {
    final entries = [
      entry(DateTime(2026, 7, 8), CervicalMucusType.sticky),
      entry(DateTime(2026, 7, 11), CervicalMucusType.creamy),
      entry(DateTime(2026, 7, 13), CervicalMucusType.eggWhite),
      entry(DateTime(2026, 7, 14), CervicalMucusType.watery),
    ];
    final window = observedFertileWindow(
      entries,
      cycleStart: cycleStart,
      today: today,
    );
    expect(window, isNotNull);
    expect(window!.start, DateTime(2026, 7, 11));
    // last fertile-quality day (14th) + fertileDaysAfterOvulation (1)
    expect(window.end, DateTime(2026, 7, 15));
  });

  test('ignores observations before the cycle start or after today', () {
    final entries = [
      entry(DateTime(2026, 6, 25), CervicalMucusType.eggWhite), // last cycle
      entry(DateTime(2026, 7, 12), CervicalMucusType.creamy), // counts
      entry(DateTime(2026, 7, 28), CervicalMucusType.eggWhite), // future
    ];
    final window = observedFertileWindow(
      entries,
      cycleStart: cycleStart,
      today: today,
    );
    expect(window!.start, DateTime(2026, 7, 12));
    expect(window.end, DateTime(2026, 7, 13));
  });

  test('a single fertile-quality day still yields a valid range', () {
    final entries = [entry(DateTime(2026, 7, 12), CervicalMucusType.eggWhite)];
    final window = observedFertileWindow(
      entries,
      cycleStart: cycleStart,
      today: today,
    );
    expect(window!.start, DateTime(2026, 7, 12));
    expect(window.end, DateTime(2026, 7, 13));
    expect(window.lengthInDays, 2);
  });
}
