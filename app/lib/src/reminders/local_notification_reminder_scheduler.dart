import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:olf_core/olf_core.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_scheduler.dart';

/// Production [ReminderScheduler] over `flutter_local_notifications`.
///
/// All plugin access is confined to this file so the rest of the app — and
/// every widget test — never loads a platform channel. p1.7 schedules a single
/// daily notification; the timing is deliberately *inexact* (a check-in nudge
/// does not need to hit the minute) so it needs no exact-alarm permission.
class LocalNotificationReminderScheduler implements ReminderScheduler {
  LocalNotificationReminderScheduler._();

  /// The app wires this single instance; tests substitute a fake.
  static final LocalNotificationReminderScheduler instance =
      LocalNotificationReminderScheduler._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const String _channelId = 'olf_daily_reminder';
  static const String _channelName = 'Daily reminder';
  static const String _channelDescription =
      'A single daily nudge to open olf. Never contains health details.';

  /// Stable notification id per kind — Phase 4 widens this.
  int _idFor(ReminderKind kind) => switch (kind) {
    ReminderKind.medication => 1001,
  };

  /// Idempotent one-time init: timezone database, local zone, plugin.
  /// Safe to call from app start-up and before every operation.
  Future<void> ensureInitialized() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {
      // Keep the UTC default rather than crash — a reminder that is off by a
      // timezone offset still beats no reminder and no app.
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    _ready = true;
  }

  @override
  Future<bool> ensurePermission() async {
    await ensureInitialized();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? true;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  @override
  Future<void> scheduleDaily(ReminderSchedule schedule) async {
    await ensureInitialized();
    await cancel(schedule.kind);
    if (!schedule.enabled) return;

    await _plugin.zonedSchedule(
      id: _idFor(schedule.kind),
      title: reminderNotificationTitle,
      body: reminderNotificationBody,
      scheduledDate: _nextInstant(schedule),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancel(ReminderKind kind) async {
    await ensureInitialized();
    await _plugin.cancel(id: _idFor(kind));
  }

  /// The next wall-clock occurrence of [schedule]'s time in the local zone.
  tz.TZDateTime _nextInstant(ReminderSchedule schedule) {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      schedule.hour,
      schedule.minute,
    );
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }
    return when;
  }
}

/// A no-op [ReminderScheduler] for platforms/tests where the plugin is absent.
/// Used as the app fallback if plugin init throws at start-up.
@visibleForTesting
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<bool> ensurePermission() async => false;

  @override
  Future<void> scheduleDaily(ReminderSchedule schedule) async {}

  @override
  Future<void> cancel(ReminderKind kind) async {}
}
