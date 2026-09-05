import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/health/conflict_review_page.dart';
import 'package:olf_app/src/health/health_providers.dart';
import 'package:olf_app/src/health/sync_status_page.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

/// p6.4 sync-status surface: connected state, when the last sync ran, what it
/// brought in, how many differences still need review, and the redaction the
/// screen reader gets under "Reduce spoken detail".
void main() {
  ReconciliationConflict conflict(int d) => ReconciliationConflict(
    localId: '2026-05-$d',
    local: LocalSampleView(
      localId: '2026-05-$d',
      type: HealthSampleType.basalBodyTemperature,
      day: DateTime(2026, 5, d),
      value: 36.5,
      unit: HealthUnit.celsius,
      source: HealthDataSource.manual,
    ),
    incoming: HealthSample.point(
      type: HealthSampleType.basalBodyTemperature,
      at: DateTime(2026, 5, d),
      value: 36.9,
      unit: HealthUnit.celsius,
      source: HealthDataSource.appleHealth,
    ),
    reason: ConflictReason.manualDisagreement,
  );

  Future<AppDatabase> seed({
    bool connected = true,
    String? lastSync = '2,1,0',
    DateTime? lastSyncAt,
    bool reduceSpokenDetail = false,
  }) async {
    final db = memoryDb();
    final settings = DriftSettingsRepository(db);
    if (connected) {
      await settings.set(SettingKeys.appleHealthConnected, 'true');
    }
    if (lastSync != null) {
      await settings.set(SettingKeys.appleHealthLastSync, lastSync);
    }
    if (lastSyncAt != null) {
      await settings.set(
        SettingKeys.appleHealthLastSyncAt,
        lastSyncAt.toIso8601String(),
      );
    }
    if (reduceSpokenDetail) {
      await settings.set(SettingKeys.reduceSpokenDetail, 'true');
    }
    return db;
  }

  /// Mounts the status page, runs [body] against it, then unmounts and flushes
  /// drift's stream-close timer before the binding's end-of-test invariant
  /// check (an `addTearDown` runs too late for that check).
  Future<void> withStatus(
    WidgetTester tester, {
    required AppDatabase db,
    List<ReconciliationConflict> conflicts = const [],
    required Future<void> Function() body,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbOverride(db),
          healthPlatformGatewayProvider.overrideWithValue(
            FakeHealthPlatformGateway(),
          ),
          healthConflictsProvider.overrideWith((ref) => conflicts),
        ],
        child: const MaterialApp(home: HealthSyncStatusPage()),
      ),
    );
    await tester.pumpAndSettle();
    await body();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('never synced — shows "Not synced yet"', (tester) async {
    final db = await seed(lastSync: null);
    addTearDown(db.close);
    await withStatus(
      tester,
      db: db,
      body: () async {
        expect(find.text('Not synced yet'), findsOneWidget);
        expect(find.text('Nothing yet'), findsOneWidget);
      },
    );
  });

  testWidgets('last-synced shows a relative time', (tester) async {
    final db = await seed(
      lastSyncAt: DateTime.now().subtract(const Duration(hours: 3)),
    );
    addTearDown(db.close);
    await withStatus(
      tester,
      db: db,
      body: () async {
        expect(find.text('3 hours ago'), findsOneWidget);
        expect(find.text('Added 2, updated 1'), findsOneWidget);
      },
    );
  });

  testWidgets('no conflicts — the review row is a dead end', (tester) async {
    final db = await seed();
    addTearDown(db.close);
    await withStatus(
      tester,
      db: db,
      body: () async {
        expect(find.text('No differences to resolve'), findsOneWidget);
        await tester.tap(find.text('Needs review'));
        await tester.pumpAndSettle();
        expect(find.byType(ConflictReviewPage), findsNothing);
      },
    );
  });

  testWidgets('N need review — the row counts them and opens the review '
      'screen', (tester) async {
    final db = await seed();
    addTearDown(db.close);
    await withStatus(
      tester,
      db: db,
      conflicts: [conflict(10), conflict(11)],
      body: () async {
        expect(
          find.text('2 differences between olf and Health Connect'),
          findsOneWidget,
        );
        await tester.tap(find.text('Needs review'));
        await tester.pumpAndSettle();
        expect(find.byType(ConflictReviewPage), findsOneWidget);
      },
    );
  });

  testWidgets('reduce spoken detail redacts the counts on the status surface', (
    tester,
  ) async {
    final db = await seed(
      reduceSpokenDetail: true,
      lastSyncAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );
    addTearDown(db.close);
    await withStatus(
      tester,
      db: db,
      conflicts: [conflict(10), conflict(11)],
      body: () async {
        final broughtIn = find.text('Added 2, updated 1');
        expect(
          tester.widget<Text>(broughtIn).semanticsLabel,
          'Last sync complete',
        );

        final review = find.text(
          '2 differences between olf and Health Connect',
        );
        expect(
          tester.widget<Text>(review).semanticsLabel,
          '2 entries need review',
        );
      },
    );
  });
}
