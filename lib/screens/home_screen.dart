import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../repositories/medicine_repository.dart';
import '../repositories/schedule_repository.dart';
import '../models/user.dart';
import '../models/medicine.dart';
import 'add_medicine_screen.dart';
import 'medicine_list_screen.dart';
import 'todays_medicines_screen.dart';
import 'login_screen.dart';
import 'notification_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final MedicineRepository _medicineRepository = MedicineRepository();
  final ScheduleRepository _scheduleRepository = ScheduleRepository();
  final NotificationService _notificationService = NotificationService();

  User? _currentUser;
  List<Medicine> _medicines = [];
  List<Map<String, dynamic>> _todaysMedicines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadData();
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.init();
  }


  Future<void> _loadData() async {
    try {
      // Get current user
      final user = await _authService.getCurrentUser();
      if (user == null) {
          _navigateToLogin();
        return;
      }


      // Generate today's logs
      await _scheduleRepository.generateTodaysLogs(user.id!);

      // Get medicines and today's schedule
      final medicines =
          await _medicineRepository.getMedicinesByUserId(user.id!);
      final todaysMedicines =
          await _scheduleRepository.getTodaysMedicineLogs(user.id!);

      setState(() {
        _currentUser = user;
        _medicines = medicines;
        _todaysMedicines = todaysMedicines;
        _isLoading = false;
      });

      // Setup notifications for user after loading data
      try {
        await _notificationService.setupNotificationsForUser(user.id!);
      } catch (e) {
        // Handle error silently or show user-friendly message if needed
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Error loading data: ${e.toString()}');
      }
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  int get _takenMedicines =>
      _todaysMedicines.where((m) => m['status'] == 'taken').length;
  int get _pendingMedicines =>
      _todaysMedicines.where((m) => m['status'] == 'pending').length;


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selamat ${_getGreeting()},',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          _currentUser?.name ?? 'User',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () async {
                        await _authService.logout();
                        _navigateToLogin();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Today's Date Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.white,
                        size: 40,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hari ini',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                                .format(DateTime.now()),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),


                // Statistics Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Obat',
                        _medicines.length.toString(),
                        Icons.medication,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Sudah Minum',
                        _takenMedicines.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Belum',
                        _pendingMedicines.toString(),
                        Icons.pending,
                        Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Quick Actions
                const Text(
                  'Menu Cepat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _buildMenuCard(
                      'Obat Hari Ini',
                      Icons.today,
                      Colors.blue,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TodaysMedicinesScreen(),
                        ),
                      ).then((_) => _loadData()),
                    ),
                    _buildMenuCard(
                      'Daftar Obat',
                      Icons.list_alt,
                      Colors.purple,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MedicineListScreen(),
                        ),
                      ).then((_) => _loadData()),
                    ),
                    _buildMenuCard(
                      'Tambah Obat',
                      Icons.add_circle,
                      Colors.green,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddMedicineScreen(),
                        ),
                      ).then((_) => _loadData()),
                    ),
                    _buildMenuCard(
                      'Pengaturan Notifikasi',
                      Icons.notifications_active,
                      Colors.orange,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const NotificationSettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Today's Medicine Preview
                if (_todaysMedicines.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Jadwal Hari Ini',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TodaysMedicinesScreen(),
                          ),
                        ).then((_) => _loadData()),
                        child: const Text('Lihat Semua'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._todaysMedicines.take(3).map((medicine) {
                    // Safe access to medicine data with null checking
                    final String medicineName =
                        medicine['medicine_name']?.toString() ??
                            'Obat Tidak Diketahui';
                    final String scheduleTime =
                        medicine['schedule_time']?.toString() ?? '00:00';
                    final String medicineDosage =
                        medicine['medicine_dosage']?.toString() ?? '0';
                    final String medicineUnit =
                        medicine['medicine_unit']?.toString() ?? 'unit';
                    final String status =
                        medicine['status']?.toString() ?? 'pending';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              status == 'taken' ? Colors.green : Colors.orange,
                          child: Icon(
                            status == 'taken' ? Icons.check : Icons.access_time,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(medicineName),
                        subtitle: Text(
                          '$scheduleTime - $medicineDosage $medicineUnit',
                        ),
                        trailing: status == 'taken'
                            ? const Text(
                                'Sudah',
                                style: TextStyle(color: Colors.green),
                              )
                            : const Text(
                                'Belum',
                                style: TextStyle(color: Colors.orange),
                              ),
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Pagi';
    } else if (hour < 15) {
      return 'Siang';
    } else if (hour < 18) {
      return 'Sore';
    } else {
      return 'Malam';
    }
  }

}
