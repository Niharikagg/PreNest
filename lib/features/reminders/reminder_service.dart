import 'dart:convert';
import 'dart:io';

class LocalReminder {
  final String id;
  final String title;
  final DateTime scheduledAt;
  final String? personId;
  final String? details;

  const LocalReminder({
    required this.id,
    required this.title,
    required this.scheduledAt,
    this.personId,
    this.details,
  });

  void validate() {
    if (id.trim().isEmpty || title.trim().isEmpty) {
      throw const FormatException('Reminder id and title are required.');
    }
    if (personId != null && personId!.trim().isEmpty) {
      throw const FormatException('Person identifier must not be blank.');
    }
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        'personId': personId,
        'details': details,
      };

  factory LocalReminder.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['title'] is! String ||
        value['scheduledAt'] is! String) {
      throw const FormatException('Reminder data is malformed.');
    }
    final reminder = LocalReminder(
      id: value['id'] as String,
      title: value['title'] as String,
      scheduledAt: DateTime.parse(value['scheduledAt'] as String),
      personId: value['personId'] as String?,
      details: value['details'] as String?,
    );
    reminder.validate();
    return reminder;
  }
}

abstract interface class ReminderStore {
  Future<List<LocalReminder>> getAll();

  Future<void> upsert(LocalReminder reminder);

  Future<bool> delete(String id);
}

class JsonReminderStore implements ReminderStore {
  final File storageFile;

  const JsonReminderStore(this.storageFile);

  @override
  Future<List<LocalReminder>> getAll() async {
    if (!await storageFile.exists()) {
      return [];
    }
    final decoded = jsonDecode(await storageFile.readAsString());
    if (decoded is! List) {
      throw const FormatException('Reminder store must contain a JSON list.');
    }
    return decoded.map(LocalReminder.fromJson).toList();
  }

  @override
  Future<void> upsert(LocalReminder reminder) async {
    reminder.validate();
    final reminders = await getAll();
    final existingIndex =
        reminders.indexWhere((item) => item.id == reminder.id);
    if (existingIndex == -1) {
      reminders.add(reminder);
    } else {
      reminders[existingIndex] = reminder;
    }
    await storageFile.parent.create(recursive: true);
    await storageFile.writeAsString(
      jsonEncode(reminders.map((item) => item.toJson()).toList()),
      flush: true,
    );
  }

  @override
  Future<bool> delete(String id) async {
    final reminders = await getAll();
    final originalLength = reminders.length;
    reminders.removeWhere((reminder) => reminder.id == id);
    if (reminders.length == originalLength) {
      return false;
    }
    await storageFile.writeAsString(
      jsonEncode(reminders.map((item) => item.toJson()).toList()),
      flush: true,
    );
    return true;
  }
}

abstract interface class LocalNotificationScheduler {
  Future<bool> requestPermission();

  Future<void> schedule(LocalReminder reminder);

  Future<void> cancel(String reminderId);
}

class ReminderActionResult {
  final LocalReminder reminder;
  final bool notificationScheduled;

  const ReminderActionResult({
    required this.reminder,
    required this.notificationScheduled,
  });
}

class ReminderService {
  final ReminderStore _store;
  final LocalNotificationScheduler _scheduler;
  final DateTime Function() _clock;
  final String Function() _idGenerator;

  ReminderService({
    required ReminderStore store,
    required LocalNotificationScheduler scheduler,
    DateTime Function()? clock,
    String Function()? idGenerator,
  })  : _store = store,
        _scheduler = scheduler,
        _clock = clock ?? DateTime.now,
        _idGenerator = idGenerator ??
            (() => DateTime.now().microsecondsSinceEpoch.toString());

  Future<List<LocalReminder>> getAll() => _store.getAll();

  Future<ReminderActionResult> create({
    required String title,
    required DateTime scheduledAt,
    String? personId,
    String? details,
  }) async {
    _validateDraft(title, scheduledAt, personId);
    final id = _idGenerator();
    if ((await _store.getAll()).any((reminder) => reminder.id == id)) {
      throw StateError('Reminder id generator returned a duplicate id.');
    }
    final reminder = LocalReminder(
      id: id,
      title: title.trim(),
      scheduledAt: scheduledAt,
      personId: personId?.trim(),
      details: details?.trim(),
    );
    reminder.validate();
    await _store.upsert(reminder);
    return ReminderActionResult(
      reminder: reminder,
      notificationScheduled: await _scheduleIfPermitted(reminder),
    );
  }

  Future<ReminderActionResult> update(LocalReminder reminder) async {
    _validateDraft(reminder.title, reminder.scheduledAt, reminder.personId);
    final existing =
        (await _store.getAll()).where((item) => item.id == reminder.id);
    if (existing.isEmpty) {
      throw StateError('Cannot update an unknown reminder.');
    }
    final updated = LocalReminder(
      id: reminder.id,
      title: reminder.title.trim(),
      scheduledAt: reminder.scheduledAt,
      personId: reminder.personId?.trim(),
      details: reminder.details?.trim(),
    );
    await _store.upsert(updated);
    await _scheduler.cancel(updated.id);
    return ReminderActionResult(
      reminder: updated,
      notificationScheduled: await _scheduleIfPermitted(updated),
    );
  }

  Future<bool> delete(String id) async {
    final exists = (await _store.getAll()).any((reminder) => reminder.id == id);
    if (!exists) {
      return false;
    }
    await _scheduler.cancel(id);
    return _store.delete(id);
  }

  void _validateDraft(String title, DateTime scheduledAt, String? personId) {
    if (title.trim().isEmpty) {
      throw const FormatException('Reminder title must not be empty.');
    }
    if (!scheduledAt.isAfter(_clock())) {
      throw ArgumentError.value(
        scheduledAt,
        'scheduledAt',
        'Reminder must be scheduled in the future.',
      );
    }
    if (personId != null && personId.trim().isEmpty) {
      throw const FormatException('Person identifier must not be blank.');
    }
  }

  Future<bool> _scheduleIfPermitted(LocalReminder reminder) async {
    if (!await _scheduler.requestPermission()) {
      return false;
    }
    await _scheduler.schedule(reminder);
    return true;
  }
}
