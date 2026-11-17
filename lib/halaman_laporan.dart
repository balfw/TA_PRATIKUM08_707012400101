
import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'models/laporan.dart';

class HalamanLaporan extends StatefulWidget {
  const HalamanLaporan({super.key});

  @override
  State<HalamanLaporan> createState() => _HalamanLaporanState();
}

class _HalamanLaporanState extends State<HalamanLaporan> {
  final db = DatabaseHelper.instance;
  final cari = TextEditingController();

  String filter = 'Semua';
  List<Laporan> laporan = [];
  Map<String, int> statistik = {'total': 0, 'aktif': 0, 'selesai': 0};
  bool loading = true;

  final kategoriList = [
    'Penerangan', 'Jalan', 'Drainase', 'Sampah', 'Lalu Lintas'
  ];

  @override
  void initState() {
    super.initState();
    muatData();
    cari.addListener(muatData);
  }

  String formatTanggal(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  void pesan(String teks) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(teks)),
    );
  }

  Future<void> muatData() async {
    try {
      final data = await db.ambil(cari: cari.text, status: filter);
      final angka = await db.statistik();

      if (!mounted) return;
      setState(() {
        laporan = data;
        statistik = angka;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      pesan('Gagal membaca data: $e');
    }
  }

  Future<void> ubahStatus(Laporan item) async {
    final status = item.status == 'Baru' ? 'Diproses' : 'Selesai';

    try {
      await db.ubahStatus(item.id!, status);
      await muatData();
      if (mounted) pesan('Status berhasil diubah');
    } catch (e) {
      if (mounted) pesan('Gagal mengubah status: $e');
    }
  }

  Future<void> hapus(Laporan item) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Laporan?'),
        content: Text('Hapus "${item.judul}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (yakin != true) return;

    try {
      await db.hapus(item.id!);
      await muatData();
      if (mounted) pesan('Laporan berhasil dihapus');
    } catch (e) {
      if (mounted) pesan('Gagal menghapus: $e');
    }
  }

  Future<void> edit(Laporan item) async {
    final formKey = GlobalKey<FormState>();
    final judul = TextEditingController(text: item.judul);
    final lokasi = TextEditingController(text: item.lokasi);

    String kategori = item.kategori;
    int urgensi = item.urgensi;
    DateTime tanggal = DateTime.parse(item.tanggal);

    final hasil = await showDialog<Laporan>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Edit Laporan'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: judul,
                    decoration: const InputDecoration(labelText: 'Judul'),
                    validator: (v) =>
                        v == null || v.trim().length < 5
                            ? 'Minimal 5 karakter'
                            : null,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: kategori,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: kategoriList.map((k) =>
                      DropdownMenuItem(value: k, child: Text(k))).toList(),
                    onChanged: (v) {
                      if (v != null) setDialog(() => kategori = v);
                    },
                  ),
                  TextFormField(
                    controller: lokasi,
                    decoration: const InputDecoration(labelText: 'Lokasi'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty
                            ? 'Lokasi wajib diisi'
                            : null,
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: urgensi,
                    decoration: const InputDecoration(labelText: 'Urgensi'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Normal')),
                      DropdownMenuItem(value: 2, child: Text('Mendesak')),
                      DropdownMenuItem(value: 3, child: Text('Darurat')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialog(() => urgensi = v);
                    },
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final pilih = await showDatePicker(
                        context: context,
                        initialDate: tanggal,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (pilih != null) {
                        setDialog(() => tanggal = pilih);
                      }
                    },
                    child: Text(formatTanggal(tanggal)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(context, Laporan(
                  id: item.id,
                  judul: judul.text.trim(),
                  kategori: kategori,
                  lokasi: lokasi.text.trim(),
                  urgensi: urgensi,
                  tanggal: formatTanggal(tanggal),
                  status: item.status,
                ));
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    judul.dispose();
    lokasi.dispose();

    if (hasil == null) return;

    try {
      await db.ubah(hasil);
      await muatData();
      if (mounted) pesan('Laporan berhasil diedit');
    } catch (e) {
      if (mounted) pesan('Gagal mengedit: $e');
    }
  }

  Widget kartuLaporan(Laporan item) {
    final selesai = item.status == 'Selesai';

    return Card(
      color: selesai ? Colors.green.shade50 : null,
      child: ListTile(
        title: Text(
          item.judul,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: selesai ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          '${item.kategori} - ${item.lokasi}\n'
          '${item.tanggal} | ${item.status} | '
          '${['', 'Normal', 'Mendesak', 'Darurat'][item.urgensi]}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (aksi) {
            if (aksi == 'status') ubahStatus(item);
            if (aksi == 'edit') edit(item);
            if (aksi == 'hapus') hapus(item);
          },
          itemBuilder: (context) => [
            if (!selesai)
              const PopupMenuItem(value: 'status', child: Text('Ubah Status')),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'hapus', child: Text('Hapus')),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    cari.removeListener(muatData);
    cari.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Laporan Kota'),
        actions: [
          IconButton(onPressed: muatData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  for (final data in [
                    ['Total', statistik['total']!, Colors.blue],
                    ['Aktif', statistik['aktif']!, Colors.orange],
                    ['Selesai', statistik['selesai']!, Colors.green],
                  ])
                    Expanded(
                      child: Card(
                        color: (data[2] as Color).withValues(alpha: 0.12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Text(
                                '${data[1]}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(data[0] as String),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cari,
                decoration: const InputDecoration(
                  labelText: 'Cari judul atau lokasi',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: ['Semua', 'Baru', 'Diproses', 'Selesai'].map((s) =>
                  ChoiceChip(
                    label: Text(s),
                    selected: filter == s,
                    onSelected: (_) {
                      setState(() => filter = s);
                      muatData();
                    },
                  )).toList(),
              ),
              const SizedBox(height: 12),
              if (loading)
                const Center(child: CircularProgressIndicator())
              else if (laporan.isEmpty)
                const Center(child: Text('Tidak ada laporan'))
              else
                ...laporan.map(kartuLaporan),
            ],
          ),
        ),
      ),
    );
  }
}
