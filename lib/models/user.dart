class User {
  final int? id;
  final String name;
  final String email;
  final String password;
  final String? profilePicture;
  final DateTime? createdAt;

  User({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    this.profilePicture,
    this.createdAt,
  });

  // Convert User object to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'profile_picture': profilePicture,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // Create User object from Map
  factory User.fromMap(Map<String, dynamic> map) {
    try {
      return User(
        id: map['id'] as int?,
        name: (map['name'] as String?) ?? '',
        email: (map['email'] as String?) ?? '',
        password: (map['password'] as String?) ?? '',
        profilePicture: map['profile_picture'] as String?,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'].toString())
            : null,
      );
    } catch (e) {
      print('Error creating User from map: $e');
      print('Map data: $map');
      rethrow;
    }
  }

  // Copy with method for updating user
  User copyWith({
    int? id,
    String? name,
    String? email,
    String? password,
    String? profilePicture,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      profilePicture: profilePicture ?? this.profilePicture,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'User{id: $id, name: $name, email: $email, profilePicture: $profilePicture, createdAt: $createdAt}';
  }
}
