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
    String? device,
  }) => HealthSample.point(
    type: HealthSampleType.basalBodyTemperature,
    at: DateTime(2026, 4, day, 6, 30),
    value: value,
    unit: HealthUnit.celsius,
    source: source,
    externalId: id,
    sourceDevice: device,
  );

  LocalSampleView local(
    int day, {
    double value = 36.5,
    HealthDataSource source = HealthDataSource.appleHealth,
    String? id,
    String? device,
  }) => LocalSampleView(
    localId: '2026-04-$day',
    type: HealthSampleType.basalBodyTemperature,
    day: DateTime(2026, 4, day),
    value: value,
    unit: HealthUnit.celsius,
    source: source,
    externalId: id,
    sourceDevice: device,
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
      'p6.4 write-back echo: manual row, externalId match, unchanged value → '
      'skip (not a spurious conflict)',
      () {
        final plan = reconciler.reconcile(
          local: [
            local(3, value: 36.6, source: HealthDataSource.manual, id: 'wb'),
          ],
          // The platform returns the row olf just pushed out, attributed to the
          // platform, same value.
          incoming: [
            bbt(3, value: 36.6, source: HealthDataSource.appleHealth, id: 'wb'),
          ],
        );
        expect(plan.conflicts, isEmpty);
        expect(plan.updates, isEmpty);
        expect(plan.inserts, isEmpty);
        expect(plan.skipped.single.localId, '2026-04-3');
      },
    );

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

    // ---- p8.2: device provenance (`sourceDevice`) ----------------------------

    group('sourceDevice (p8.2)', () {
      test('a device tag on a matched same-source update never changes the '
          'plan shape', () {
        // Same platform, same device, revised value → still a plain update; the
        // tag rides along on the incoming sample untouched.
        final plan = reconciler.reconcile(
          local: [local(1, value: 36.4, id: 'a', device: 'Oura')],
          incoming: [bbt(1, value: 36.8, id: 'a', device: 'Oura')],
        );
        expect(plan.conflicts, isEmpty);
        expect(plan.inserts, isEmpty);
        expect(plan.updates.single.localId, '2026-04-1');
        expect(plan.updates.single.incoming.sourceDevice, 'Oura');
      });

      test('a device revising its own earlier reading is an update, not a '
          'conflict', () {
        // Stored Oura row, a fresh Oura import for the same day with a corrected
        // value → a plain in-place update; nothing for the user to resolve.
        final plan = reconciler.reconcile(
          local: [local(1, value: 36.4, id: 'a', device: 'Oura')],
          incoming: [bbt(1, value: 36.9, id: 'a', device: 'Oura')],
        );
        expect(plan.conflicts, isEmpty);
        expect(plan.inserts, isEmpty);
        expect(plan.updates.single.localId, '2026-04-1');
        expect(plan.updates.single.incoming.value, 36.9);
      });

      test(
        'two same-batch incoming from the SAME device, same day, differing '
        'values → two inserts (unchanged pre-p8.2 shape), never a conflict',
        () {
          final plan = reconciler.reconcile(
            local: const [],
            incoming: [
              bbt(1, value: 36.4, device: 'Oura'),
              bbt(1, value: 36.9, device: 'Oura'),
            ],
          );
          expect(plan.conflicts, isEmpty);
          expect(plan.updates, isEmpty);
          expect(plan.inserts, hasLength(2));
          expect(plan.total, 2);
        },
      );

      test(
        'two known devices, same day, values agree → one reconciled reading',
        () {
          final plan = reconciler.reconcile(
            local: const [],
            incoming: [
              bbt(1, value: 36.50, device: 'Oura'),
              bbt(1, value: 36.504, device: 'Garmin Connect'),
            ],
          );
          expect(plan.conflicts, isEmpty);
          expect(plan.inserts.single.sourceDevice, 'Oura');
          expect(plan.skipped.single.incoming.sourceDevice, 'Garmin Connect');
          expect(plan.updates, isEmpty);
        },
      );

      test('two known devices, same day, material disagreement → one '
          'crossDeviceDisagreement conflict, no silent overwrite', () {
        final plan = reconciler.reconcile(
          local: const [],
          incoming: [
            bbt(1, value: 36.4, device: 'Oura'),
            bbt(1, value: 36.9, device: 'Garmin Connect'),
          ],
        );
        expect(plan.inserts.single.sourceDevice, 'Oura');
        expect(plan.updates, isEmpty);
        expect(
          plan.conflicts.single.reason,
          ConflictReason.crossDeviceDisagreement,
        );
        expect(plan.conflicts.single.incoming.sourceDevice, 'Garmin Connect');
      });

      test(
        'a stored device row vs a different incoming device that disagrees → '
        'crossDeviceDisagreement conflict',
        () {
          final plan = reconciler.reconcile(
            local: [local(2, value: 36.4, device: 'Oura')],
            incoming: [bbt(2, value: 36.9, device: 'Garmin Connect')],
          );
          expect(plan.updates, isEmpty);
          expect(
            plan.conflicts.single.reason,
            ConflictReason.crossDeviceDisagreement,
          );
          expect(plan.conflicts.single.local.sourceDevice, 'Oura');
        },
      );

      test('one side has an unknown device → falls through to a plain update, '
          'never a device conflict', () {
        // Legacy / unattributable local row, a newly-attributed import that
        // disagrees. Same source → the reconciler updates in place; it must not
        // manufacture a conflict the user has no basis to resolve.
        final plan = reconciler.reconcile(
          local: [local(3, value: 36.4)], // sourceDevice null
          incoming: [bbt(3, value: 36.9, device: 'Oura')],
        );
        expect(plan.conflicts, isEmpty);
        expect(plan.updates.single.localId, '2026-04-3');
      });

      test('cross-device disagreement is independent of incoming order', () {
        final a = bbt(1, value: 36.4, device: 'Oura');
        final b = bbt(1, value: 36.9, device: 'Garmin Connect');
        final forward = reconciler.reconcile(local: const [], incoming: [a, b]);
        final reverse = reconciler.reconcile(local: const [], incoming: [b, a]);
        expect(forward, equals(reverse));
        expect(forward.hashCode, reverse.hashCode);
        expect(
          forward.conflicts.single.reason,
          ConflictReason.crossDeviceDisagreement,
        );
      });

      test('single-source multi-row batch: plan is identical to the no-device '
          'run (device tags do not perturb it)', () {
        List<HealthSample> batch({String? device}) => [
          for (var d = 1; d <= 6; d++)
            bbt(
              d,
              value: 36.0 + d / 10 + (d.isEven ? 0.3 : 0.0),
              id: 'id-$d',
              device: device,
            ),
          bbt(20, value: 37.0, id: 'new', device: device),
        ];
        final localRows = [
          for (var d = 1; d <= 6; d++)
            local(d, value: 36.0 + d / 10, id: 'id-$d'),
        ];
        final withoutDevice = reconciler.reconcile(
          local: localRows,
          incoming: batch(),
        );
        final withDevice = reconciler.reconcile(
          local: [for (final r in localRows) r], // no device on stored rows
          incoming: batch(device: 'Oura'),
        );
        // Same bucket sizes and same localIds — a uniform device tag on the
        // incoming batch changes nothing structural.
        expect(
          withDevice.updates.map((u) => u.localId),
          withoutDevice.updates.map((u) => u.localId),
        );
        expect(
          withDevice.skipped.map((s) => s.localId),
          withoutDevice.skipped.map((s) => s.localId),
        );
        expect(withDevice.inserts.length, withoutDevice.inserts.length);
        expect(withDevice.conflicts, isEmpty);
      });
    });

    // ---- p8.6: multi-source precedence ------------------------------------

    group('precedence (p8.6)', () {
      HealthSample wrist(int day, {double value = 36.5, String? id}) =>
          HealthSample.point(
            type: HealthSampleType.basalBodyTemperature,
            at: DateTime(2026, 4, day, 6, 30),
            value: value,
            unit: HealthUnit.celsius,
            source: HealthDataSource.appleHealth,
            externalId: id,
            isSleepingWrist: true,
          );

      LocalSampleView localWrist(int day, {double value = 36.5}) =>
          LocalSampleView(
            localId: '2026-04-$day',
            type: HealthSampleType.basalBodyTemperature,
            day: DateTime(2026, 4, day),
            value: value,
            unit: HealthUnit.celsius,
            source: HealthDataSource.appleHealth,
            isSleepingWrist: true,
          );

      test('a manual local row is never auto-resolved by precedence — a '
          'disagreeing dedicated-device import is still a conflict', () {
        final plan = reconciler.reconcile(
          local: [local(1, value: 36.4, source: HealthDataSource.manual)],
          incoming: [bbt(1, value: 36.9, device: 'Oura')],
        );
        expect(plan.updates, isEmpty);
        expect(plan.superseded, isEmpty);
        expect(plan.conflicts.single.reason, ConflictReason.manualDisagreement);
      });

      test('manual + several automatic sources → one manual conflict, no '
          'auto-update', () {
        final plan = reconciler.reconcile(
          local: [local(2, value: 36.3, source: HealthDataSource.manual)],
          incoming: [
            bbt(2, value: 36.8, device: 'Oura'),
            bbt(2, value: 36.7, device: 'Garmin Connect'),
            wrist(2, value: 36.9),
          ],
        );
        expect(plan.updates, isEmpty);
        expect(
          plan.conflicts.every(
            (c) => c.reason == ConflictReason.manualDisagreement,
          ),
          isTrue,
        );
      });

      test('dedicated device outranks a bare platform sample → deterministic '
          'auto-update, no conflict', () {
        final plan = reconciler.reconcile(
          local: [local(3, value: 36.4)], // generic platform, no device
          incoming: [bbt(3, value: 36.9, device: 'Oura')],
        );
        expect(plan.conflicts, isEmpty);
        expect(plan.updates.single.localId, '2026-04-3');
        expect(plan.updates.single.incoming.value, 36.9);
      });

      test('a bare platform sample never overwrites a stored dedicated-device '
          'reading — it is superseded', () {
        final plan = reconciler.reconcile(
          local: [local(4, value: 36.9, device: 'Oura')],
          incoming: [bbt(4, value: 36.4)], // generic, disagrees
        );
        expect(plan.conflicts, isEmpty);
        expect(plan.updates, isEmpty);
        expect(plan.superseded.single.incoming.value, 36.4);
      });

      test('dedicated device outranks Apple-Watch wrist', () {
        final plan = reconciler.reconcile(
          local: [localWrist(5, value: 36.5)],
          incoming: [bbt(5, value: 36.9, device: 'Oura')],
        );
        expect(plan.conflicts, isEmpty);
        expect(plan.updates.single.incoming.value, 36.9);
      });

      test('Apple-Watch wrist outranks a bare platform sample', () {
        final plan = reconciler.reconcile(
          local: [local(6, value: 36.4)], // generic
          incoming: [wrist(6, value: 36.9)],
        );
        expect(plan.conflicts, isEmpty);
        expect(plan.updates.single.incoming.value, 36.9);
      });

      test('two dedicated devices at the same tier that disagree stay a '
          'user conflict (unchanged from p8.2)', () {
        final plan = reconciler.reconcile(
          local: const [],
          incoming: [
            bbt(7, value: 36.4, device: 'Oura'),
            bbt(7, value: 36.9, device: 'Garmin Connect'),
          ],
        );
        expect(plan.updates, isEmpty);
        expect(
          plan.conflicts.single.reason,
          ConflictReason.crossDeviceDisagreement,
        );
        expect(plan.conflicts.single.alsoContending, isEmpty);
      });

      test('three same-tier devices disagree → ONE conflict carrying the rest '
          'in alsoContending', () {
        final plan = reconciler.reconcile(
          local: const [],
          incoming: [
            bbt(8, value: 36.3, device: 'Oura'),
            bbt(8, value: 36.6, device: 'Garmin Connect'),
            bbt(8, value: 36.9, device: 'Withings Health Mate'),
          ],
        );
        expect(plan.conflicts, hasLength(1));
        final c = plan.conflicts.single;
        expect(c.reason, ConflictReason.crossDeviceDisagreement);
        expect(c.alsoContending, hasLength(1));
        // every disagreeing reading is represented exactly once
        final values = {
          c.local.value,
          c.incoming.value,
          ...c.alsoContending.map((s) => s.value),
        };
        expect(values, {36.3, 36.6, 36.9});
      });

      test('delete the winning source → next reconcile the runner-up wins', () {
        // Round 1: a stored generic reading, an Oura import outranks it.
        final round1 = reconciler.reconcile(
          local: [local(9, value: 36.4)],
          incoming: [bbt(9, value: 36.9, device: 'Oura')],
        );
        expect(round1.updates.single.incoming.value, 36.9);

        // The user deletes the Oura row. Only a wrist reading remains for the
        // day; on the next sync it is what wins.
        final round2 = reconciler.reconcile(
          local: const [],
          incoming: [wrist(9, value: 36.7)],
        );
        expect(round2.conflicts, isEmpty);
        expect(round2.inserts.single.value, 36.7);
      });

      test('auto-resolution is fully order-independent', () {
        final a = bbt(10, value: 36.9, device: 'Oura'); // attributed
        final b = wrist(10, value: 36.5); // wrist
        final c = bbt(10, value: 36.2); // generic
        final forward = reconciler.reconcile(
          local: const [],
          incoming: [a, b, c],
        );
        final shuffled = reconciler.reconcile(
          local: const [],
          incoming: [c, a, b],
        );
        expect(forward, equals(shuffled));
        expect(forward.hashCode, shuffled.hashCode);
        // the Oura reading is the one that ends up stored
        expect(forward.conflicts, isEmpty);
        final stored = [
          ...forward.inserts.map((s) => s.value),
          ...forward.updates.map((u) => u.incoming.value),
        ];
        expect(stored, [36.9]);
      });

      // ---- stored non-manual row + >=2 incoming (PR #87 review blocker) ----
      // The running winner must occupy the slot for the rest of the pass, so a
      // later same-day reading reconciles against it — not the original stored
      // row.

      List<double> storedValue(ReconciliationPlan p) => [
        ...p.inserts.map((s) => s.value),
        ...p.updates.map((u) => u.incoming.value),
      ];

      test(
        'stored bare-platform row + [attributed, wrist] (either order) → the '
        'attributed reading is stored; wrist and the stored row are '
        'superseded; no conflict',
        () {
          for (final order in [
            [bbt(11, value: 36.50, device: 'Oura'), wrist(11, value: 36.90)],
            [wrist(11, value: 36.20), bbt(11, value: 36.50, device: 'Oura')],
          ]) {
            final plan = reconciler.reconcile(
              local: [local(11, value: 36.40)], // genericPlatform, stored
              incoming: order,
            );
            expect(plan.conflicts, isEmpty, reason: '$order');
            expect(storedValue(plan), [36.50], reason: '$order');
            // both the wrist reading and the displaced stored row are recorded
            expect(
              plan.superseded.map((s) => s.incoming.value).toSet(),
              containsAll(<double>[36.40]),
              reason: '$order',
            );
            expect(
              plan.superseded.any((s) => s.incoming.isSleepingWrist),
              isTrue,
              reason: 'the wrist reading is superseded ($order)',
            );
          }
        },
      );

      test('stored bare-platform row + [Oura, Garmin] → exactly one '
          'crossDeviceDisagreement, no blind update', () {
        final plan = reconciler.reconcile(
          local: [local(12, value: 36.40)], // genericPlatform, stored
          incoming: [
            bbt(12, value: 36.50, device: 'Oura'),
            bbt(12, value: 36.90, device: 'Garmin Connect'),
          ],
        );
        expect(
          plan.conflicts.single.reason,
          ConflictReason.crossDeviceDisagreement,
        );
        // the day is the user's call now — nothing is auto-written
        expect(plan.updates, isEmpty);
        expect(plan.inserts, isEmpty);
        // the two devices are both represented in the conflict
        final values = {
          plan.conflicts.single.local.value,
          plan.conflicts.single.incoming.value,
          ...plan.conflicts.single.alsoContending.map((s) => s.value),
        };
        expect(values, containsAll(<double>[36.50, 36.90]));
      });

      test(
        'stored bare-platform row + [Oura, Garmin] is order-independent',
        () {
          final a = bbt(13, value: 36.50, device: 'Oura');
          final b = bbt(13, value: 36.90, device: 'Garmin Connect');
          final forward = reconciler.reconcile(
            local: [local(13, value: 36.40)],
            incoming: [a, b],
          );
          final reverse = reconciler.reconcile(
            local: [local(13, value: 36.40)],
            incoming: [b, a],
          );
          expect(forward, equals(reverse));
          expect(forward.hashCode, reverse.hashCode);
        },
      );

      test('stored bare-platform row + [wrist, Oura, Garmin] → the two devices '
          'tie for review, the wrist reading is superseded', () {
        final plan = reconciler.reconcile(
          local: [local(14, value: 36.40)],
          incoming: [
            wrist(14, value: 36.20),
            bbt(14, value: 36.55, device: 'Oura'),
            bbt(14, value: 36.95, device: 'Garmin Connect'),
          ],
        );
        expect(plan.conflicts, hasLength(1));
        expect(
          plan.conflicts.single.reason,
          ConflictReason.crossDeviceDisagreement,
        );
        expect(plan.updates, isEmpty);
        expect(plan.superseded.any((s) => s.incoming.isSleepingWrist), isTrue);
      });
    });
  });
}
