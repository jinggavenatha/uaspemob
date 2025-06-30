import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WebStorageHelper {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Users
  static Future<void> saveUser(Map<String, dynamic> user) async {
    final users = await getUsers();
    users.add(user);
    await _prefs.setString('users', jsonEncode(users));
  }

  static Future<List<Map<String, dynamic>>> getUsers() async {
    final usersString = _prefs.getString('users');
    if (usersString == null) return [];
    final List<dynamic> usersList = jsonDecode(usersString);
    return usersList.cast<Map<String, dynamic>>();
  }

  static Future<void> saveUsersList(List<Map<String, dynamic>> users) async {
    await _prefs.setString('users', jsonEncode(users));
  }

  static Future<void> clearUsers() async {
    await _prefs.remove('users');
  }

  // Medicines
  static Future<void> saveMedicine(Map<String, dynamic> medicine) async {
    final medicines = await getMedicines();
    medicines.add(medicine);
    await _prefs.setString('medicines', jsonEncode(medicines));
  }

  static Future<List<Map<String, dynamic>>> getMedicines() async {
    final medicinesString = _prefs.getString('medicines');
    if (medicinesString == null) return [];
    final List<dynamic> medicinesList = jsonDecode(medicinesString);
    return medicinesList.cast<Map<String, dynamic>>();
  }

  static Future<void> saveMedicinesList(
      List<Map<String, dynamic>> medicines) async {
    await _prefs.setString('medicines', jsonEncode(medicines));
  }

  // Schedules
  static Future<void> saveSchedule(Map<String, dynamic> schedule) async {
    final schedules = await getSchedules();
    schedules.removeWhere((s) => s['id'] == schedule['id']);
    schedules.add(schedule);
    await _prefs.setString('schedules', jsonEncode(schedules));
  }

  static Future<List<Map<String, dynamic>>> getSchedules() async {
    final schedulesString = _prefs.getString('schedules');
    if (schedulesString == null) return [];
    final List<dynamic> schedulesList = jsonDecode(schedulesString);
    return schedulesList.cast<Map<String, dynamic>>();
  }

  static Future<void> saveSchedulesList(
      List<Map<String, dynamic>> schedules) async {
    await _prefs.setString('schedules', jsonEncode(schedules));
  }

  // Medicine Logs
  static Future<void> saveMedicineLog(Map<String, dynamic> log) async {
    final logs = await getMedicineLogs();
    logs.add(log);
    await _prefs.setString('medicine_logs', jsonEncode(logs));
  }

  static Future<List<Map<String, dynamic>>> getMedicineLogs() async {
    final logsString = _prefs.getString('medicine_logs');
    if (logsString == null) return [];
    final List<dynamic> logsList = jsonDecode(logsString);
    return logsList.cast<Map<String, dynamic>>();
  }

  static Future<void> saveMedicineLogsList(
      List<Map<String, dynamic>> logs) async {
    await _prefs.setString('medicine_logs', jsonEncode(logs));
  }

  // Clear all data
  static Future<void> clearAll() async {
    await _prefs.clear();
  }
}
