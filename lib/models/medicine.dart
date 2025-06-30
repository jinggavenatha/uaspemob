class Medicine {
  final int? id;
  final int userId;
  final String name;
  final String type;
  final String dosage;
  final String unit;
  final DateTime startDate;
  final DateTime? endDate;
  final String? notes;
  final DateTime? createdAt;
  final String? photo;

  Medicine({
    this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.dosage,
    required this.unit,
    required this.startDate,
    this.endDate,
    this.notes,
    this.createdAt,
    this.photo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'type': type,
      'dosage': dosage,
      'unit': unit,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'photo': photo,
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'],
      userId: map['user_id'],
      name: map['name'],
      type: map['type'],
      dosage: map['dosage'],
      unit: map['unit'],
      startDate: DateTime.parse(map['start_date']),
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
      notes: map['notes'],
      createdAt:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      photo: map['photo'],
    );
  }

  Medicine copyWith({
    int? id,
    int? userId,
    String? name,
    String? type,
    String? dosage,
    String? unit,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    DateTime? createdAt,
    String? photo,
  }) {
    return Medicine(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      dosage: dosage ?? this.dosage,
      unit: unit ?? this.unit,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      photo: photo ?? this.photo,
    );
  }
}
