import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:form_field_validator/form_field_validator.dart';
import '../models/medicine.dart';
import '../models/schedule.dart';
import '../repositories/medicine_repository.dart';
import '../repositories/schedule_repository.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AddMedicineScreen extends StatefulWidget {
  final Medicine? medicine;

  const AddMedicineScreen({super.key, this.medicine});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();

  final MedicineRepository _medicineRepository = MedicineRepository();
  final ScheduleRepository _scheduleRepository = ScheduleRepository();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  String _selectedType = 'Tablet';
  String _selectedUnit = 'mg';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  List<TimeOfDay> _scheduleTimes = [TimeOfDay.now()];
  List<List<String>> _scheduleDays = [
    ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"]
  ];
  bool _isLoading = false;
  String? _imageBase64;
  final ImagePicker _picker = ImagePicker();

  final List<String> _medicineTypes = [
    'Tablet',
    'Kapsul',
    'Sirup',
    'Tetes',
    'Salep',
    'Suntik'
  ];
  final List<String> _dosageUnits = [
    'mg',
    'ml',
    'tetes',
    'sendok',
    'tablet',
    'kapsul'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.medicine != null) {
      _loadMedicineData();
    }
  }

  Future<void> _loadMedicineData() async {
    final medicine = widget.medicine!;
    _nameController.text = medicine.name;
    _dosageController.text = medicine.dosage;
    _notesController.text = medicine.notes ?? '';
    _selectedType = medicine.type;
    _selectedUnit = medicine.unit;
    _startDate = medicine.startDate;
    _endDate = medicine.endDate;
    _imageBase64 = medicine.photo;

    // Load existing schedules for this medicine
    try {
      final schedules =
          await _scheduleRepository.getSchedulesByMedicineId(medicine.id!);

      print(
          'Loading ${schedules.length} existing schedules for medicine ${medicine.name}');

      if (schedules.isNotEmpty) {
        // Clear default schedule and load existing ones
        _scheduleTimes.clear();
        _scheduleDays.clear();

        for (final schedule in schedules) {
          // Parse time string to TimeOfDay
          final timeParts = schedule.time.split(':');
          final hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);

          _scheduleTimes.add(TimeOfDay(hour: hour, minute: minute));
          _scheduleDays.add(List<String>.from(schedule.days));

          print('Loaded schedule: ${schedule.time} on days: ${schedule.days}');
        }

        // Update UI
        setState(() {});

        print('Successfully loaded ${_scheduleTimes.length} schedules');
      } else {
        print('No existing schedules found, keeping default schedule');
      }
    } catch (e) {
      print('Error loading schedules: $e');
      // Keep default schedule if error occurs
    }

    // Ensure we always have at least one schedule
    if (_scheduleTimes.isEmpty) {
      _scheduleTimes.add(TimeOfDay.now());
      _scheduleDays.add(
          ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"]);
      print('Added default schedule as fallback');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : (_endDate ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _scheduleTimes[index],
    );

    if (picked != null) {
      setState(() {
        _scheduleTimes[index] = picked;
      });
    }
  }

  void _addScheduleTime() {
    setState(() {
      _scheduleTimes.add(TimeOfDay.now());
      _scheduleDays.add(
          ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"]);
    });
  }

  void _removeScheduleTime(int index) {
    if (_scheduleTimes.length > 1) {
      setState(() {
        _scheduleTimes.removeAt(index);
        _scheduleDays.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimal harus ada satu jadwal minum obat'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<String?> _compressImage(Uint8List imageBytes) async {
    try {
      if (imageBytes.length < 400 * 1024) {
        return base64Encode(imageBytes);
      }

      String base64Str = base64Encode(imageBytes);
      if (base64Str.length > 1000000) {
        base64Str = base64Str.substring(0, 1000000);
      }
      return base64Str;
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 80,
      );
      if (image != null) {
        print(kIsWeb
            ? 'Image dipilih pada platform Web'
            : 'Image dipilih pada platform Mobile/Desktop');
        final bytes = await image.readAsBytes();

        // Untuk web dan mobile kita simpan sebagai base64 (ukuran sudah dikompres)
        final compressed = await _compressImage(bytes);
        if (compressed != null) {
          setState(() {
            _imageBase64 = compressed;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gagal mengompres gambar'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Sumber Gambar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate required fields
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama obat wajib diisi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_dosageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dosis obat wajib diisi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate schedules
    if (_scheduleTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimal harus ada satu jadwal minum obat'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate that each schedule has at least one day selected
    for (int i = 0; i < _scheduleDays.length; i++) {
      if (_scheduleDays[i].isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Jadwal ke-${i + 1} harus memiliki minimal satu hari'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final user = await _authService.getCurrentUser();
      if (user == null) throw Exception('User not logged in');

      // Create or update medicine
      final medicine = Medicine(
        id: widget.medicine?.id,
        userId: user.id!,
        name: _nameController.text.trim(),
        type: _selectedType,
        dosage: _dosageController.text.trim(),
        unit: _selectedUnit,
        startDate: _startDate,
        endDate: _endDate,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        photo: _imageBase64,
      );

      int medicineId;
      if (widget.medicine == null) {
        medicineId = await _medicineRepository.createMedicine(medicine);
      } else {
        await _medicineRepository.updateMedicine(medicine);
        medicineId = widget.medicine!.id!;
        // Delete existing schedules
        await _scheduleRepository.deleteSchedulesByMedicineId(medicineId);
      }

      // Create schedules
      for (int i = 0; i < _scheduleTimes.length; i++) {
        final time = _scheduleTimes[i];
        final days = _scheduleDays[i];

        if (days.isNotEmpty) {
          // Additional safety check
          final schedule = Schedule(
            medicineId: medicineId,
            time:
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
            days: days,
          );
          await _scheduleRepository.createSchedule(schedule);
        }
      }

      // Setup notifications for this medicine
      try {
        await _notificationService.setupNotificationsForMedicine(medicineId);
        print('Notifications setup for medicine ID: $medicineId');
      } catch (e) {
        print('Error setting up notifications: $e');
        // Don't fail the whole operation if notification setup fails
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.medicine == null
                ? 'Obat berhasil ditambahkan dan notifikasi diatur'
                : 'Obat berhasil diperbarui dan notifikasi diatur ulang'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving medicine: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(widget.medicine == null ? 'Tambah Obat' : 'Edit Obat'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Medicine Name
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informasi Obat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Photo
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _showImageSourceDialog,
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: _imageBase64 != null
                                    ? MemoryImage(base64Decode(_imageBase64!))
                                    : null,
                                child: _imageBase64 == null
                                    ? const Icon(Icons.camera_alt,
                                        color: Colors.grey, size: 40)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _showImageSourceDialog,
                              child: const Text('Tambah/Ubah Foto'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Nama Obat',
                          hintText: 'Contoh: Paracetamol',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: RequiredValidator(
                                errorText: 'Nama obat wajib diisi')
                            .call,
                      ),
                      const SizedBox(height: 16),
                      // Medicine Type
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: InputDecoration(
                          labelText: 'Jenis Obat',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: _medicineTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      // Dosage
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _dosageController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Dosis',
                                hintText: 'Contoh: 500',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: RequiredValidator(
                                      errorText: 'Dosis wajib diisi')
                                  .call,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedUnit,
                              decoration: InputDecoration(
                                labelText: 'Satuan',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items: _dosageUnits.map((unit) {
                                return DropdownMenuItem(
                                  value: unit,
                                  child: Text(unit),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedUnit = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Notes
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Catatan (Opsional)',
                          hintText: 'Contoh: Diminum setelah makan',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Date Range
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Periode Konsumsi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Start Date
                      ListTile(
                        title: const Text('Tanggal Mulai'),
                        subtitle:
                            Text(DateFormat('dd MMMM yyyy').format(_startDate)),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () => _selectDate(context, true),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // End Date
                      ListTile(
                        title: const Text('Tanggal Selesai (Opsional)'),
                        subtitle: Text(_endDate != null
                            ? DateFormat('dd MMMM yyyy').format(_endDate!)
                            : 'Tidak ada batas waktu'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () => _selectDate(context, false),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Schedule Times
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Jadwal Minum Obat',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: _addScheduleTime,
                            icon: const Icon(Icons.add_circle,
                                color: Colors.blue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _scheduleTimes.length,
                        itemBuilder: (context, index) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Jadwal ke-${index + 1}'),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle,
                                        color: Colors.red),
                                    onPressed: () => _removeScheduleTime(index),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text('Jam: '),
                                  TextButton(
                                    onPressed: () =>
                                        _selectTime(context, index),
                                    child: Text(
                                        _scheduleTimes[index].format(context)),
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final day in [
                                    "Senin",
                                    "Selasa",
                                    "Rabu",
                                    "Kamis",
                                    "Jumat",
                                    "Sabtu",
                                    "Minggu"
                                  ])
                                    FilterChip(
                                      label: Text(day),
                                      selected:
                                          _scheduleDays[index].contains(day),
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            _scheduleDays[index].add(day);
                                          } else {
                                            _scheduleDays[index].remove(day);
                                          }
                                        });
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveMedicine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          widget.medicine == null ? 'Simpan' : 'Update',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
