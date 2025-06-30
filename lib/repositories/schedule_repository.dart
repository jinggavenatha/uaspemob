import '../models/schedule.dart';
import '../models/medicine_log.dart';
import '../services/database_helper.dart';
import 'package:flutter/foundation.dart';
import '../services/web_storage_helper.dart';

class ScheduleRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Create schedule
  Future<int> createSchedule(Schedule schedule) async {
    if (kIsWeb) {
      try {
        // Generate unique ID for web
        final schedules = await WebStorageHelper.getSchedules();
        final newId = schedules.isEmpty
            ? 1
            : (schedules
                    .map((s) => (s['id'] as int?) ?? 0)
                    .reduce((a, b) => a > b ? a : b)) +
                1;

        final scheduleWithId = schedule.copyWith(id: newId);
        await WebStorageHelper.saveSchedule(scheduleWithId.toMap());

        print('Created schedule with ID: $newId');
        return newId;
      } catch (e) {
        print('Error creating schedule: $e');
        rethrow;
      }
    } else {
      return await _dbHelper.insert('schedules', schedule.toMap());
    }
  }

  // Get schedules by medicine id
  Future<List<Schedule>> getSchedulesByMedicineId(int medicineId) async {
    if (kIsWeb) {
      try {
        final schedules = await WebStorageHelper.getSchedules();
        return schedules
            .where((s) => (s['medicine_id'] as int?) == medicineId)
            .map((map) => Schedule.fromMap(map))
            .toList();
      } catch (e) {
        print('Error getting schedules for medicine $medicineId: $e');
        return [];
      }
    } else {
      final results = await _dbHelper.query(
        'schedules',
        where: 'medicine_id = ?',
        whereArgs: [medicineId],
        orderBy: 'time ASC',
      );
      return results.map((map) => Schedule.fromMap(map)).toList();
    }
  }

  // Update schedule
  Future<int> updateSchedule(Schedule schedule) async {
    if (kIsWeb) {
      await WebStorageHelper.saveSchedule(schedule.toMap());
      return 1;
    } else {
      return await _dbHelper.update(
        'schedules',
        schedule.toMap(),
        where: 'id = ?',
        whereArgs: [schedule.id],
      );
    }
  }

  // Delete schedule
  Future<int> deleteSchedule(int id) async {
    if (kIsWeb) {
      final schedules = await WebStorageHelper.getSchedules();
      schedules.removeWhere((s) => s['id'] == id);
      await WebStorageHelper.saveSchedulesList(schedules);
      return 1;
    } else {
      return await _dbHelper.delete(
        'schedules',
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // Delete all schedules for a medicine
  Future<int> deleteSchedulesByMedicineId(int medicineId) async {
    if (kIsWeb) {
      final schedules = await WebStorageHelper.getSchedules();
      schedules.removeWhere((s) => s['medicine_id'] == medicineId);
      await WebStorageHelper.saveSchedulesList(schedules);
      return 1;
    } else {
      return await _dbHelper.delete(
        'schedules',
        where: 'medicine_id = ?',
        whereArgs: [medicineId],
      );
    }
  }

  // Create medicine log
  Future<int> createMedicineLog(MedicineLog log) async {
    if (kIsWeb) {
      try {
        // Generate unique ID jika belum ada
        final logs = await WebStorageHelper.getMedicineLogs();
        final newId = log.id ??
            (logs.isEmpty
                ? 1
                : (logs
                        .map((l) => l['id'] as int? ?? 0)
                        .reduce((a, b) => a > b ? a : b)) +
                    1);

        final logWithId = log.copyWith(id: newId);
        await WebStorageHelper.saveMedicineLog(logWithId.toMap());

        print('Created medicine log with ID: $newId');
        return newId;
      } catch (e) {
        print('Error creating medicine log: $e');
        rethrow;
      }
    } else {
      return await _dbHelper.insert('medicine_logs', log.toMap());
    }
  }

  // Get today's medicine logs
  Future<List<Map<String, dynamic>>> getTodaysMedicineLogs(int userId) async {
    final today = DateTime.now();
    final todayStr =
        "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    if (kIsWeb) {
      try {
        print('Getting today\'s medicine logs for user $userId on $todayStr');

        // Get all data
        final logs = await WebStorageHelper.getMedicineLogs();
        final medicines = await WebStorageHelper.getMedicines();
        final schedules = await WebStorageHelper.getSchedules();

        // Filter logs for today and this user
        final todaysLogs = logs
            .where((log) =>
                (log['user_id'] as int?) == userId &&
                log['scheduled_date'] == todayStr)
            .toList();

        print('Found ${todaysLogs.length} logs for today');

        // Join with medicine and schedule data
        final result = <Map<String, dynamic>>[];

        for (final log in todaysLogs) {
          final medicineId = log['medicine_id'] as int?;
          final scheduleId = log['schedule_id'] as int?;

          if (medicineId == null || scheduleId == null) {
            print('Skipping log with null medicineId or scheduleId');
            continue;
          }

          // Find medicine
          final medicine = medicines.firstWhere(
            (m) => (m['id'] as int?) == medicineId,
            orElse: () => <String, dynamic>{},
          );

          // Find schedule
          final schedule = schedules.firstWhere(
            (s) => (s['id'] as int?) == scheduleId,
            orElse: () => <String, dynamic>{},
          );

          if (medicine.isNotEmpty && schedule.isNotEmpty) {
            result.add({
              ...log,
              'medicine_name': medicine['name'],
              'medicine_type': medicine['type'],
              'medicine_dosage': medicine['dosage'],
              'medicine_unit': medicine['unit'],
              'schedule_time': schedule['time'],
            });
          }
        }

        // Sort by schedule time
        result.sort((a, b) {
          final timeA = a['schedule_time'] as String;
          final timeB = b['schedule_time'] as String;
          return timeA.compareTo(timeB);
        });

        print('Returning ${result.length} medicine logs for today');
        return result;
      } catch (e) {
        print('Error getting today\'s medicine logs for web: $e');
        return [];
      }
    } else {
      final startOfDay =
          DateTime(today.year, today.month, today.day).toIso8601String();
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59)
          .toIso8601String();

      final query = '''
        SELECT 
          ml.*,
          m.name as medicine_name,
          m.type as medicine_type,
          m.dosage as medicine_dosage,
          m.unit as medicine_unit,
          s.time as schedule_time
        FROM medicine_logs ml
        JOIN medicines m ON ml.medicine_id = m.id
        JOIN schedules s ON ml.schedule_id = s.id
        WHERE ml.user_id = ? 
          AND ml.scheduled_date >= ? 
          AND ml.scheduled_date <= ?
        ORDER BY s.time ASC
      ''';

      return await _dbHelper.rawQuery(query, [userId, startOfDay, endOfDay]);
    }
  }

  // Update medicine log status
  Future<int> updateMedicineLogStatus(int logId, String status,
      {DateTime? takenAt}) async {
    if (kIsWeb) {
      try {
        final logs = await WebStorageHelper.getMedicineLogs();
        final idx = logs.indexWhere((l) => (l['id'] as int?) == logId);
        if (idx != -1) {
          logs[idx]['status'] = status;
          if (takenAt != null)
            logs[idx]['taken_at'] = takenAt.toIso8601String();
          await WebStorageHelper.saveMedicineLogsList(logs);
          print('Updated medicine log $logId status to $status');
          return 1;
        }
        print('Medicine log $logId not found for update');
        return 0;
      } catch (e) {
        print('Error updating medicine log status: $e');
        rethrow;
      }
    } else {
      final data = {
        'status': status,
        if (takenAt != null) 'taken_at': takenAt.toIso8601String(),
      };
      return await _dbHelper.update(
        'medicine_logs',
        data,
        where: 'id = ?',
        whereArgs: [logId],
      );
    }
  }

  // Generate logs for today
  Future<void> generateTodaysLogs(int userId) async {
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final todayStr =
        "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    // Map Indonesian day names to match schedule format - FIX: weekday dimulai dari 1 (Monday)
    final dayNames = [
      'Senin', // 1
      'Selasa', // 2
      'Rabu', // 3
      'Kamis', // 4
      'Jumat', // 5
      'Sabtu', // 6
      'Minggu' // 7
    ];

    // FIX: weekday dimulai dari 1 (Monday), jadi kita perlu adjust
    final todayDay = dayNames[today.weekday - 1];

    print('=== DEBUGGING TODAYS LOGS ===');
    print('Generating logs for user $userId on $todayStr ($todayDay)');
    print('Today weekday: ${today.weekday}');
    print('Mapped day: $todayDay');

    if (kIsWeb) {
      try {
        // Get all medicines for user
        final medicines = await WebStorageHelper.getMedicines();
        final userMedicines = medicines.where((m) => m['user_id'] == userId);

        print('Found ${userMedicines.length} medicines for user');

        // Debug: print all medicines
        for (final med in userMedicines) {
          print(
              'Medicine: ${med['name']} (ID: ${med['id']}) - Start: ${med['start_date']}, End: ${med['end_date']}');
        }

        // Get all schedules
        final schedules = await WebStorageHelper.getSchedules();
        print('Total schedules in storage: ${schedules.length}');

        // Get existing logs for today
        final existingLogs = await WebStorageHelper.getMedicineLogs();
        final todaysExistingLogs = existingLogs.where((log) {
          return log['user_id'] == userId && log['scheduled_date'] == todayStr;
        }).toList();
        print('Existing logs for today: ${todaysExistingLogs.length}');

        for (final medicine in userMedicines) {
          // Safe casting with null checking
          final medicineId = medicine['id'] as int?;
          if (medicineId == null) {
            print('Skipping medicine with null ID: ${medicine['name']}');
            continue;
          }

          final startDateStr = medicine['start_date'] as String?;
          if (startDateStr == null) {
            print(
                'Skipping medicine with null start_date: ${medicine['name']}');
            continue;
          }

          final startDate = DateTime.parse(startDateStr);
          final startDateOnly =
              DateTime(startDate.year, startDate.month, startDate.day);

          final endDate = medicine['end_date'] != null
              ? DateTime.parse(medicine['end_date'] as String)
              : null;
          final endDateOnly = endDate != null
              ? DateTime(endDate.year, endDate.month, endDate.day)
              : null;

          print('Checking medicine ${medicine['name']}:');
          print(
              '  Start date: $startDate (Date only for check: $startDateOnly)');
          print('  End date: $endDate (Date only for check: $endDateOnly)');
          print('  Today: $todayDateOnly');

          // FIX: Compare date part only
          if (startDateOnly.isAfter(todayDateOnly)) {
            print('  SKIPPED: Start date is after today');
            continue;
          }

          if (endDateOnly != null && endDateOnly.isBefore(todayDateOnly)) {
            print('  SKIPPED: End date is before today');
            continue;
          }

          print('  ACTIVE: Medicine is active today');

          // Get schedules for this medicine
          print('  Looking for schedules with medicine_id: $medicineId');

          // Debug: print all schedules to see the data
          for (final s in schedules) {
            print(
                '    Schedule: id=${s['id']}, medicine_id=${s['medicine_id']}, time=${s['time']}, active=${s['is_active']}');
          }

          final medicineSchedules = schedules.where((s) {
            final schedMedicineId = s['medicine_id'] as int?;
            final isActive = s['is_active'] as int? ?? 1;
            final matches = schedMedicineId == medicineId && isActive == 1;
            print(
                '    Schedule ${s['id']}: medicine_id=$schedMedicineId, matches=$matches');
            return matches;
          });

          print(
              '  Found ${medicineSchedules.length} schedules for this medicine');

          for (final schedule in medicineSchedules) {
            final scheduleId = schedule['id'] as int?;
            if (scheduleId == null) {
              print('    Skipping schedule with null ID');
              continue;
            }

            final scheduleTime = schedule['time'] as String?;
            final daysStr = schedule['days'] as String?;

            print(
                '    Schedule ID: $scheduleId, Time: $scheduleTime, Days: $daysStr');

            // Check if today is in the schedule days
            bool shouldInclude = true;
            if (daysStr != null && daysStr.isNotEmpty) {
              print('    Raw days string: "$daysStr"');

              // Handle multiple formats
              List<String> days = [];

              // Always try comma-separated first since that's the most common format
              if (daysStr.contains(',')) {
                // Handle comma-separated format: "Senin,Selasa,Rabu,..."
                days = daysStr.split(',').map((e) => e.trim()).toList();
              } else if (daysStr.startsWith('[') && daysStr.endsWith(']')) {
                // Handle List format like [Senin, Selasa, ...]
                final cleanStr = daysStr.substring(1, daysStr.length - 1);
                days = cleanStr.split(',').map((e) => e.trim()).toList();
              } else if (daysStr.contains(' ')) {
                // Handle space-separated format
                days = daysStr
                    .trim()
                    .split(' ')
                    .where((d) => d.isNotEmpty)
                    .toList();
              } else {
                // Single day
                days = [daysStr.trim()];
              }

              // Clean up days - remove extra spaces and common prefixes
              days = days
                  .map((day) {
                    return day
                        .trim()
                        .replaceAll(RegExp(r'^[,\s]*'), '')
                        .replaceAll(RegExp(r'[,\s]*$'), '');
                  })
                  .where((day) => day.isNotEmpty)
                  .toList();

              print('    Parsed days: $days');
              print('    Looking for: "$todayDay"');

              // Check if today matches any of the days (simple exact match)
              shouldInclude = false;
              for (String day in days) {
                final cleanDay = day.trim();
                print('    Comparing "$cleanDay" with "$todayDay"');
                if (cleanDay == todayDay) {
                  shouldInclude = true;
                  print('    ✓ EXACT MATCH found!');
                  break;
                }
              }

              print('    Final result - Should include: $shouldInclude');
            } else {
              print('    No specific days set, including by default');
            }

            if (!shouldInclude) {
              print('    SKIPPED: Today not in schedule days');
              continue;
            }

            // Check if log already exists
            final existingLog = existingLogs.any((log) {
              final logUserId = log['user_id'] as int?;
              final logMedicineId = log['medicine_id'] as int?;
              final logScheduleId = log['schedule_id'] as int?;
              final logDate = log['scheduled_date'] as String?;

              return logUserId == userId &&
                  logMedicineId == medicineId &&
                  logScheduleId == scheduleId &&
                  logDate == todayStr;
            });

            if (!existingLog) {
              // Generate unique ID for web
              final logs = await WebStorageHelper.getMedicineLogs();
              final newId = logs.isEmpty
                  ? 1
                  : (logs
                          .map((l) => l['id'] as int? ?? 0)
                          .reduce((a, b) => a > b ? a : b)) +
                      1;

              final newLog = MedicineLog(
                id: newId,
                userId: userId,
                medicineId: medicineId,
                scheduleId: scheduleId,
                scheduledDate: todayDateOnly,
                status: 'pending',
              );

              // Convert to map and fix the scheduled_date format for web
              final logMap = newLog.toMap();
              logMap['scheduled_date'] =
                  todayStr; // Use simple date format for web

              print('    About to save log: $logMap');
              await WebStorageHelper.saveMedicineLog(logMap);

              // Verify log was saved
              final savedLogs = await WebStorageHelper.getMedicineLogs();
              final todayLogs = savedLogs
                  .where((log) => log['scheduled_date'] == todayStr)
                  .toList();
              print(
                  '    After save - Total logs for today: ${todayLogs.length}');

              print(
                  '    ✅ CREATED: Log for medicine ${medicine['name']} at $scheduleTime');
            } else {
              print('    EXISTS: Log already exists for this schedule');
            }
          }
        }

        print('=== FINISHED GENERATING LOGS ===');
      } catch (e) {
        print('Error generating today\'s logs for web: $e');
        print('Stack trace: ${StackTrace.current}');
        rethrow;
      }
    } else {
      final query = '''
        SELECT 
          m.id as medicine_id,
          m.user_id,
          s.id as schedule_id,
          s.time,
          s.days
        FROM medicines m
        JOIN schedules s ON m.id = s.medicine_id
        WHERE m.user_id = ? 
          AND s.is_active = 1
          AND (m.end_date IS NULL OR date(m.end_date) >= date(?))
          AND date(m.start_date) <= date(?)
      ''';

      final results = await _dbHelper.rawQuery(
        query,
        [userId, todayStr, todayStr],
      );

      // Filter hanya jadwal yang hari-nya cocok
      final filteredResults = results.where((row) {
        final daysStr = row['days'] as String?;
        if (daysStr == null || daysStr.isEmpty)
          return true; // fallback: semua hari

        // Handle both comma-separated and List format
        List<String> days;
        if (daysStr.startsWith('[') && daysStr.endsWith(']')) {
          final cleanStr = daysStr.substring(1, daysStr.length - 1);
          days = cleanStr.split(',').map((e) => e.trim()).toList();
        } else {
          days = daysStr.split(',').map((e) => e.trim()).toList();
        }

        return days.contains(todayDay);
      }).toList();

      // Check existing logs untuk hari ini
      for (final result in filteredResults) {
        final existingLogs = await _dbHelper.query(
          'medicine_logs',
          where:
              'user_id = ? AND medicine_id = ? AND schedule_id = ? AND DATE(scheduled_date) = DATE(?)',
          whereArgs: [
            userId,
            result['medicine_id'],
            result['schedule_id'],
            todayStr,
          ],
        );

        // Jika belum ada log, buat log baru
        if (existingLogs.isEmpty) {
          final log = MedicineLog(
            userId: userId,
            medicineId: result['medicine_id'] as int,
            scheduleId: result['schedule_id'] as int,
            scheduledDate: todayDateOnly,
            status: 'pending',
          );
          await createMedicineLog(log);
        }
      }
    }
  }
}
