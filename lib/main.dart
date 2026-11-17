import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'database_helper.dart';
import 'halaman_laporan.dart';
import 'models/laporan.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: HalamanInput()),
  );
}

const kategoriFasilitas = [
  'Penerangan',
  'Jalan',
  'Drainase',
  'Sampah',
  'Lalu Lintas',
];

String formatTanggal(DateTime tanggal) {
  return '${tanggal.year}-'
      '${tanggal.month.toString().padLeft(2, '0')}-'
      '${tanggal.day.toString().padLeft(2, '0')}';
}

class HalamanInput extends StatefulWidget {
  const HalamanInput({super.key});

  @override
  State<HalamanInput> createState() => _HalamanInputState();
}

class _HalamanInputState extends State<HalamanInput> {
  final formKey = GlobalKey<FormState>();
  final judul = TextEditingController();
  final lokasi = TextEditingController();

  String? kategori;
  int? urgensi;
  DateTime? tanggal;
  bool menyimpan = false;

  Future<void> pilihTanggal() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: tanggal ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (hasil != null && mounted) {
      setState(() => tanggal = hasil);
    }
  }

  Future<void> simpan() async {
    if (!formKey.currentState!.validate()) return;

    if (tanggal == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pilih tanggal kejadian')));
      return;
    }

    setState(() => menyimpan = true);

    try {
      await DatabaseHelper.instance.tambah(
        Laporan(
          judul: judul.text.trim(),
          kategori: kategori!,
          lokasi: lokasi.text.trim(),
          urgensi: urgensi!,
          tanggal: formatTanggal(tanggal!),
        ),
      );

      if (!mounted) return;

      formKey.currentState!.reset();
      judul.clear();
      lokasi.clear();

      setState(() {
        kategori = null;
        urgensi = null;
        tanggal = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Laporan berhasil dikirim')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    } finally {
      if (mounted) {
        setState(() => menyimpan = false);
      }
    }
  }

  @override
  void dispose() {
    judul.dispose();
    lokasi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart City - Pelaporan Publik'),
        backgroundColor: const Color.fromARGB(255, 72, 126, 235),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Form Laporan Fasilitas Kota',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: judul,
                  decoration: const InputDecoration(
                    labelText: 'Judul Masalah',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 5) {
                      return 'Judul minimal 5 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: kategori,
                  decoration: const InputDecoration(
                    labelText: 'Kategori Fasilitas',
                    border: OutlineInputBorder(),
                  ),
                  items: kategoriFasilitas.map((item) {
                    return DropdownMenuItem(value: item, child: Text(item));
                  }).toList(),
                  onChanged: (value) {
                    setState(() => kategori = value);
                  },
                  validator: (value) {
                    return value == null ? 'Pilih kategori' : null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: lokasi,
                  decoration: const InputDecoration(
                    labelText: 'Lokasi / Kecamatan',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lokasi wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<int>(
                  initialValue: urgensi,
                  decoration: const InputDecoration(
                    labelText: 'Tingkat Urgensi',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Normal')),
                    DropdownMenuItem(value: 2, child: Text('Mendesak')),
                    DropdownMenuItem(value: 3, child: Text('Darurat')),
                  ],
                  onChanged: (value) {
                    setState(() => urgensi = value);
                  },
                  validator: (value) {
                    return value == null ? 'Pilih urgensi' : null;
                  },
                ),
                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: pilihTanggal,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    tanggal == null
                        ? 'Pilih Tanggal Kejadian'
                        : formatTanggal(tanggal!),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: menyimpan ? null : simpan,
                  child: Text(menyimpan ? 'Menyimpan...' : 'Kirim Laporan'),
                ),
                const SizedBox(height: 10),

                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HalamanLaporan()),
                    );
                  },
                  child: const Text('Pantau Laporan Kota'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
