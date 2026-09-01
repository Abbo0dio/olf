import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:olf_core/olf_core.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_copy.dart';
import 'reminder_scheduler.dart';

/// One Android channel per reminder kind. All `private` visibility (redacted on
/// a secure lock screen) and default importance.
typedef _Channel = ({String id, String name, String description});

_Channel _channelFor(ReminderKind kind) => switch (kind) {
  ReminderKind.medication => (
    id: 'olf_reminder_medication',
    name: 'Daily reminder',
    description: 'A daily nudge to open olf. Never contains health details.',
  ),
  ReminderKind.bbtPrompt => (
    id: 'olf_reminder_bbtPrompt',
    name: 'Morning temperature',
    description: 'A daily morning nudge. Never contains health details.',
  ),
  ReminderKind.upcomingPeriod => (
    id: 'olf_reminder_upcomingPeriod',
    name: 'Upcoming period',
    description:
        'A heads-up a couple of days before a predicted start. '
        'Text stays generic.',
  ),
  ReminderKind.fertileWindow => (
    id: 'olf_reminder_fertileWindow',
    name: 'Fertile window',
    description:
        'A note around the start of an estimated fertile window. '
        'Text stays generic.',
  ),
  ReminderKind.latePeriodCheckIn => (
    id: 'olf_reminder_latePeriodCheckIn',
    name: 'Late check-in',
    description:
        'A gentle check-in when something expected has not been logged. '
        'Text stays generic.',
  ),
};

/// Production [ReminderScheduler] over `flutter_local_notifications`.
///
/// All plugin access is confined to this file so the rest of the app — and
/// every widget test — never loads a platform channel. The timing is
/// deliberately *inexact* (a nudge does not need to hit the minute) so it needs
/// no exact-alarm permission.
class LocalNotificationReminderScheduler implements ReminderScheduler {
  LocalNotificationReminderScheduler._();

  /// The app wires this single instance; tests substitute a fake.
  static final LocalNotificationReminderScheduler instance =
      LocalNotificationReminderScheduler._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Stable notification id per kind — no collisions (p1.7 used 1001).
  int _idFor(ReminderKind kind) => switch (kind) {
    ReminderKind.medication => 1001,
    ReminderKind.upcomingPeriod => 1002,
    ReminderKind.fertileWindow => 1003,
    ReminderKind.bbtPrompt => 1004,
    ReminderKind.latePeriodCheckIn => 1005,
  };

  NotificationDetails _detailsFor(ReminderKind kind) {
    final channel = _channelFor(kind);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        // p2.4: wording is already generic, but redact it on a secure lock
        // screen anyway — the OS then shows only the app name.
        visibility: NotificationVisibility.private,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

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

    // p4.1: p1.7 registered a single 'olf_daily_reminder' channel; medication
    // now lives on 'olf_reminder_medication'. Android never removes a channel on
    // its own, so an upgraded install would keep an orphaned, empty entry in
    // system Settings — delete it here. No-op on a fresh install or non-Android.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.deleteNotificationChannel(channelId: 'olf_daily_reminder');

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

    final copy = notificationCopyFor(schedule.kind);
    await _plugin.zonedSchedule(
      id: _idFor(schedule.kind),
      title: copy.title,
      body: copy.body,
      scheduledDate: _nextInstant(schedule),
      notificationDetails: _detailsFor(schedule.kind),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> scheduleAt(ReminderKind kind, DateTime when) async {
    await ensureInitialized();
    await cancel(kind);

    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime.from(when, tz.local);
    if (!at.isAfter(now)) {
      // Late (e.g. an overdue check-in) — fire as soon as the OS allows.
      at = now.add(const Duration(minutes: 1));
    }

    final copy = notificationCopyFor(kind);
    await _plugin.zonedSchedule(
      id: _idFor(kind),
      title: copy.title,
      body: copy.body,
      scheduledDate: at,
      notificationDetails: _detailsFor(kind),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // One-shot: no matchDateTimeComponents — the sync layer re-arms it.
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
  Future<void> scheduleAt(ReminderKind kind, DateTime when) async {}

  @override
  Future<void> cancel(ReminderKind kind) async {}
}
