import 'dart:convert';

import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../models/schedule.dart';
import '../repositories/medicine_repository.dart';
import '../repositories/schedule_repository.dart';
import '../services/auth_service.dart';
import 'add_medicine_screen.dart';

class MedicineListScreen extends StatefulWidget {
  const MedicineListScreen({super.key});

  @override
  State<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends State<MedicineListScreen> {
  final MedicineRepository _medicineRepository = MedicineRepository();
  final ScheduleRepository _scheduleRepository = ScheduleRepository();
  final AuthService _authService = AuthService();

  List<Medicine> _medicines = [];
  List<Medicine> _filteredMedicines = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicines() async {
    setState(() => _isLoading = true);

    try {
      final user = await _authService.getCurrentUser();
      if (user == null) return;

      final medicines =
          await _medicineRepository.getMedicinesByUserId(user.id!);
      setState(() {
        _medicines = medicines;
        _filteredMedicines = medicines;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading medicines: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterMedicines(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMedicines = _medicines;
      } else {
        _filteredMedicines = _medicines
            .where((medicine) =>
                medicine.name.toLowerCase().contains(query.toLowerCase()) ||
                medicine.type.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _deleteMedicine(Medicine medicine) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Obat'),
        content: Text('Apakah Anda yakin ingin menghapus "${medicine.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _medicineRepository.deleteMedicine(medicine.id!);
        await _loadMedicines();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Obat berhasil dihapus'),
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
  }

  Future<List<Schedule>> _getSchedules(int medicineId) async {
    return await _scheduleRepository.getSchedulesByMedicineId(medicineId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Daftar Obat'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterMedicines,
              decoration: InputDecoration(
                hintText: 'Cari obat...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),

          // Medicine List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMedicines.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.medication_outlined,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'Belum ada obat tersimpan'
                                  : 'Tidak ada obat yang ditemukan',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (_searchController.text.isEmpty) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AddMedicineScreen(),
                                    ),
                                  ).then((_) => _loadMedicines());
                                },
                                icon:
                                    const Icon(Icons.add, color: Colors.white),
                                label: const Text('Tambah Obat',
                                    style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadMedicines,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _filteredMedicines.length,
                          itemBuilder: (context, index) {
                            final medicine = _filteredMedicines[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ExpansionTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      _getMedicineColor(medicine.type),
                                  backgroundImage: medicine.photo != null
                                      ? MemoryImage(
                                          base64Decode(medicine.photo!))
                                      : null,
                                  child: medicine.photo == null
                                      ? Icon(
                                          _getMedicineIcon(medicine.type),
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                title: Text(
                                  medicine.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  '${medicine.type} - ${medicine.dosage} ${medicine.unit}',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Medicine Details
                                        if (medicine.photo != null) ...[
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                            child: Image.memory(
                                              base64Decode(medicine.photo!),
                                              height: 150,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today,
                                                size: 16,
                                                color: Colors.grey.shade600),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Mulai: ${_formatDate(medicine.startDate)}',
                                              style: TextStyle(
                                                  color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                        if (medicine.endDate != null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.event_available,
                                                  size: 16,
                                                  color: Colors.grey.shade600),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Selesai: ${_formatDate(medicine.endDate!)}',
                                                style: TextStyle(
                                                    color:
                                                        Colors.grey.shade600),
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (medicine.notes != null &&
                                            medicine.notes!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.note,
                                                  size: 16,
                                                  color: Colors.grey.shade600),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  medicine.notes!,
                                                  style: TextStyle(
                                                      color:
                                                          Colors.grey.shade600),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 12),

                                        // Schedules
                                        FutureBuilder<List<Schedule>>(
                                          future: medicine.id != null
                                              ? _getSchedules(medicine.id!)
                                              : Future.value(<Schedule>[]),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasData &&
                                                snapshot.data!.isNotEmpty) {
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Jadwal:',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: snapshot.data!
                                                        .map((schedule) {
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                bottom: 4.0),
                                                        child: Row(
                                                          children: [
                                                            Chip(
                                                              label: Text(
                                                                  schedule
                                                                      .time),
                                                              backgroundColor:
                                                                  Colors.blue
                                                                      .shade50,
                                                              labelStyle: TextStyle(
                                                                  color: Colors
                                                                      .blue
                                                                      .shade700),
                                                            ),
                                                            const SizedBox(
                                                                width: 8),
                                                            if (schedule.days
                                                                .isNotEmpty)
                                                              Flexible(
                                                                child: Text(
                                                                  schedule.days
                                                                      .join(
                                                                          ', '),
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                      color: Colors
                                                                          .grey
                                                                          .shade600),
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ],
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),

                                        const SizedBox(height: 12),
                                        // Action Buttons
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        AddMedicineScreen(
                                                            medicine: medicine),
                                                  ),
                                                ).then((_) => _loadMedicines());
                                              },
                                              icon: const Icon(Icons.edit,
                                                  size: 18),
                                              label: const Text('Edit'),
                                            ),
                                            const SizedBox(width: 8),
                                            TextButton.icon(
                                              onPressed: () =>
                                                  _deleteMedicine(medicine),
                                              icon: const Icon(Icons.delete,
                                                  size: 18),
                                              label: const Text('Hapus'),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddMedicineScreen(),
            ),
          ).then((_) => _loadMedicines());
        },
        backgroundColor: Colors.blue.shade600,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Color _getMedicineColor(String type) {
    switch (type.toLowerCase()) {
      case 'tablet':
        return Colors.blue;
      case 'kapsul':
        return Colors.orange;
      case 'sirup':
        return Colors.purple;
      case 'tetes':
        return Colors.cyan;
      case 'salep':
        return Colors.green;
      case 'suntik':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getMedicineIcon(String type) {
    switch (type.toLowerCase()) {
      case 'tablet':
      case 'kapsul':
        return Icons.medication;
      case 'sirup':
        return Icons.water_drop;
      case 'tetes':
        return Icons.water;
      case 'salep':
        return Icons.healing;
      case 'suntik':
        return Icons.vaccines;
      default:
        return Icons.medication_outlined;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
