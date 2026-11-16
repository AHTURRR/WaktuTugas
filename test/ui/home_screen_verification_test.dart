import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:waktu_tugas/app/app.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/state/auth_controller.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

class OfflinePlanner extends PlannerController {
  OfflinePlanner({super.clock, super.initial});
  @override
  bool get isOfflineSnapshot => true;
}

Future<void> bootWithSnapshot(
  WidgetTester t,
  PlannerSnapshot snapshot, {
  DateTime? now,
  bool isOffline = false,
  Size size = const Size(412, 915),
  double textScale = 1.0,
}) async {
  t.view.physicalSize = Size(size.width * 2.0, size.height * 2.0);
  t.view.devicePixelRatio = 2.0;

  final auth = AuthController()..enterDemo();
  final planner = isOffline
      ? OfflinePlanner(
          clock: () => now ?? DateTime.utc(2026, 11, 9, 11),
          initial: snapshot,
        )
      : PlannerController(
          clock: () => now ?? DateTime.utc(2026, 11, 9, 11),
          initial: snapshot,
        );

  await t.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: WaktuTugasApp(auth: auth, planner: planner),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  setUpAll(tz.initializeTimeZones);

  testWidgets('Ringkasan: Akun kosong menampilkan panduan dan tombol awal yang jelas', (
    t,
  ) async {
    final emptySnapshot = PlannerSnapshot(
      revision: 0,
      tasks: [],
      timeWindows: [],
      activities: [],
      sessions: [],
    );

    await bootWithSnapshot(t, emptySnapshot);

    // 1. Verifikasi ucapan sambutan dan deskripsi awal
    expect(find.text('Mulai perjalanan\nbelajar Anda.'), findsOneWidget);
    expect(
      find.textContaining('Belum ada tugas atau jadwal terdaftar'),
      findsOneWidget,
    );

    // 2. Verifikasi tombol tindakan awal
    expect(find.text('Tambah tugas pertama'), findsOneWidget);
    expect(find.text('Atur waktu belajar'), findsWidgets);
    expect(find.text('Langkah awal penggunaan'), findsOneWidget);

    // 3. Verifikasi jalur tindakan: klik Tambah tugas pertama membuka form tugas
    await t.tap(find.text('Tambah tugas pertama'));
    await t.pumpAndSettle();
    expect(find.text('Tambah tugas'), findsWidgets);
  });

  testWidgets(
    'Ringkasan: Hari tanpa sesi menampilkan informasi yang jelas dan aksi ke jadwal',
    (t) async {
      final now = DateTime.utc(2026, 11, 9, 11); // Senin, 18:00 WIB
      // Tugas ada, tapi sesi terencana dijadwalkan untuk besok (10 Nov)
      final snapshot = PlannerSnapshot(
        revision: 1,
        tasks: [
          Task(
            id: 'T01',
            title: 'Tugas Algoritma',
            course: 'IF101',
            deadlineAt: DateTime.utc(2026, 11, 15, 12),
            remainingMinutes: 120,
            createdAt: now,
          ),
        ],
        timeWindows: [],
        activities: [],
        sessions: [
          PlannerSession(
            id: 'S01',
            taskId: 'T01',
            startsAt: DateTime.utc(2026, 11, 10, 12), // Besok
            endsAt: DateTime.utc(2026, 11, 10, 14),
            status: SessionStatus.planned,
          ),
        ],
      );

      await bootWithSnapshot(t, snapshot, now: now);

      // 1. Sesi berikutnya (besok) diprioritaskan di FocusPanel
      expect(find.text('SESI BERIKUTNYA'), findsOneWidget);
      expect(find.text('Tugas Algoritma'), findsWidgets);
      expect(find.text('IF101'), findsWidgets);
      expect(find.text('Buka sesi berikutnya'), findsOneWidget);

      // 2. Agenda hari ini kosong
      expect(find.text('Agenda hari ini'), findsOneWidget);
      expect(find.text('Tidak ada sesi belajar hari ini'), findsOneWidget);

      // 3. Jalur navigasi ke detail sesi berikutnya bekerja
      await t.tap(find.text('Buka sesi berikutnya'));
      await t.pumpAndSettle();
      expect(find.text('Detail sesi'), findsOneWidget);
      expect(find.text('Tugas Algoritma'), findsOneWidget);
    },
  );

  testWidgets(
    'Ringkasan: Beberapa tenggat berdekatan diurutkan dengan badge relatif dan jalur ke detail',
    (t) async {
      final now = DateTime.utc(2026, 11, 9, 11); // Senin, 18:00 WIB
      // Tugas 1: tenggat hari ini pukul 23:00 WIB (16:00 UTC)
      // Tugas 2: tenggat besok pukul 12:00 WIB (05:00 UTC)
      // Tugas 3: tenggat lusa
      final snapshot = PlannerSnapshot(
        revision: 1,
        tasks: [
          Task(
            id: 'T_LUSA',
            title: 'Laporan Praktikum Fisika',
            course: 'FI102',
            deadlineAt: DateTime.utc(2026, 11, 11, 10),
            remainingMinutes: 90,
            createdAt: now,
          ),
          Task(
            id: 'T_TODAY',
            title: 'Kuis Matematika Diskrit',
            course: 'MA201',
            deadlineAt: DateTime.utc(2026, 11, 9, 16), // Hari ini 23:00 WIB
            remainingMinutes: 60,
            createdAt: now,
          ),
          Task(
            id: 'T_TOMORROW',
            title: 'Tugas Pemrograman Web',
            course: 'IF203',
            deadlineAt: DateTime.utc(2026, 11, 10, 5), // Besok 12:00 WIB
            remainingMinutes: 120,
            createdAt: now,
          ),
        ],
        timeWindows: [],
        activities: [],
        sessions: [],
      );

      await bootWithSnapshot(t, snapshot, now: now);

      // 1. Verifikasi bagian Tenggat terdekat muncul
      expect(find.text('Tenggat terdekat'), findsOneWidget);

      // 2. Verifikasi badge tenggat relatif
      expect(find.text('Hari ini'), findsOneWidget);
      expect(find.text('Besok'), findsOneWidget);

      // 3. Verifikasi urutan: Kuis Matematika Diskrit (Hari ini) muncul teratas
      final textWidgets = t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').toList();
      final idxToday = textWidgets.indexOf('Kuis Matematika Diskrit');
      final idxTomorrow = textWidgets.indexOf('Tugas Pemrograman Web');
      final idxLusa = textWidgets.indexOf('Laporan Praktikum Fisika');
      expect(idxToday != -1 && idxTomorrow != -1 && idxLusa != -1, isTrue);
      expect(idxToday < idxTomorrow, isTrue);
      expect(idxTomorrow < idxLusa, isTrue);

      // 4. Jalur jelas ke detail: ketuk tugas pertama membuka form/detail tugas
      await t.ensureVisible(find.text('Kuis Matematika Diskrit'));
      await t.tap(find.text('Kuis Matematika Diskrit'));
      await t.pumpAndSettle();
      expect(find.text('Ubah tugas'), findsOneWidget);
      expect(find.text('Kuis Matematika Diskrit'), findsWidgets);
    },
  );

  testWidgets('Ringkasan: Semua tugas selesai menampilkan apresiasi dan tindakan lanjutan', (
    t,
  ) async {
    final now = DateTime.utc(2026, 11, 9, 11);
    final snapshot = PlannerSnapshot(
      revision: 2,
      tasks: [
        Task(
          id: 'T01',
          title: 'Makalah Bahasa Indonesia',
          deadlineAt: DateTime.utc(2026, 11, 12, 12),
          remainingMinutes: 0, // Selesai
          createdAt: now,
        ),
        Task(
          id: 'T02',
          title: 'Tugas Sistem Operasi',
          deadlineAt: DateTime.utc(2026, 11, 14, 12),
          remainingMinutes: 0, // Selesai
          createdAt: now,
        ),
      ],
      timeWindows: [],
      activities: [],
      sessions: [],
    );

    await bootWithSnapshot(t, snapshot, now: now);

    // 1. FocusPanel menampilkan status selesai
    expect(find.text('Semua tugas\ntelah selesai!'), findsOneWidget);
    expect(
      find.text('Kerja luar biasa! Seluruh 2 tugas telah tuntas dikerjakan.'),
      findsOneWidget,
    );

    // 2. Banner pencapaian selesai muncul
    expect(find.text('Semua target tugas tuntas!'), findsOneWidget);

    // 3. Tombol tindakan relevan tersedia
    expect(find.text('Tambah tugas baru'), findsWidgets);
    expect(find.text('Lihat daftar tugas'), findsWidgets);

    // 4. Ketuk tombol 'Lihat daftar tugas' membuka layar Tugas
    await t.tap(find.text('Lihat daftar tugas').first);
    await t.pumpAndSettle();
    expect(find.text('Tugas selesai'), findsOneWidget);
  });

  testWidgets(
    'Ringkasan: Cache luring tetap menampilkan data dan jalur baca detail dapat dibuka',
    (t) async {
      final now = DateTime.utc(2026, 11, 9, 11);
      final snapshot = PlannerSnapshot(
        revision: 3,
        tasks: [
          Task(
            id: 'T01',
            title: 'Tugas Jaringan Komputer',
            course: 'IF301',
            deadlineAt: DateTime.utc(2026, 11, 15, 12),
            remainingMinutes: 90,
            createdAt: now,
          ),
        ],
        timeWindows: [],
        activities: [],
        sessions: [
          PlannerSession(
            id: 'S01',
            taskId: 'T01',
            startsAt: DateTime.utc(2026, 11, 9, 12),
            endsAt: DateTime.utc(2026, 11, 9, 13, 30),
            status: SessionStatus.planned,
          ),
        ],
      );

      await bootWithSnapshot(t, snapshot, now: now, isOffline: true);

      // 1. Banner luring muncul di atas
      expect(find.text('Luring · hanya baca'), findsOneWidget);

      // 2. Informasi sesi berikutnya tetap terbaca dengan jelas
      expect(find.text('Tugas Jaringan Komputer'), findsWidgets);
      expect(find.text('Buka sesi berikutnya'), findsOneWidget);

      // 3. Jalur baca ke detail sesi tetap dapat dibuka dalam mode luring
      await t.tap(find.text('Buka sesi berikutnya'));
      await t.pumpAndSettle();
      expect(find.text('Detail sesi'), findsOneWidget);
      expect(find.text('Tugas Jaringan Komputer'), findsWidgets);
    },
  );

  testWidgets(
    'Ringkasan: Tugas terlambat muncul dengan jelas dan punya jalur langsung ke detail',
    (t) async {
      final now = DateTime.utc(2026, 11, 10, 11);
      final snapshot = PlannerSnapshot(
        revision: 1,
        tasks: [
          Task(
            id: 'T_LATE',
            title: 'Tugas Struktur Data Terlambat',
            course: 'IF202',
            deadlineAt: DateTime.utc(2026, 11, 9, 10), // Kemarin (terlambat)
            remainingMinutes: 60,
            createdAt: DateTime.utc(2026, 11, 1),
          ),
        ],
        timeWindows: [],
        activities: [],
        sessions: [],
      );

      await bootWithSnapshot(t, snapshot, now: now);

      // 1. Bagian tugas terlambat muncul
      expect(find.text('Tugas terlambat'), findsOneWidget);
      expect(find.text('1 terlambat'), findsOneWidget);
      expect(find.text('Tugas Struktur Data Terlambat'), findsOneWidget);

      // 2. Ketuk item terlambat membuka form/detail tugas
      await t.tap(find.text('Tugas Struktur Data Terlambat'));
      await t.pumpAndSettle();
      expect(find.text('Ubah tugas'), findsOneWidget);
      expect(find.text('Tugas Struktur Data Terlambat'), findsWidgets);
    },
  );

  testWidgets(
    'Ringkasan: Responsif pada layar Android sempit (360x640) dan teks diperbesar (1.8x)',
    (t) async {
      final now = DateTime.utc(2026, 11, 9, 11);
      final snapshot = PlannerSnapshot(
        revision: 1,
        tasks: [
          Task(
            id: 'T01',
            title: 'Proyek Akhir Rekayasa Perangkat Lunak Berbasis Platform Modern',
            course: 'IF401 Rekayasa Perangkat Lunak Lanjut',
            deadlineAt: DateTime.utc(2026, 11, 9, 16),
            remainingMinutes: 180,
            createdAt: now,
          ),
          Task(
            id: 'T02',
            title: 'Laporan Praktikum Sistem Tertanam dan Komputasi Bergerak',
            course: 'EL302 Sistem Tertanam',
            deadlineAt: DateTime.utc(2026, 11, 10, 5),
            remainingMinutes: 120,
            createdAt: now,
          ),
        ],
        timeWindows: [],
        activities: [],
        sessions: [
          PlannerSession(
            id: 'S01',
            taskId: 'T01',
            startsAt: DateTime.utc(2026, 11, 9, 12),
            endsAt: DateTime.utc(2026, 11, 9, 13, 30),
            status: SessionStatus.planned,
          ),
        ],
      );

      // Layar Android sempit: 360 x 640 dengan skala teks 1.8x
      await bootWithSnapshot(
        t,
        snapshot,
        now: now,
        size: const Size(360, 640),
        textScale: 1.8,
      );

      // 1. Verifikasi tidak ada RenderFlex overflow
      expect(t.takeException(), isNull);

      // 2. Verifikasi konten esensial tetap ada dan terbaca
      expect(find.text('SESI BERIKUTNYA'), findsOneWidget);
      expect(find.text('Buka sesi berikutnya'), findsOneWidget);
      expect(find.text('Tenggat terdekat'), findsOneWidget);
    },
  );
}
