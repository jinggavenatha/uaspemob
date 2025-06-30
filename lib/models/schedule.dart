class Schedule {
  final int? id;
  final int medicineId;
  final String time; // Format: HH:mm
  final bool isActive;
  final DateTime? createdAt;
  final List<String>
      days; // Tambahan: hari-hari jadwal, misal: ["Senin", "Rabu"]

  Schedule({
    this.id,
    required this.medicineId,
    required this.time,
    this.isActive = true,
    this.createdAt,
    this.days = const [], // default kosong
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicine_id': medicineId,
      'time': time,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'days': days.join(','), // simpan sebagai string dipisah koma
    };
  }

  factory Schedule.fromMap(Map<String, dynamic> map) {
    return Schedule(
      id: map['id'],
      medicineId: map['medicine_id'],
      time: map['time'],
      isActive: map['is_active'] == 1,
      createdAt:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      days: map['days'] != null && map['days'].toString().isNotEmpty
          ? map['days'].toString().split(',')
          : [],
    );
  }

  Schedule copyWith({
    int? id,
    int? medicineId,
    String? time,
    bool? isActive,
    DateTime? createdAt,
    List<String>? days,
  }) {
    return Schedule(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      time: time ?? this.time,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      days: days ?? this.days,
    );
  }
}
