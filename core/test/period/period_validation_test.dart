import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

/// A stored period with the dates that matter for validation. `id` defaults to
/// something that will not collide with a typical `editingId` in these tests.
Period _stored(DateTime start, DateTime? end, {int id = 1}) => Period(
  id: id,
  startDate: start,
  endDate: end,
  createdAt: DateTime(2020),
  updatedAt: DateTime(2020),
);

PeriodDraft _draft(DateTime start, [DateTime? end]) =>
    PeriodDraft(start: start, end: end);

void main() {
  final today = DateTime(2026, 8, 28);

  group('impossible ranges', () {
    test('a simple past range is valid', () {
      expect(
        validatePeriod(
          _draft(DateTime(2026, 8, 1), DateTime(2026, 8, 5)),
          existing: const [],
          today: today,
        ),
        isNull,
      );
    });

    test('a single-day period (start == end) is valid', () {
      expect(
        validatePeriod(
          _draft(DateTime(2026, 8, 1), DateTime(2026, 8, 1)),
          existing: const [],
          today: today,
        ),
        isNull,
      );
    });

    test('an open-ended period (no end) is valid', () {
      expect(
        validatePeriod(
          _draft(DateTime(2026, 8, 25)),
          existing: const [],
          today: today,
        ),
        isNull,
      );
    });

    test('end before start is rejected', () {
      expect(
        validatePeriod(
          _draft(DateTime(2026, 8, 5), DateTime(2026, 8, 1)),
          existing: const [],
          today: today,
        ),
        PeriodValidationError.endBeforeStart,
      );
    });

    test('start in the future is rejected', () {
      expect(
        validatePeriod(
          _draft(DateTime(2026, 8, 29)),
          existing: const [],
          today: today,
        ),
        PeriodValidationError.startInFuture,
      );
    });

    test('start today is allowed', () {
      expect(
        validatePeriod(_draft(today), existing: const [], today: today),
        isNull,
      );
    });

    test('end in the future is rejected', () {
      expect(
        validatePeriod(
          _draft(DateTime(2026, 8, 27), DateTime(2026, 8, 30)),
          existing: const [],
          today: today,
        ),
        PeriodValidationError.endInFuture,
      );
    });

    test('time-of-day is ignored — a range ending later today is fine', () {
      expect(
        validatePeriod(
          PeriodDraft(
            start: DateTime(2026, 8, 27, 6),
            end: DateTime(2026, 8, 28, 23, 59),
          ),
          existing: const [],
          today: DateTime(2026, 8, 28, 1),
        ),
        isNull,
      );
    });
  });

  group('overlap', () {
    final existing = [_stored(DateTime(2026, 8, 10), DateTime(2026, 8, 15))];

    test('an identical range overlaps', () {
      expect(
        validatePeriod(
          _draft(DateTime(2026, 8, 10), DateTime(2026, 8, 15)),
          existing: existing,
          today: today,
        ),
        PeriodValidationError.overlapsExisting,
      );
    });

    test('a range fully inside an existing one overlaps', () {
      expect(
        validatePeriod(
          _draft(DateTime(2026, 8, 12), DateTime(2026, 8, 13)),
          existing: existing,
          today: today,
        ),
        PeriodValidationError.overlapsExisting,
      );
    });

    test('a range that swallows an existing one overlaps', () {
      expect(
        validatePeriod(
          _draft(DateTime(2026, 8, 1), DateTime(2026, 8, 20)),
          existing: existing,
          today: today,
        ),
        PeriodValidationError.overlapsExisting,
      );
    });

    test('overlap on the leading edge', () {
      expect(
        validatePeriod(
          _draft(DateTime(2026, 8, 5), DateTime(2026, 8, 10)),
          existing: existing,
          today: today,
        ),
        PeriodValidationError.overlapsExisting,
      );
    });

    test('overlap on the trailing edge', () {
      expect(
        validatePeriod(
          _draft(DateTime(2026, 8, 15), DateTime(2026, 8, 18)),
          existing: existing,
          today: today,
        ),
        PeriodValidationError.overlapsExisting,
      );
    });

    test('a range that only touches one shared day still overlaps', () {
      expect(
        validatePeriod(
          _draft(DateTime(2026, 8, 1), DateTime(2026, 8, 10)),
          existing: existing,
          today: today,
        ),
        PeriodValidationError.overlapsExisting,
      );
    });

    test('an adjacent range with no shared day is allowed', () {
      expect(
        validatePeriod(
          _draft(DateTime(2026, 8, 16), DateTime(2026, 8, 18)),
          existing: existing,
          today: today,
        ),
        isNull,
      );
      expect(
        validatePeriod(
          _draft(DateTime(2026, 8, 7), DateTime(2026, 8, 9)),
          existing: existing,
          today: today,
        ),
        isNull,
      );
    });

    test('an open-ended existing period blocks anything logged after it', () {
      final ongoing = [_stored(DateTime(2026, 8, 20), null)];
      expect(
        validatePeriod(
          _draft(DateTime(2026, 8, 25), DateTime(2026, 8, 26)),
          existing: ongoing,
          today: today,
        ),
        PeriodValidationError.overlapsExisting,
      );
    });

    test('an open-ended existing period does not block earlier history', () {
      final ongoing = [_stored(DateTime(2026, 8, 20), null)];
      expect(
        validatePeriod(
          _draft(DateTime(2026, 8, 1), DateTime(2026, 8, 5)),
          existing: ongoing,
          today: today,
        ),
        isNull,
      );
    });

    test('an open-ended candidate can overlap an existing dated period', () {
      expect(
        validatePeriod(
          _draft(DateTime(2026, 8, 14)),
          existing: existing,
          today: today,
        ),
        PeriodValidationError.overlapsExisting,
      );
    });
  });

  group('editing', () {
    final a = _stored(DateTime(2026, 8, 10), DateTime(2026, 8, 15), id: 1);
    final b = _stored(DateTime(2026, 7, 1), DateTime(2026, 7, 6), id: 2);

    test('a period does not overlap itself when re-saved unchanged', () {
      expect(
        validatePeriod(
          _draft(DateTime(2026, 8, 10), DateTime(2026, 8, 15)),
          existing: [a, b],
          today: today,
          editingId: 1,
        ),
        isNull,
      );
    });

    test('extending a period is allowed while it clears the others', () {
      expect(
        validatePeriod(
          _draft(DateTime(2026, 8, 8), DateTime(2026, 8, 18)),
          existing: [a, b],
          today: today,
          editingId: 1,
        ),
        isNull,
      );
    });

    test('an edit cannot be dragged onto a different period', () {
      expect(
        validatePeriod(
          _draft(DateTime(2026, 7, 3), DateTime(2026, 7, 4)),
          existing: [a, b],
          today: today,
          editingId: 1,
        ),
        PeriodValidationError.overlapsExisting,
      );
    });
  });

  test('every error has a non-empty, distinct message', () {
    final messages = PeriodValidationError.values
        .map((e) => e.describe())
        .toSet();
    expect(messages, hasLength(PeriodValidationError.values.length));
    expect(messages.every((m) => m.trim().isNotEmpty), isTrue);
  });
}
