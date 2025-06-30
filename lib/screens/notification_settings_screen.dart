import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  Map<String, dynamic> _notificationSummary = {};
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      final user = await _authService.getCurrentUser();
      final summary = await _notificationService.getNotificationSummary();

      setState(() {
        _currentUser = user;
        _notificationSummary = summary;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notification settings: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _testNotification() async {
    try {
      await _notificationService.showTestNotification();
      _showSnackBar('Test notifikasi telah dikirim!', Colors.green);
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _testScheduledNotification() async {
    try {
      await _notificationService.scheduleTestNotification();
      _showSnackBar('Test notifikasi terjadwal dalam 5 detik!', Colors.blue);

      // Refresh summary after scheduling
      await Future.delayed(const Duration(seconds: 1));
      await _loadData();
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _setupAllNotifications() async {
    if (_currentUser?.id == null) {
      _showSnackBar('User tidak ditemukan', Colors.red);
      return;
    }

    try {
      setState(() => _isLoading = true);

      await _notificationService.setupNotificationsForUser(_currentUser!.id!);
      _showSnackBar(
          'Notifikasi berhasil diatur untuk semua obat!', Colors.green);

      // Refresh summary
      await _loadData();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _clearAllNotifications() async {
    try {
      await _notificationService.cancelAllNotifications();
      _showSnackBar('Semua notifikasi telah dibatalkan!', Colors.orange);

      // Refresh summary
      await _loadData();
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Notifikasi'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Status Notifikasi',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildStatusRow('Platform',
                              _notificationSummary['platform'] ?? 'unknown'),
                          _buildStatusRow('Status',
                              _notificationSummary['status'] ?? 'unknown'),
                          _buildStatusRow('Izin',
                              _notificationSummary['permissions'] ?? 'unknown'),
                          _buildStatusRow('Notifikasi Tertunda',
                              '${_notificationSummary['pending_count'] ?? 0}'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Test Buttons
                  const Text(
                    'Test Notifikasi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _testNotification,
                      icon: const Icon(Icons.notifications),
                      label: const Text('Test Notifikasi Sekarang'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _testScheduledNotification,
                      icon: const Icon(Icons.schedule),
                      label: const Text('Test Notifikasi Terjadwal (5 detik)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Medicine Notifications
                  const Text(
                    'Notifikasi Obat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _setupAllNotifications,
                      icon: const Icon(Icons.medication),
                      label: const Text('Atur Notifikasi Semua Obat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _clearAllNotifications,
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Batalkan Semua Notifikasi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Pending Notifications List
                  if (_notificationSummary['pending_notifications'] != null &&
                      (_notificationSummary['pending_notifications'] as List)
                          .isNotEmpty) ...[
                    const Text(
                      'Notifikasi Tertunda',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount:
                            (_notificationSummary['pending_notifications']
                                    as List)
                                .length,
                        itemBuilder: (context, index) {
                          final notification =
                              (_notificationSummary['pending_notifications']
                                  as List)[index];
                          return ListTile(
                            leading: const Icon(Icons.notifications_outlined),
                            title: Text(notification['title'] ?? 'No Title'),
                            subtitle: Text(notification['body'] ?? 'No Body'),
                            trailing: Text('ID: ${notification['id']}'),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Refresh Button
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Status'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    Color valueColor = Colors.black;
    if (label == 'Status') {
      valueColor = value == 'enabled' ? Colors.green : Colors.red;
    } else if (label == 'Izin') {
      valueColor = value.contains('granted') ? Colors.green : Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
