import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import '../repositories/medicine_repository.dart';
import '../repositories/schedule_repository.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  String webNotificationPermission = 'disabled';
  bool _isInitialized = false;

  // Initialize notification service
  Future<bool> init() async {
    if (kIsWeb) {
      // Web platform - simplified version
      webNotificationPermission = 'disabled';
      print('Notification service disabled for web');
      return true;
    }

    try {
      // Initialize timezone
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Combined initialization settings
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      // Initialize the plugin
      final bool? initialized = await _flutterLocalNotificationsPlugin
          .initialize(initializationSettings,
              onDidReceiveNotificationResponse: _onNotificationTapped);

      _isInitialized = initialized ?? false;

      // Request permissions
      await _requestPermissions();

      print('Notification service initialized: $_isInitialized');
      return _isInitialized;
    } catch (e) {
      print('Error initializing notification service: $e');
      return false;
    }
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // Handle notification tap here - navigate to specific screen if needed
  }

  // Request notification permissions
  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Android 13+ requires explicit permission request
      final notificationStatus = await Permission.notification.request();
      
      // Android 12+ requires exact alarm permission for precise scheduling
      final exactAlarmStatus = await Permission.scheduleExactAlarm.request();
      
      print('Notification permission: $notificationStatus');
      print('Exact alarm permission: $exactAlarmStatus');
      
      return notificationStatus.isGranted && exactAlarmStatus.isGranted;
    } else if (Platform.isIOS) {
      final bool? result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    }
    return true;
  }

  // Show immediate notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized || kIsWeb) {
      print('Notification (disabled): $title - $body');
      return;
    }

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'medicine_reminder_channel',
      'Medicine Reminder',
      channelDescription: 'Notifications for medicine reminders',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Medicine Reminder',
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Schedule notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_isInitialized || kIsWeb) {
      print('Scheduled notification (disabled): $title at $scheduledDate');
      return;
    }

    final tz.TZDateTime tzScheduledDate =
        tz.TZDateTime.from(scheduledDate, tz.local);

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'medicine_reminder_channel',
      'Medicine Reminder',
      channelDescription: 'Notifications for medicine reminders',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Medicine Reminder',
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      notificationDetails,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Cancel notification
  Future<void> cancelNotification(int id) async {
    if (!_isInitialized || kIsWeb) {
      print('Cancel notification (disabled): $id');
      return;
    }

    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    if (!_isInitialized || kIsWeb) {
      print('Cancel all notifications (disabled)');
      return;
    }

    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  // Show medicine reminder
  Future<void> showMedicineReminder({
    required String medicineName,
    required String dosage,
    required String time,
    String? notes,
  }) async {
    await showNotification(
      title: '⏰ Waktu Minum Obat!',
      body: '$medicineName ($dosage) - $time${notes != null ? '\n$notes' : ''}',
      payload: 'medicine_reminder:$medicineName',
    );
  }

  // Schedule daily medicine reminder
  Future<void> scheduleDailyMedicineReminder({
    required int id,
    required String medicineName,
    required String dosage,
    required int hour,
    required int minute,
    String? notes,
  }) async {
    if (!_isInitialized || kIsWeb) {
      print(
          'Daily medicine reminder (disabled): $medicineName at $hour:$minute');
      return;
    }

    // Calculate next occurrence
    final now = DateTime.now();
    DateTime scheduledDate =
        DateTime(now.year, now.month, now.day, hour, minute);

    // If the time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await scheduleNotification(
      id: id,
      title: '⏰ Waktu Minum Obat!',
      body: '$medicineName ($dosage)${notes != null ? '\n$notes' : ''}',
      scheduledDate: scheduledDate,
      payload: 'medicine_reminder:$medicineName',
    );
  }

  // Schedule recurring daily notifications
  Future<void> scheduleRecurringDailyNotification({
    required int baseId,
    required String medicineName,
    required String dosage,
    required int hour,
    required int minute,
    required int daysAhead,
    String? notes,
  }) async {
    if (!_isInitialized || kIsWeb) return;

    final now = DateTime.now();

    for (int i = 0; i < daysAhead; i++) {
      final scheduleDate =
          DateTime(now.year, now.month, now.day + i, hour, minute);

      // Skip if the time has already passed today (only for today)
      if (i == 0 && scheduleDate.isBefore(now)) {
        continue;
      }

      await scheduleNotification(
        id: baseId + i,
        title: '⏰ Waktu Minum Obat!',
        body: '$medicineName ($dosage)${notes != null ? '\n$notes' : ''}',
        scheduledDate: scheduleDate,
        payload: 'medicine_reminder:$medicineName',
      );
    }
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      final notificationStatus = await Permission.notification.status;
      final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
      return notificationStatus.isGranted && exactAlarmStatus.isGranted;
    } else if (Platform.isIOS) {
      final bool? result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions();
      return result ?? false;
    }
    return _isInitialized;
  }

  // Get notification permission status
  Future<String> getNotificationPermissionStatus() async {
    if (kIsWeb) return 'disabled';

    if (Platform.isAndroid) {
      final notificationStatus = await Permission.notification.status;
      final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
      
      if (notificationStatus.isGranted && exactAlarmStatus.isGranted) {
        return 'granted (notification + exact alarm)';
      } else if (notificationStatus.isGranted) {
        return 'notification granted, exact alarm: ${exactAlarmStatus.toString()}';
      } else {
        return 'notification: ${notificationStatus.toString()}, exact alarm: ${exactAlarmStatus.toString()}';
      }
    } else if (Platform.isIOS) {
      final enabled = await areNotificationsEnabled();
      return enabled ? 'granted' : 'denied';
    }
    return _isInitialized ? 'granted' : 'disabled';
  }

  // Get pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_isInitialized || kIsWeb) return [];

    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  // Schedule notifications for a medicine based on its schedules
  Future<void> scheduleMedicineNotifications({
    required int medicineId,
    required String medicineName,
    required String dosage,
    required List<String> times, // Format: ["08:00", "20:00"]
    required int durationDays,
    String? notes,
  }) async {
    if (!_isInitialized || kIsWeb) return;

    // Cancel existing notifications for this medicine
    await cancelMedicineNotifications(medicineId);

    final now = DateTime.now();

    for (int dayOffset = 0; dayOffset < durationDays; dayOffset++) {
      for (int timeIndex = 0; timeIndex < times.length; timeIndex++) {
        final timeParts = times[timeIndex].split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);

        final scheduleDate = DateTime(
          now.year,
          now.month,
          now.day + dayOffset,
          hour,
          minute,
        );

        // Skip if the time has already passed today (only for today)
        if (dayOffset == 0 && scheduleDate.isBefore(now)) {
          continue;
        }

        // Create unique ID: medicineId * 10000 + dayOffset * 100 + timeIndex
        final notificationId = medicineId * 10000 + dayOffset * 100 + timeIndex;

        await scheduleNotification(
          id: notificationId,
          title: '⏰ Waktu Minum Obat!',
          body:
              '$medicineName ($dosage)\n${times[timeIndex]}${notes != null ? '\n$notes' : ''}',
          scheduledDate: scheduleDate,
          payload: 'medicine_reminder:$medicineId:$timeIndex',
        );
      }
    }

    print(
        'Scheduled ${times.length * durationDays} notifications for $medicineName');
  }

  // Cancel all notifications for a specific medicine
  Future<void> cancelMedicineNotifications(int medicineId) async {
    if (!_isInitialized || kIsWeb) return;

    // Cancel notifications with IDs in the range for this medicine
    // ID pattern: medicineId * 10000 + dayOffset * 100 + timeIndex
    for (int dayOffset = 0; dayOffset < 365; dayOffset++) {
      // Max 1 year
      for (int timeIndex = 0; timeIndex < 10; timeIndex++) {
        // Max 10 times per day
        final notificationId = medicineId * 10000 + dayOffset * 100 + timeIndex;
        await cancelNotification(notificationId);
      }
    }

    print('Cancelled notifications for medicine ID: $medicineId');
  }

  // Test notification (untuk testing)
  Future<void> showTestNotification() async {
    await showNotification(
      title: '🧪 Test Notifikasi',
      body: 'Notifikasi berfungsi dengan baik!',
      payload: 'test_notification',
    );
  }

  // Schedule test notification in 5 seconds
  Future<void> scheduleTestNotification() async {
    final testTime = DateTime.now().add(const Duration(seconds: 5));

    await scheduleNotification(
      id: 99999,
      title: '🧪 Test Jadwal Notifikasi',
      body: 'Notifikasi terjadwal berfungsi dengan baik!',
      scheduledDate: testTime,
      payload: 'test_scheduled_notification',
    );

    print('Test notification scheduled for: $testTime');
  }

  // Setup notifications for all active medicines for a user
  Future<void> setupNotificationsForUser(int userId) async {
    if (!_isInitialized || kIsWeb) {
      print('Notifications not available for this platform');
      return;
    }

    try {
      final medicineRepo = MedicineRepository();
      final scheduleRepo = ScheduleRepository();

      // Get all active medicines for the user
      final medicines = await medicineRepo.getActiveMedicines(userId);

      print('Setting up notifications for ${medicines.length} medicines');

      for (final medicine in medicines) {
        if (medicine.id == null) continue;

        // Get schedules for this medicine
        final schedules =
            await scheduleRepo.getSchedulesByMedicineId(medicine.id!);

        if (schedules.isEmpty) continue;

        // Calculate duration from start date to end date (or 7 days if no end date)
        final startDate = medicine.startDate;
        final endDate =
            medicine.endDate ?? startDate.add(const Duration(days: 7));
        final durationDays = endDate.difference(startDate).inDays + 1;

        // Extract times from schedules
        final times = schedules
            .where((schedule) => schedule.isActive)
            .map((schedule) => schedule.time)
            .toList();

        if (times.isNotEmpty) {
          await scheduleMedicineNotifications(
            medicineId: medicine.id!,
            medicineName: medicine.name,
            dosage: '${medicine.dosage} ${medicine.unit}',
            times: times,
            durationDays: durationDays > 365 ? 365 : durationDays, // Max 1 year
            notes: medicine.notes,
          );
        }
      }

      print('Notifications setup completed for user $userId');
    } catch (e) {
      print('Error setting up notifications: $e');
    }
  }

  // Setup notifications for a specific medicine
  Future<void> setupNotificationsForMedicine(int medicineId) async {
    if (!_isInitialized || kIsWeb) return;

    try {
      final medicineRepo = MedicineRepository();
      final scheduleRepo = ScheduleRepository();

      // Get medicine details
      final medicine = await medicineRepo.getMedicineById(medicineId);
      if (medicine == null) return;

      // Get schedules for this medicine
      final schedules = await scheduleRepo.getSchedulesByMedicineId(medicineId);

      if (schedules.isEmpty) return;

      // Calculate duration
      final startDate = medicine.startDate;
      final endDate =
          medicine.endDate ?? startDate.add(const Duration(days: 7));
      final durationDays = endDate.difference(startDate).inDays + 1;

      // Extract times from schedules
      final times = schedules
          .where((schedule) => schedule.isActive)
          .map((schedule) => schedule.time)
          .toList();

      if (times.isNotEmpty) {
        await scheduleMedicineNotifications(
          medicineId: medicineId,
          medicineName: medicine.name,
          dosage: '${medicine.dosage} ${medicine.unit}',
          times: times,
          durationDays: durationDays > 365 ? 365 : durationDays,
          notes: medicine.notes,
        );
      }

      print('Notifications setup for medicine: ${medicine.name}');
    } catch (e) {
      print('Error setting up notifications for medicine $medicineId: $e');
    }
  }

  // Cancel and reschedule notifications for a medicine (useful when medicine is updated)
  Future<void> rescheduleNotificationsForMedicine(int medicineId) async {
    await cancelMedicineNotifications(medicineId);
    await setupNotificationsForMedicine(medicineId);
  }

  // Get notification summary for debugging
  Future<Map<String, dynamic>> getNotificationSummary() async {
    if (!_isInitialized || kIsWeb) {
      return {
        'platform': 'web',
        'status': 'disabled',
        'pending_count': 0,
        'permissions': 'disabled',
      };
    }

    final pending = await getPendingNotifications();
    final permissionStatus = await getNotificationPermissionStatus();
    final enabled = await areNotificationsEnabled();

    return {
      'platform': Platform.isAndroid ? 'android' : 'ios',
      'status': enabled ? 'enabled' : 'disabled',
      'pending_count': pending.length,
      'permissions': permissionStatus,
      'pending_notifications': pending
          .map((p) => {
                'id': p.id,
                'title': p.title,
                'body': p.body,
                'payload': p.payload,
              })
          .toList(),
    };
  }
}
