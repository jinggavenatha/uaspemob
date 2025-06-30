import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/database_helper.dart';
import '../services/web_storage_helper.dart';

class UserRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Hash password sebelum disimpan
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Create user
  Future<int> createUser(User user) async {
    try {
      final hashedUser = user.copyWith(password: _hashPassword(user.password));
      if (kIsWeb) {
        // Untuk web, generate ID sederhana
        final users = await WebStorageHelper.getUsers();
        final newId = users.isEmpty
            ? 1
            : (users
                    .map((u) => u['id'] as int? ?? 0)
                    .reduce((a, b) => a > b ? a : b)) +
                1;
        final userWithId = hashedUser.copyWith(id: newId);
        await WebStorageHelper.saveUser(userWithId.toMap());
        print('User created successfully on web with ID: $newId');
        return newId;
      } else {
        final id = await _dbHelper.insert('users', hashedUser.toMap());
        print('User created successfully with ID: $id');
        return id;
      }
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  // Get user by email
  Future<User?> getUserByEmail(String email) async {
    try {
      if (kIsWeb) {
        final users = await WebStorageHelper.getUsers();
        final userMap = users.firstWhere(
          (u) => u['email'] == email,
          orElse: () => <String, dynamic>{},
        );
        if (userMap.isEmpty) {
          print('User not found for email: $email');
          return null;
        }
        print('User found for email: $email');
        return User.fromMap(userMap);
      } else {
        final results = await _dbHelper.query(
          'users',
          where: 'email = ?',
          whereArgs: [email],
        );
        if (results.isEmpty) {
          print('User not found for email: $email');
          return null;
        }
        print('User found for email: $email');
        return User.fromMap(results.first);
      }
    } catch (e) {
      print('Error getting user by email: $e');
      return null;
    }
  }

  // Login user
  Future<User?> login(String email, String password) async {
    try {
      print('Attempting login with email: $email');
      final hashedPassword = _hashPassword(password);

      if (kIsWeb) {
        final users = await WebStorageHelper.getUsers();
        print('Total users in storage: ${users.length}');

        // Debug: print all users for debugging
        for (var user in users) {
          print('Stored user: ${user['email']} with hash: ${user['password']}');
        }
        print('Looking for hash: $hashedPassword');

        final userMap = users.firstWhere(
          (u) => u['email'] == email && u['password'] == hashedPassword,
          orElse: () => <String, dynamic>{},
        );

        if (userMap.isEmpty) {
          print('Login failed: User not found or incorrect credentials');
          return null;
        }

        print('Login successful for user: ${userMap['name']}');
        return User.fromMap(userMap);
      } else {
        final results = await _dbHelper.query(
          'users',
          where: 'email = ? AND password = ?',
          whereArgs: [email, hashedPassword],
        );

        if (results.isEmpty) {
          print('Login failed: User not found or incorrect credentials');
          return null;
        }

        print('Login successful for user: ${results.first['name']}');
        return User.fromMap(results.first);
      }
    } catch (e) {
      print('Error during login: $e');
      return null;
    }
  }

  // Update user
  Future<int> updateUser(User user) async {
    try {
      if (kIsWeb) {
        // Update user di SharedPreferences
        final users = await WebStorageHelper.getUsers();
        final idx = users.indexWhere((u) => u['email'] == user.email);
        if (idx != -1) {
          users[idx] = user.toMap();
          await WebStorageHelper.saveUsersList(users);
          print('User updated successfully on web');
          return 1;
        }
        print('User not found for update');
        return 0;
      } else {
        final result = await _dbHelper.update(
          'users',
          user.toMap(),
          where: 'id = ?',
          whereArgs: [user.id],
        );
        print('User updated successfully with result: $result');
        return result;
      }
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  // Check if email exists
  Future<bool> emailExists(String email) async {
    try {
      if (kIsWeb) {
        final users = await WebStorageHelper.getUsers();
        final exists = users.any((u) => u['email'] == email);
        print('Email exists check for $email: $exists');
        return exists;
      } else {
        final results = await _dbHelper.query(
          'users',
          where: 'email = ?',
          whereArgs: [email],
        );
        final exists = results.isNotEmpty;
        print('Email exists check for $email: $exists');
        return exists;
      }
    } catch (e) {
      print('Error checking email existence: $e');
      return false;
    }
  }

  // Insert default user
  Future<void> insertDefaultUser() async {
    try {
      print('Checking if default user exists...');
      final emailExists = await this.emailExists('jenath@gmail.com');

      if (!emailExists) {
        print('Creating default user...');
        final defaultUser = User(
          name: 'Jingga Venatha',
          email: 'jenath@gmail.com',
          password: 'asdasd',
        );
        final id = await createUser(defaultUser);
        print('Default user created successfully with ID: $id');
      } else {
        print('Default user already exists');
      }
    } catch (e) {
      print('Error inserting default user: $e');
      rethrow;
    }
  }

  // Clear all users (for testing)
  Future<void> clearAllUsers() async {
    try {
      if (kIsWeb) {
        await WebStorageHelper.clearUsers();
        print('All users cleared from web storage');
      } else {
        await _dbHelper.delete('users');
        print('All users cleared from database');
      }
    } catch (e) {
      print('Error clearing users: $e');
      rethrow;
    }
  }
}
