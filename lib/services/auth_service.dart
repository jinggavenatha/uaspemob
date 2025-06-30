import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../repositories/user_repository.dart';

class AuthService {
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _isLoggedInKey = 'is_logged_in';

  final UserRepository _userRepository = UserRepository();

  // Initialize default user on first app launch
  Future<void> initializeApp() async {
    try {
      await _userRepository.insertDefaultUser();
      print('Default user initialized successfully');
    } catch (e) {
      print('Error initializing default user: $e');
    }
  }

  // Login
  Future<User?> login(String email, String password) async {
    try {
      print('Attempting login for email: $email');

      // Validasi input
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email dan password tidak boleh kosong');
      }

      final user = await _userRepository.login(email, password);

      if (user != null) {
        print('Login successful for user: ${user.name}');
        await _saveSession(user);
      } else {
        print('Login failed: User not found or incorrect credentials');
      }

      return user;
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  // Register
  Future<User?> register(String name, String email, String password) async {
    try {
      // Check if email already exists
      final emailExists = await _userRepository.emailExists(email);
      if (emailExists) {
        throw Exception('Email sudah terdaftar');
      }

      // Create new user
      final newUser = User(
        name: name,
        email: email,
        password: password,
      );

      final userId = await _userRepository.createUser(newUser);
      final createdUser = newUser.copyWith(id: userId);

      // Auto login after register
      await _saveSession(createdUser);

      return createdUser;
    } catch (e) {
      print('Register error: $e');
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      print('Logout error: $e');
      rethrow;
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isLoggedInKey) ?? false;
    } catch (e) {
      print('Check login status error: $e');
      return false;
    }
  }

  // Get current user from session
  Future<User?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt(_userIdKey);

      if (userId == null) return null;

      final userEmail = prefs.getString(_userEmailKey) ?? '';
      final userName = prefs.getString(_userNameKey) ?? '';

      return User(
        id: userId,
        name: userName,
        email: userEmail,
        password: '', // Password tidak disimpan di session
      );
    } catch (e) {
      print('Get current user error: $e');
      return null;
    }
  }

  // Save session
  Future<void> _saveSession(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Pastikan user.id tidak null
      if (user.id == null) {
        throw Exception('User ID cannot be null when saving session');
      }

      await prefs.setInt(_userIdKey, user.id!);
      await prefs.setString(_userEmailKey, user.email);
      await prefs.setString(_userNameKey, user.name);
      await prefs.setBool(_isLoggedInKey, true);

      print('Session saved successfully for user: ${user.name}');
    } catch (e) {
      print('Save session error: $e');
      rethrow;
    }
  }

  // Update current user session
  Future<void> updateCurrentUser(User user) async {
    try {
      await _saveSession(user);
    } catch (e) {
      print('Update current user error: $e');
      rethrow;
    }
  }
}
