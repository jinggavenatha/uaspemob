import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/schedule_repository.dart';
import '../services/auth_service.dart';

class TodaysMedicinesScreen extends StatefulWidget {
  const TodaysMedicinesScreen({super.key});

  @override
  State<TodaysMedicinesScreen> createState() => _TodaysMedicinesScreenState();
}

class _TodaysMedicinesScreenState extends State<TodaysMedicinesScreen> {
  final ScheduleRepository _scheduleRepository = ScheduleRepository();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _todaysMedicines = [];
  bool _isLoading = true;

  // Group medicines by time period
  List<Map<String, dynamic>> _morningMedicines = [];
  List<Map<String, dynamic>> _afternoonMedicines = [];
  List<Map<String, dynamic>> _eveningMedicines = [];
  List<Map<String, dynamic>> _nightMedicines = [];

  @override
  void initState() {
    super.initState();
    _loadTodaysMedicines();
  }

  Future<void> _loadTodaysMedicines() async {
    setState(() => _isLoading = true);

    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        print('No current user found');
        setState(() => _isLoading = false);
        return;
      }

      print(
          'Loading today\'s medicines for user: ${user.name} (ID: ${user.id})');

      // Generate logs for today
      print('Generating logs for today...');
      await _scheduleRepository.generateTodaysLogs(user.id!);
      print('Logs generation completed');

      // Get today's medicines
      print('Fetching today\'s medicine logs...');
      final medicines =
          await _scheduleRepository.getTodaysMedicineLogs(user.id!);

      print('Loaded ${medicines.length} medicine logs for today');
      if (medicines.isNotEmpty) {
        for (final medicine in medicines) {
          print(
              'Medicine: ${medicine['medicine_name'] ?? 'NULL'} at ${medicine['schedule_time'] ?? 'NULL'} - Status: ${medicine['status'] ?? 'NULL'}');
        }
      } else {
        print('No medicines found for today - this might indicate:');
        print('1. No medicines are scheduled for today');
        print('2. No schedules are configured for existing medicines');
        print('3. Medicine start/end dates don\'t include today');
      }

      // Group by time period
      _groupMedicinesByTime(medicines);

      setState(() {
        _todaysMedicines = medicines;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading today\'s medicines: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error memuat obat hari ini: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _groupMedicinesByTime(List<Map<String, dynamic>> medicines) {
    _morningMedicines = [];
    _afternoonMedicines = [];
    _eveningMedicines = [];
    _nightMedicines = [];

    for (final medicine in medicines) {
      final timeStr = medicine['schedule_time'] as String;
      final timeParts = timeStr.split(':');
      final hour = int.parse(timeParts[0]);

      if (hour >= 5 && hour < 12) {
        _morningMedicines.add(medicine);
      } else if (hour >= 12 && hour < 15) {
        _afternoonMedicines.add(medicine);
      } else if (hour >= 15 && hour < 18) {
        _eveningMedicines.add(medicine);
      } else {
        _nightMedicines.add(medicine);
      }
    }
  }

  Future<void> _updateMedicineStatus(int logId, bool taken) async {
    try {
      await _scheduleRepository.updateMedicineLogStatus(
        logId,
        taken ? 'taken' : 'pending',
        takenAt: taken ? DateTime.now() : null,
      );

      await _loadTodaysMedicines();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(taken ? 'Obat sudah diminum' : 'Status obat direset'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Obat Hari Ini'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _todaysMedicines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 80,
                        color: Colors.green.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tidak ada jadwal obat hari ini',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nikmati hari Anda!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTodaysMedicines,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      color: Colors.blue.shade600,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                                          .format(DateTime.now()),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildSummaryItem(
                                      'Total',
                                      _todaysMedicines.length.toString(),
                                      Colors.blue,
                                    ),
                                    _buildSummaryItem(
                                      'Sudah',
                                      _todaysMedicines
                                          .where((m) => m['status'] == 'taken')
                                          .length
                                          .toString(),
                                      Colors.green,
                                    ),
                                    _buildSummaryItem(
                                      'Belum',
                                      _todaysMedicines
                                          .where(
                                              (m) => m['status'] == 'pending')
                                          .length
                                          .toString(),
                                      Colors.orange,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Time Period Sections
                        if (_morningMedicines.isNotEmpty) ...[
                          _buildTimePeriodSection(
                              'Pagi', Icons.wb_sunny, _morningMedicines),
                          const SizedBox(height: 16),
                        ],
                        if (_afternoonMedicines.isNotEmpty) ...[
                          _buildTimePeriodSection('Siang',
                              Icons.wb_sunny_outlined, _afternoonMedicines),
                          const SizedBox(height: 16),
                        ],
                        if (_eveningMedicines.isNotEmpty) ...[
                          _buildTimePeriodSection(
                              'Sore', Icons.wb_twilight, _eveningMedicines),
                          const SizedBox(height: 16),
                        ],
                        if (_nightMedicines.isNotEmpty) ...[
                          _buildTimePeriodSection(
                              'Malam', Icons.nightlight_round, _nightMedicines),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildTimePeriodSection(
      String title, IconData icon, List<Map<String, dynamic>> medicines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...medicines.map((medicine) => _buildMedicineCard(medicine)).toList(),
      ],
    );
  }

  Widget _buildMedicineCard(Map<String, dynamic> medicine) {
    final bool isTaken = medicine['status'] == 'taken';

    // Safe access to medicine data with null checking
    final String medicineName =
        medicine['medicine_name']?.toString() ?? 'Obat Tidak Diketahui';
    final String scheduleTime =
        medicine['schedule_time']?.toString() ?? '00:00';
    final String medicineDosage =
        medicine['medicine_dosage']?.toString() ?? '0';
    final String medicineUnit = medicine['medicine_unit']?.toString() ?? 'unit';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _updateMedicineStatus(medicine['id'], !isTaken),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Medicine Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicineName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: isTaken ? TextDecoration.lineThrough : null,
                        color: isTaken ? Colors.grey : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          scheduleTime,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.medication,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$medicineDosage $medicineUnit',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (isTaken && medicine['taken_at'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Diminum pada ${DateFormat('HH:mm').format(DateTime.parse(medicine['taken_at']))}',
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Status Icon
              Icon(
                isTaken ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isTaken ? Colors.green : Colors.grey.shade400,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
