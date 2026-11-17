import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../lib/features/reminders/reminder_service.dart';

class FakeReminderScheduler implements LocalNotificationScheduler {
  bool permissionGranted;
  final List<LocalReminder> scheduled = [];
  final List<String> cancelled = [];
  int permissionRequests = 0;

  FakeReminderScheduler({this.permissionGranted = true});

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> schedule(LocalReminder reminder) async {
    scheduled.add(reminder);
  }

  @override
  Future<void> cancel(String reminderId) async {
    cancelled.add(reminderId);
  }
}

void main() {
  late Directory temporaryDirectory;
  late File storageFile;
  final now = DateTime.utc(2026, 1, 1);

  setUp(() async {
    temporaryDirectory =
        await Directory.systemTemp.createTemp('prenest_reminders_');
    storageFile = File('${temporaryDirectory.path}\\reminders.json');
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  group('ReminderService', () {
    test('creates, lists, edits, persists, and deletes reminders', () async {
      final scheduler = FakeReminderScheduler();
      final service = ReminderService(
        store: JsonReminderStore(storageFile),
        scheduler: scheduler,
        clock: () => now,
        idGenerator: () => 'reminder-1',
      );

      final created = await service.create(
        title: 'Visit',
        scheduledAt: now.add(const Duration(days: 1)),
        personId: 'P1',
      );
      expect(created.notificationScheduled, isTrue);
      expect((await service.getAll()).single.title, 'Visit');

      final editedReminder = LocalReminder(
        id: created.reminder.id,
        title: 'Updated visit',
        scheduledAt: now.add(const Duration(days: 2)),
        personId: 'P1',
      );
      final updated = await service.update(editedReminder);
      expect(updated.notificationScheduled, isTrue);
      expect((await service.getAll()).single.title, 'Updated visit');
      expect(scheduler.cancelled, ['reminder-1']);

      final reloaded = JsonReminderStore(storageFile);
      expect((await reloaded.getAll()).single.title, 'Updated visit');
      expect(await service.delete('reminder-1'), isTrue);
      expect(await service.getAll(), isEmpty);
      expect(await service.delete('unknown'), isFalse);
    });

    test('stores reminders when notification permission is denied', () async {
      final scheduler = FakeReminderScheduler(permissionGranted: false);
      final service = ReminderService(
        store: JsonReminderStore(storageFile),
        scheduler: scheduler,
        clock: () => now,
        idGenerator: () => 'reminder-2',
      );

      final result = await service.create(
        title: 'Visit',
        scheduledAt: now.add(const Duration(hours: 2)),
      );

      expect(result.notificationScheduled, isFalse);
      expect(await service.getAll(), hasLength(1));
      expect(scheduler.scheduled, isEmpty);
    });

    test('rejects blank titles and reminders that are not in the future',
        () async {
      final service = ReminderService(
        store: JsonReminderStore(storageFile),
        scheduler: FakeReminderScheduler(),
        clock: () => now,
      );

      await expectLater(
        service.create(
          title: ' ',
          scheduledAt: now.add(const Duration(days: 1)),
        ),
        throwsFormatException,
      );
      await expectLater(
        service.create(title: 'Visit', scheduledAt: now),
        throwsArgumentError,
      );
      expect(await service.getAll(), isEmpty);
    });
  });
}
