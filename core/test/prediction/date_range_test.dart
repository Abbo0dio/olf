import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  test('lengthInDays counts both ends', () {
    expect(
      DateRange(DateTime(2026, 1, 1), DateTime(2026, 1, 1)).lengthInDays,
      1,
    );
    expect(
      DateRange(DateTime(2026, 1, 1), DateTime(2026, 1, 7)).lengthInDays,
      7,
    );
  });

  test('contains is inclusive of both ends and calendar-date only', () {
    final r = DateRange(DateTime(2026, 3, 10), DateTime(2026, 3, 14));
    expect(r.contains(DateTime(2026, 3, 10)), isTrue);
    expect(r.contains(DateTime(2026, 3, 14, 23, 59)), isTrue);
    expect(r.contains(DateTime(2026, 3, 12)), isTrue);
    expect(r.contains(DateTime(2026, 3, 9)), isFalse);
    expect(r.contains(DateTime(2026, 3, 15)), isFalse);
  });

  test('time-of-day is stripped on construction', () {
    final r = DateRange(
      DateTime(2026, 1, 1, 23, 30),
      DateTime(2026, 1, 3, 2, 15),
    );
    expect(r.start, DateTime(2026, 1, 1));
    expect(r.end, DateTime(2026, 1, 3));
    expect(r.lengthInDays, 3);
  });

  test('value equality', () {
    expect(
      DateRange(DateTime(2026, 1, 1), DateTime(2026, 1, 5)),
      DateRange(DateTime(2026, 1, 1, 8), DateTime(2026, 1, 5, 20)),
    );
    expect(
      DateRange(DateTime(2026, 1, 1), DateTime(2026, 1, 5)).hashCode,
      DateRange(DateTime(2026, 1, 1), DateTime(2026, 1, 5)).hashCode,
    );
    expect(
      DateRange(DateTime(2026, 1, 1), DateTime(2026, 1, 5)) ==
          DateRange(DateTime(2026, 1, 1), DateTime(2026, 1, 6)),
      isFalse,
    );
  });

  test('end before start is rejected', () {
    expect(
      () => DateRange(DateTime(2026, 1, 5), DateTime(2026, 1, 1)),
      throwsA(isA<AssertionError>()),
    );
  });
}
