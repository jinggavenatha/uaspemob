import '../models/medicine.dart';
import '../services/database_helper.dart';
import 'package:flutter/foundation.dart';
import '../services/web_storage_helper.dart';

class MedicineRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Create medicine
  Future<int> createMedicine(Medicine medicine) async {
    if (kIsWeb) {
      try {
        // Generate unique ID for web
        final medicines = await WebStorageHelper.getMedicines();
        final newId = medicines.isEmpty
            ? 1
            : (medicines
                    .map((m) => (m['id'] as int?) ?? 0)
                    .reduce((a, b) => a > b ? a : b)) +
                1;

        final medicineWithId = medicine.copyWith(id: newId);
        await WebStorageHelper.saveMedicine(medicineWithId.toMap());

        print('Created medicine with ID: $newId');
        return newId;
      } catch (e) {
        print('Error creating medicine: $e');
        rethrow;
      }
    } else {
      return await _dbHelper.insert('medicines', medicine.toMap());
    }
  }

  // Get all medicines for user
  Future<List<Medicine>> getMedicinesByUserId(int userId) async {
    if (kIsWeb) {
      try {
        final medicines = await WebStorageHelper.getMedicines();
        return medicines
            .where((m) => (m['user_id'] as int?) == userId)
            .map((map) => Medicine.fromMap(map))
            .toList();
      } catch (e) {
        print('Error getting medicines for user $userId: $e');
        return [];
      }
    } else {
      final results = await _dbHelper.query(
        'medicines',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );
      return results.map((map) => Medicine.fromMap(map)).toList();
    }
  }

  // Get medicine by id
  Future<Medicine?> getMedicineById(int id) async {
    if (kIsWeb) {
      final medicines = await WebStorageHelper.getMedicines();
      final medMap = medicines.firstWhere(
        (m) => m['id'] == id,
        orElse: () => <String, dynamic>{},
      );
      if (medMap.isEmpty) return null;
      return Medicine.fromMap(medMap);
    } else {
      final results = await _dbHelper.query(
        'medicines',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (results.isEmpty) return null;
      return Medicine.fromMap(results.first);
    }
  }

  // Update medicine
  Future<int> updateMedicine(Medicine medicine) async {
    if (kIsWeb) {
      final medicines = await WebStorageHelper.getMedicines();
      final idx = medicines.indexWhere((m) => m['id'] == medicine.id);
      if (idx != -1) {
        medicines[idx] = medicine.toMap();
        await WebStorageHelper.saveMedicinesList(medicines);
        return 1;
      }
      return 0;
    } else {
      return await _dbHelper.update(
        'medicines',
        medicine.toMap(),
        where: 'id = ?',
        whereArgs: [medicine.id],
      );
    }
  }

  // Delete medicine
  Future<int> deleteMedicine(int id) async {
    if (kIsWeb) {
      final medicines = await WebStorageHelper.getMedicines();
      medicines.removeWhere((m) => m['id'] == id);
      await WebStorageHelper.saveMedicinesList(medicines);
      return 1;
    } else {
      return await _dbHelper.delete(
        'medicines',
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // Get active medicines (belum expired)
  Future<List<Medicine>> getActiveMedicines(int userId) async {
    if (kIsWeb) {
      final medicines = await WebStorageHelper.getMedicines();
      final now = DateTime.now();
      return medicines
          .where((m) =>
              m['user_id'] == userId &&
              (m['end_date'] == null ||
                  DateTime.parse(m['end_date']).isAfter(now)))
          .map((map) => Medicine.fromMap(map))
          .toList();
    } else {
      final now = DateTime.now().toIso8601String();
      final results = await _dbHelper.query(
        'medicines',
        where: 'user_id = ? AND (end_date IS NULL OR end_date >= ?)',
        whereArgs: [userId, now],
        orderBy: 'name ASC',
      );
      return results.map((map) => Medicine.fromMap(map)).toList();
    }
  }

  // Search medicines
  Future<List<Medicine>> searchMedicines(int userId, String query) async {
    if (kIsWeb) {
      final medicines = await WebStorageHelper.getMedicines();
      return medicines
          .where((m) =>
              m['user_id'] == userId &&
              (m['name'] as String).toLowerCase().contains(query.toLowerCase()))
          .map((map) => Medicine.fromMap(map))
          .toList();
    } else {
      final results = await _dbHelper.query(
        'medicines',
        where: 'user_id = ? AND name LIKE ?',
        whereArgs: [userId, '%$query%'],
        orderBy: 'name ASC',
      );
      return results.map((map) => Medicine.fromMap(map)).toList();
    }
  }
}
