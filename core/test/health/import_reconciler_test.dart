import 'dart:math';

import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  const reconciler = ImportReconciler();

  HealthSample bbt(
    int day, {
    double value = 36.5,
    HealthDataSource source = HealthDataSource.appleHealth,
    String? id,
  }) => HealthSample.point(
    type: HealthSampleType.basalBodyTemperature,
    at: DateTime(2026, 4, day, 6, 30),
    value: value,
    unit: HealthUnit.celsius,
    source: source,
    externalId: id,
  );

  LocalSampleView local(
    int day, {
    double value = 36.5,
    HealthDataSource source = HealthDataSource.appleHealth,
    String? id,
  }) => LocalSampleView(
    localId: '2026-04-$day',
    type: HealthSampleType.basalBodyTemperature,
    day: DateTime(2026, 4, day),
    value: value,
    unit: HealthUnit.celsius,
    source: source,
    externalId: id,
  );

  group('ImportReconciler', () {
    test('no local rows → everything inserts', () {
      final plan = reconciler.reconcile(
        local: const [],
        incoming: [
          bbt(1, id: 'a'),
          bbt(2, id: 'b'),
        ],
      );
      expect(plan.inserts, [bbt(1, id: 'a'), bbt(2, id: 'b')]);
      expect(plan.updates, isEmpty);
      expect(plan.conflicts, isEmpty);
      expect(plan.skipped, isEmpty);
    });

    test('no incoming → empty plan', () {
      final plan = reconciler.reconcile(
        local: [local(1, id: 'a')],
        incoming: const [],
      );
      expect(plan.isEmpty, isTrue);
      expect(plan.total, 0);
    });

    test('update matched by externalId when same non-manual source', () {
      final plan = reconciler.reconcile(
        local: [local(1, value: 36.4, id: 'a')],
        incoming: [bbt(1, value: 36.7, id: 'a')],
      );
      expect(plan.inserts, isEmpty);
      expect(plan.conflicts, isEmpty);
      expect(plan.updates.single.localId, '2026-04-1');
      expect(plan.updates.single.incoming, bbt(1, value: 36.7, id: 'a'));
    });

    test(
      'update matched by (type, day) when both sides same source, no id',
      () {
        final plan = reconciler.reconcile(
          local: [local(3, value: 36.4)],
          incoming: [bbt(3, value: 36.9)],
        );
        expect(plan.updates.single.localId, '2026-04-3');
        expect(plan.inserts, isEmpty);
        expect(plan.conflicts, isEmpty);
      },
    );

    test('disagreement with a manual local row is always a conflict', () {
      final plan = reconciler.reconcile(
        local: [local(1, value: 36.4, source: HealthDataSource.manual)],
        incoming: [bbt(1, value: 36.8)],
      );
      expect(plan.updates, isEmpty);
      expect(plan.conflicts.single.reason, ConflictReason.manualDisagreement);
      expect(plan.conflicts.single.localId, '2026-04-1');
      expect(plan.conflicts.single.local.source, HealthDataSource.manual);
    });

    test(
      'manual local row with an externalId still conflicts, never updates',
      () {
        final plan = reconciler.reconcile(
          local: [
            local(1, value: 36.4, source: HealthDataSource.manual, id: 'a'),
          ],
          incoming: [bbt(1, value: 36.8, id: 'a')],
        );
        expect(plan.updates, isEmpty);
        expect(plan.conflicts.single.reason, ConflictReason.manualDisagreement);
      },
    );

    test(
      'disagreement across two platform sources is a cross-source conflict',
      () {
        final plan = reconciler.reconcile(
          local: [
            local(2, value: 36.4, source: HealthDataSource.healthConnect),
          ],
          incoming: [bbt(2, value: 36.9, source: HealthDataSource.appleHealth)],
        );
        expect(plan.updates, isEmpty);
        expect(
          plan.conflicts.single.reason,
          ConflictReason.crossSourceDisagreement,
        );
      },
    );

    test('same value from a different source is a skip, not a conflict', () {
      final plan = reconciler.reconcile(
        local: [local(2, value: 36.5, source: HealthDataSource.healthConnect)],
        incoming: [bbt(2, value: 36.5, source: HealthDataSource.appleHealth)],
      );
      expect(plan.conflicts, isEmpty);
      expect(plan.updates, isEmpty);
      expect(plan.skipped.single.localId, '2026-04-2');
    });

    test(
      'exact duplicate (value within tolerance, same source) is skipped',
      () {
        final plan = reconciler.reconcile(
          local: [local(1, value: 36.5, id: 'a')],
          incoming: [bbt(1, value: 36.504, id: 'a')],
        );
        expect(plan.skipped.single.localId, '2026-04-1');
        expect(plan.updates, isEmpty);
        expect(plan.inserts, isEmpty);
      },
    );

    test('a batch splits into every bucket at once', () {
      final plan = reconciler.reconcile(
        local: [
          local(1, value: 36.5, id: 'a'), // exact dupe → skip
          local(2, value: 36.4, id: 'b'), // revised → update
          local(3, value: 36.4, source: HealthDataSource.manual), // → conflict
        ],
        incoming: [
          bbt(1, value: 36.5, id: 'a'),
          bbt(2, value: 36.8, id: 'b'),
          bbt(3, value: 36.9),
          bbt(9, value: 36.6, id: 'z'), // new → insert
        ],
      );
      expect(plan.skipped.map((s) => s.localId), ['2026-04-1']);
      expect(plan.updates.map((u) => u.localId), ['2026-04-2']);
      expect(plan.conflicts.map((c) => c.localId), ['2026-04-3']);
      expect(plan.inserts.map((s) => s.externalId), ['z']);
      expect(plan.total, 4);
    });

    test('plan is independent of incoming order', () {
      final local2 = [
        local(1, value: 36.5, id: 'a'),
        local(2, value: 36.4, id: 'b'),
        local(3, value: 36.4, source: HealthDataSource.manual),
      ];
      final forward = [
        bbt(1, value: 36.5, id: 'a'),
        bbt(2, value: 36.8, id: 'b'),
        bbt(3, value: 36.9),
        bbt(9, value: 36.6, id: 'z'),
      ];
      final planA = reconciler.reconcile(local: local2, incoming: forward);
      final planB = reconciler.reconcile(
        local: local2.reversed.toList(),
        incoming: forward.reversed.toList(),
      );
      expect(planA, equals(planB));
      expect(planA.hashCode, planB.hashCode);
    });

    test('plan is independent of a shuffled larger batch', () {
      final localRows = [
        for (var d = 1; d <= 10; d++)
          local(d, value: 36.0 + d / 10, id: 'id-$d'),
      ];
      final incoming = [
        for (var d = 1; d <= 10; d++)
          bbt(d, value: 36.0 + d / 10 + (d.isEven ? 0.3 : 0.0), id: 'id-$d'),
        bbt(20, value: 37.0, id: 'new'),
      ];
      final base = reconciler.reconcile(local: localRows, incoming: incoming);
      for (var seed = 0; seed < 5; seed++) {
        final again = reconciler.reconcile(
          local: [...localRows]..shuffle(Random(seed + 100)),
          incoming: [...incoming]..shuffle(Random(seed)),
        );
        expect(again, equals(base), reason: 'seed $seed diverged');
      }
      // even days revised → update, odd days unchanged → skip, plus one insert
      expect(base.updates, hasLength(5));
      expect(base.skipped, hasLength(5));
      expect(base.inserts, hasLength(1));
    });
  });
}
