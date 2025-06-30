class MedicineLog {
  final int? id;
  final int userId;
  final int medicineId;
  final int scheduleId;
  final DateTime? takenAt;
  final String status; // 'pending', 'taken', 'skipped'
  final DateTime scheduledDate;
  final String? notes;
  final DateTime? createdAt;

  MedicineLog({
    this.id,
    required this.userId,
    required this.medicineId,
    required this.scheduleId,
    this.takenAt,
    this.status = 'pending',
    required this.scheduledDate,
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'medicine_id': medicineId,
      'schedule_id': scheduleId,
      'taken_at': takenAt?.toIso8601String(),
      'status': status,
      'scheduled_date': scheduledDate.toIso8601String(),
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory MedicineLog.fromMap(Map<String, dynamic> map) {
    return MedicineLog(
      id: map['id'],
      userId: map['user_id'],
      medicineId: map['medicine_id'],
      scheduleId: map['schedule_id'],
      takenAt: map['taken_at'] != null ? DateTime.parse(map['taken_at']) : null,
      status: map['status'] ?? 'pending',
      scheduledDate: DateTime.parse(map['scheduled_date']),
      notes: map['notes'],
      createdAt:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  MedicineLog copyWith({
    int? id,
    int? userId,
    int? medicineId,
    int? scheduleId,
    DateTime? takenAt,
    String? status,
    DateTime? scheduledDate,
    String? notes,
    DateTime? createdAt,
  }) {
    return MedicineLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      medicineId: medicineId ?? this.medicineId,
      scheduleId: scheduleId ?? this.scheduleId,
      takenAt: takenAt ?? this.takenAt,
      status: status ?? this.status,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
