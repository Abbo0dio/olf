import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  PregnancyStartReference ref(PregnancyReferenceKind kind, DateTime date) =>
      PregnancyStartReference(kind: kind, date: date);

  group('gestationalAgeAsOf — from a last-menstrual-period date', () {
    final lmp = ref(
      PregnancyReferenceKind.lastMenstrualPeriod,
      DateTime(2026, 1, 1),
    );

    test('day 0 is week 0, day 0', () {
      final ga = gestationalAgeAsOf(lmp, asOf: DateTime(2026, 1, 1))!;
      expect(ga.completedWeeks, 0);
      expect(ga.daysIntoWeek, 0);
      expect(ga.totalDays, 0);
      expect(ga.trimester, PregnancyTrimester.first);
    });

    test('100 days in is 14 weeks, 2 days', () {
      final ga = gestationalAgeAsOf(
        lmp,
        asOf: DateTime(2026, 1, 1).add(const Duration(days: 100)),
      )!;
      expect(ga.completedWeeks, 14);
      expect(ga.daysIntoWeek, 2);
      expect(ga.compact, '14+2');
      expect(ga.trimester, PregnancyTrimester.second);
    });

    test('estimated due date is the anchor + 280 days', () {
      expect(
        lmp.estimatedDueDate,
        DateTime(2026, 1, 1).add(const Duration(days: 280)),
      );
    });
  });

  group('gestationalAgeAsOf — from an estimated due date', () {
    // Due date 2026-10-08 → LMP anchor 280 days earlier = 2026-01-01.
    final due = ref(PregnancyReferenceKind.dueDate, DateTime(2026, 10, 8));

    test('anchor is 280 days before the due date', () {
      expect(due.lmpAnchor, DateTime(2026, 1, 1));
      expect(due.estimatedDueDate, DateTime(2026, 10, 8));
    });

    test('matches the LMP result for the same implied anchor', () {
      final ga = gestationalAgeAsOf(
        due,
        asOf: DateTime(2026, 1, 1).add(const Duration(days: 190)),
      )!;
      expect(ga.completedWeeks, 27);
      expect(ga.daysIntoWeek, 1);
      expect(ga.trimester, PregnancyTrimester.second);
    });
  });

  group('gestationalAgeAsOf — from a conception date', () {
    // Conception 2026-01-15 → LMP anchor 14 days earlier = 2026-01-01.
    final conception = ref(
      PregnancyReferenceKind.conceptionDate,
      DateTime(2026, 1, 15),
    );

    test('anchor is 14 days before conception', () {
      expect(conception.lmpAnchor, DateTime(2026, 1, 1));
    });

    test('56 days after conception is week 10, day 0', () {
      final ga = gestationalAgeAsOf(
        conception,
        asOf: DateTime(2026, 1, 15).add(const Duration(days: 56)),
      )!;
      expect(ga.completedWeeks, 10);
      expect(ga.daysIntoWeek, 0);
      expect(ga.trimester, PregnancyTrimester.first);
    });

    test('conception day itself is week 2, day 0 — not a negative age', () {
      final ga = gestationalAgeAsOf(conception, asOf: DateTime(2026, 1, 15))!;
      expect(ga.completedWeeks, 2);
      expect(ga.daysIntoWeek, 0);
    });

    test(
      'exactly 14 days before conception is week 0 — the anchor, not below',
      () {
        final ga = gestationalAgeAsOf(conception, asOf: DateTime(2026, 1, 1))!;
        expect(ga.totalDays, 0);
      },
    );
  });

  group('week and trimester boundaries', () {
    final lmp = ref(
      PregnancyReferenceKind.lastMenstrualPeriod,
      DateTime(2026, 1, 1),
    );

    GestationalAge at(int days) => gestationalAgeAsOf(
      lmp,
      asOf: DateTime(2026, 1, 1).add(Duration(days: days)),
    )!;

    test('13w6d is the first trimester, 14w0d is the second', () {
      expect(at(13 * 7 + 6).trimester, PregnancyTrimester.first);
      expect(at(14 * 7).completedWeeks, 14);
      expect(at(14 * 7).trimester, PregnancyTrimester.second);
    });

    test('27w6d is the second trimester, 28w0d is the third', () {
      expect(at(27 * 7 + 6).trimester, PregnancyTrimester.second);
      expect(at(28 * 7).completedWeeks, 28);
      expect(at(28 * 7).trimester, PregnancyTrimester.third);
    });

    test('trimesterForWeek matches at the edges', () {
      expect(trimesterForWeek(13), PregnancyTrimester.first);
      expect(trimesterForWeek(14), PregnancyTrimester.second);
      expect(trimesterForWeek(27), PregnancyTrimester.second);
      expect(trimesterForWeek(28), PregnancyTrimester.third);
    });

    test(
      'weekForNote clamps a post-dates pregnancy to the last covered week',
      () {
        final ga = at(45 * 7 + 3);
        expect(ga.completedWeeks, 45);
        expect(ga.weekForNote, kMaxPregnancyWeek);
      },
    );
  });

  group(
    'a date before the reference is an honest null, never a negative week',
    () {
      test('LMP: the day before the anchor', () {
        final lmp = ref(
          PregnancyReferenceKind.lastMenstrualPeriod,
          DateTime(2026, 6, 10),
        );
        expect(gestationalAgeAsOf(lmp, asOf: DateTime(2026, 6, 9)), isNull);
      });

      test('conception: more than 14 days before conception', () {
        final conception = ref(
          PregnancyReferenceKind.conceptionDate,
          DateTime(2026, 6, 10),
        );
        expect(
          gestationalAgeAsOf(conception, asOf: DateTime(2026, 5, 20)),
          isNull,
        );
      });

      test('due date: an as-of day before the implied anchor', () {
        final due = ref(PregnancyReferenceKind.dueDate, DateTime(2026, 12, 1));
        expect(gestationalAgeAsOf(due, asOf: DateTime(2026, 1, 1)), isNull);
      });
    },
  );

  test('the result is a pure function of the injected as-of day', () {
    final lmp = ref(
      PregnancyReferenceKind.lastMenstrualPeriod,
      DateTime(2026, 1, 1),
    );
    final early = gestationalAgeAsOf(lmp, asOf: DateTime(2026, 3, 1))!;
    final later = gestationalAgeAsOf(lmp, asOf: DateTime(2026, 4, 1))!;
    expect(early, isNot(equals(later)));
    expect(later.totalDays - early.totalDays, 31);
    // Deterministic: same inputs, same output, equal by value.
    expect(gestationalAgeAsOf(lmp, asOf: DateTime(2026, 3, 1)), equals(early));
  });

  test('time-of-day on the reference and the as-of day is ignored', () {
    final withTime = PregnancyStartReference(
      kind: PregnancyReferenceKind.lastMenstrualPeriod,
      date: DateTime(2026, 1, 1, 23, 59),
    );
    final ga = gestationalAgeAsOf(withTime, asOf: DateTime(2026, 2, 1, 0, 1))!;
    expect(ga.totalDays, 31);
  });
}
