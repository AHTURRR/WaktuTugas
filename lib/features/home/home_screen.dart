import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../app/theme.dart';
import '../../planner/models.dart';
import '../../planner/schedule.dart';
import '../../state/planner_controller.dart';
import '../shared.dart';
import '../time/time_form_screen.dart';

class HomeScreen extends StatelessWidget {
  final PlannerController planner;
  const HomeScreen({super.key, required this.planner});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isLargeText = MediaQuery.textScalerOf(context).scale(14) > 18;

    return ListenableBuilder(
      listenable: planner,
      builder: (context, _) {
        final tasks = planner.snapshot.tasks;
        final active = tasks.where((t) => t.remainingMinutes > 0).toList()
          ..sort((a, b) => a.deadlineAt.compareTo(b.deadlineAt));
        final totalRemainingMinutes = active.fold(
          0,
          (int n, t) => n + t.remainingMinutes,
        );

        final late = active
            .where((t) => !t.deadlineAt.isAfter(planner.now))
            .toList();
        final upcomingActive = active
            .where((t) => t.deadlineAt.isAfter(planner.now))
            .toList();

        final plannedSessions =
            planner.snapshot.sessions
                .where((s) => s.status == SessionStatus.planned)
                .toList()
              ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        final next = plannedSessions.firstOrNull;
        final nextTask = next != null ? planner.taskById(next.taskId) : null;
        final started = next != null && !next.startsAt.isAfter(planner.now);

        final today =
            planner.snapshot.sessions
                .where(
                  (s) =>
                      s.status != SessionStatus.cancelled &&
                      dateLabel(s.startsAt) == dateLabel(planner.now),
                )
                .toList()
              ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

        final locked = planner.isPending || planner.isOfflineSnapshot;

        return PageContent(
          children: [
            // =================================================================
            // 1. FOCUS PANEL: PRIORITAS UTAMA APA YANG HARUS DIKERJAKAN
            // =================================================================
            _buildFocusPanel(
              context: context,
              colors: colors,
              tasks: tasks,
              active: active,
              totalMinutes: totalRemainingMinutes,
              next: next,
              nextTask: nextTask,
              started: started,
              locked: locked,
              isLargeText: isLargeText,
            ),

            // =================================================================
            // 2. PERINGATAN & TINDAKAN JADWAL
            // =================================================================
            if (planner.needsReschedule) ...[
              const SizedBox(height: AppLayout.space12),
              PaperCard(
                color: colors.warningBg,
                borderColor: colors.warningInk.withValues(alpha: 0.3),
                padding: const EdgeInsets.all(AppLayout.space12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: DesignIcon(
                            'imgAlertCircle',
                            size: 20,
                            color: colors.warningInk,
                          ),
                        ),
                        const SizedBox(width: AppLayout.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jadwal perlu diperbarui',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: colors.warningInk,
                                    ),
                              ),
                              const SizedBox(height: AppLayout.space4),
                              Text(
                                'Data tugas atau rentang waktu berubah. Perbarui jadwal agar sesi belajar tetap konsisten.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.warningInk),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppLayout.space8),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        onPressed: () => context.go('/schedule'),
                        icon: const DesignIcon('imgArrowRight', size: 16),
                        label: const Text('Buka jadwal'),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (planner.preview != null &&
                planner.preview!.unallocated.isNotEmpty) ...[
              const SizedBox(height: AppLayout.space12),
              PaperCard(
                color: colors.warningBg,
                borderColor: colors.warningInk.withValues(alpha: 0.3),
                padding: const EdgeInsets.all(AppLayout.space12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: DesignIcon(
                            'imgAlertCircle',
                            size: 20,
                            color: colors.warningInk,
                          ),
                        ),
                        const SizedBox(width: AppLayout.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sebagian tugas belum tertampung kapasitas',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: colors.warningInk,
                                    ),
                              ),
                              const SizedBox(height: AppLayout.space4),
                              for (final u in planner.preview!.unallocated)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '\u2022 ${planner.taskById(u.taskId)?.title ?? u.taskId}: ${u.minutes} menit belum terjadwal',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: colors.warningInk),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppLayout.space8),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: AppLayout.space8,
                      runSpacing: AppLayout.space4,
                      children: [
                        TextButton(
                          onPressed: () => context.go('/time'),
                          child: const Text('Tambah waktu'),
                        ),
                        TextButton(
                          onPressed: () => context.go('/schedule'),
                          child: const Text('Tinjau jadwal'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            ErrorNotice(planner.error),

            // =================================================================
            // 3. TUGAS PERLU PERHATIAN (TERLAMBAT)
            // =================================================================
            if (late.isNotEmpty) ...[
              const SizedBox(height: AppLayout.space16),
              SectionHeader(
                title: 'Tugas terlambat',
                subtitle:
                    'Tenggat telah lewat. Perbarui tenggat atau selesaikan tugas.',
                trailing: StatusBadge(
                  '${late.length} terlambat',
                  tone: StatusTone.danger,
                  icon: 'imgAlertCircle',
                ),
              ),
              for (final task in late) ...[
                PaperCard(
                  margin: const EdgeInsets.only(bottom: AppLayout.space8),
                  padding: EdgeInsets.zero,
                  borderColor: colors.dangerInk.withValues(alpha: 0.3),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(AppLayout.radius),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => context.push('/task/${task.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(AppLayout.space16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colors.dangerBg,
                                shape: BoxShape.circle,
                              ),
                              child: DesignIcon(
                                'imgAlertCircle',
                                size: 18,
                                color: colors.dangerInk,
                              ),
                            ),
                            const SizedBox(width: AppLayout.space12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  if (task.course case final course?)
                                    Text(
                                      course,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.inkSecondary,
                                          ),
                                    ),
                                  const SizedBox(height: AppLayout.space4),
                                  Text(
                                    'Lewat: ${dateTimeLabel(task.deadlineAt)}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: colors.dangerInk,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                  Text(
                                    '${task.remainingMinutes} menit tersisa',
                                    style: AppTypography.time.copyWith(
                                      color: colors.inkSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppLayout.space8),
                            DesignIcon(
                              'imgChevronRight',
                              size: 20,
                              color: colors.inkMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],

            // =================================================================
            // 3B. PANDUAN SINGKAT AKUN BARU / KOSONG
            // =================================================================
            if (planner.shouldShowOnboardingGuide) ...[
              const SizedBox(height: AppLayout.space16),
              _OnboardingGuideCard(
                planner: planner,
                locked: locked,
              ),
            ],

            // =================================================================
            // 4. AGENDA HARI INI
            // =================================================================
            const SizedBox(height: AppLayout.space16),
            SectionHeader(
              title: 'Agenda hari ini',
              subtitle: dateLabel(planner.now),
              trailing: TextButton(
                onPressed: () => context.go('/schedule'),
                child: const Text('Lihat semua'),
              ),
            ),
            if (today.isEmpty)
              PaperCard(
                color: colors.primarySoft,
                padding: const EdgeInsets.all(AppLayout.space16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DesignIcon(
                        'imgCalendar',
                        color: colors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppLayout.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tidak ada sesi belajar hari ini',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            active.isNotEmpty
                                ? 'Manfaatkan hari untuk istirahat atau tinjau jadwal belajar mendatang.'
                                : 'Tidak ada tugas aktif atau sesi belajar yang dijadwalkan.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.inkSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final session in today)
                SessionCard(
                  session: session,
                  title:
                      planner.taskById(session.taskId)?.title ?? session.taskId,
                  onTap: () => context.push('/session/${session.id}'),
                ),

            // =================================================================
            // 5. TENGGAT TERDEKAT (MENDATANG)
            // =================================================================
            if (upcomingActive.isNotEmpty) ...[
              const SizedBox(height: AppLayout.section),
              SectionHeader(
                title: 'Tenggat terdekat',
                subtitle: 'Prioritas berdasarkan batas waktu pengumpulan tugas.',
                trailing: TextButton(
                  onPressed: () => context.go('/tasks'),
                  child: const Text('Semua tugas'),
                ),
              ),
              for (final task in upcomingActive.take(4))
                _buildUpcomingTaskCard(
                  context: context,
                  task: task,
                  now: planner.now,
                  colors: colors,
                  isLargeText: isLargeText,
                ),
            ],

            // =================================================================
            // 6. STATUS TUGAS SELESAI
            // =================================================================
            if (tasks.isNotEmpty && active.isEmpty) ...[
              const SizedBox(height: AppLayout.section),
              PaperCard(
                color: colors.successBg,
                borderColor: colors.successInk.withValues(alpha: 0.3),
                padding: const EdgeInsets.all(AppLayout.space16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: DesignIcon(
                        'imgCheckCircle',
                        color: colors.successInk,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppLayout.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Semua target tugas tuntas!',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: colors.successInk,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: AppLayout.space4),
                          Text(
                            'Tidak ada sisa pengerjaan pada seluruh ${tasks.length} tugas. Istirahat yang cukup atau buat tugas baru saat semester berjalan.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.successInk),
                          ),
                          const SizedBox(height: AppLayout.space12),
                          Wrap(
                            spacing: AppLayout.space8,
                            runSpacing: AppLayout.space8,
                            children: [
                              AppButton(
                                label: 'Lihat daftar tugas',
                                icon: 'imgNavigationCheckSquare',
                                secondary: true,
                                onPressed: () => context.go('/tasks'),
                              ),
                              AppButton(
                                label: 'Tambah tugas baru',
                                icon: 'imgPlus',
                                onPressed: locked
                                    ? null
                                    : () => context.push('/task/new'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // ===========================================================================
  // WIDGET HELPER: FOCUS PANEL
  // ===========================================================================
  Widget _buildFocusPanel({
    required BuildContext context,
    required AppColors colors,
    required List<Task> tasks,
    required List<Task> active,
    required int totalMinutes,
    required PlannerSession? next,
    required Task? nextTask,
    required bool started,
    required bool locked,
    required bool isLargeText,
  }) {
    if (tasks.isEmpty) {
      return FocusPanel(
        eyebrow: dateLabel(planner.now),
        title: 'Mulai perjalanan\nbelajar Anda.',
        description:
            'Belum ada tugas atau jadwal terdaftar. Tambahkan tugas pertama Anda untuk memulai perencanaan terarah.',
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: 'Tambah tugas pertama',
              highlighted: true,
              icon: 'imgPlus',
              onPressed: locked ? null : () => context.push('/task/new'),
            ),
            const SizedBox(height: AppLayout.space8),
            AppButton(
              label: 'Atur waktu belajar',
              secondary: true,
              icon: 'imgClock',
              onPressed: () => context.go('/time'),
            ),
          ],
        ),
      );
    }

    if (active.isEmpty) {
      return FocusPanel(
        eyebrow: dateLabel(planner.now),
        title: 'Semua tugas\ntelah selesai!',
        description:
            'Kerja luar biasa! Seluruh ${tasks.length} tugas telah tuntas dikerjakan.',
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: 'Tambah tugas baru',
              highlighted: true,
              icon: 'imgPlus',
              onPressed: locked ? null : () => context.push('/task/new'),
            ),
            const SizedBox(height: AppLayout.space8),
            AppButton(
              label: 'Lihat daftar tugas',
              secondary: true,
              icon: 'imgCheckCircle',
              onPressed: () => context.go('/tasks'),
            ),
          ],
        ),
      );
    }

    if (next != null) {
      return FocusPanel(
        eyebrow: dateLabel(planner.now),
        title: started ? 'Saatnya catat\nlangkah Anda.' : 'Beri ruang\nuntuk fokus.',
        description:
            '${active.length} tugas aktif \u00b7 $totalMinutes menit tersisa',
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Divider(color: colors.onPanel.withValues(alpha: 0.3), height: 1),
            const SizedBox(height: AppLayout.space16),
            Text(
              started ? 'SESI PERLU DICATAT' : 'SESI BERIKUTNYA',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: AppLayout.space8),
            Text(
              nextTask?.title ?? next.taskId,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.onPanel,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (nextTask?.course case final course?) ...[
              const SizedBox(height: 2),
              Text(
                course,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onPanel.withValues(alpha: 0.8),
                ),
              ),
            ],
            const SizedBox(height: AppLayout.space8),
            Text(
              '${dateLabel(next.startsAt)}\n${clockLabel(next.startsAt)} \u2013 ${clockLabel(next.endsAt)} WIB (${next.endsAt.difference(next.startsAt).inMinutes} menit)',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onPanel),
            ),
            const SizedBox(height: AppLayout.page),
            AppButton(
              label: started ? 'Catat progres sesi' : 'Buka sesi berikutnya',
              highlighted: true,
              icon: started ? 'imgCheckCircle' : 'imgArrowRight',
              // Selalu izinkan navigasi untuk membaca detail sesi (bahkan saat luring)
              onPressed: () => context.push('/session/${next.id}'),
            ),
          ],
        ),
      );
    }

    // Ada tugas aktif tapi belum ada sesi yang terencana
    return FocusPanel(
      eyebrow: dateLabel(planner.now),
      title: 'Susun jadwal\nuntuk mulai.',
      description:
          '${active.length} tugas aktif ($totalMinutes menit) belum memiliki jadwal sesi belajar.',
      footer: AppButton(
        label: 'Tinjau & susun jadwal',
        highlighted: true,
        icon: 'imgCalendar',
        onPressed: () => context.go('/schedule'),
      ),
    );
  }

  // ===========================================================================
  // WIDGET HELPER: UPCOMING DEADLINE CARD
  // ===========================================================================
  Widget _buildUpcomingTaskCard({
    required BuildContext context,
    required Task task,
    required DateTime now,
    required AppColors colors,
    required bool isLargeText,
  }) {
    final nowJkt = tz.TZDateTime.from(now, jakarta);
    final deadlineJkt = tz.TZDateTime.from(task.deadlineAt, jakarta);

    final isToday =
        nowJkt.year == deadlineJkt.year &&
        nowJkt.month == deadlineJkt.month &&
        nowJkt.day == deadlineJkt.day;

    final tomorrowJkt = tz.TZDateTime(
      jakarta,
      nowJkt.year,
      nowJkt.month,
      nowJkt.day + 1,
    );
    final isTomorrow =
        tomorrowJkt.year == deadlineJkt.year &&
        tomorrowJkt.month == deadlineJkt.month &&
        tomorrowJkt.day == deadlineJkt.day;

    final hoursLeft = task.deadlineAt.difference(now).inHours;

    final (badgeLabel, badgeTone, badgeIcon) = isToday
        ? ('Hari ini', StatusTone.warning, 'imgClock')
        : isTomorrow
        ? ('Besok', StatusTone.info, 'imgCalendar')
        : hoursLeft <= 48
        ? ('$hoursLeft jam lagi', StatusTone.info, 'imgClock')
        : (
            DateFormat('d MMM', 'id_ID').format(deadlineJkt),
            StatusTone.neutral,
            'imgCalendar',
          );

    return PaperCard(
      margin: const EdgeInsets.only(bottom: AppLayout.space8),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppLayout.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/task/${task.id}'),
          child: Padding(
            padding: const EdgeInsets.all(AppLayout.space16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppLayout.space8,
                        runSpacing: AppLayout.space4,
                        children: [
                          StatusBadge(
                            badgeLabel,
                            tone: badgeTone,
                            icon: badgeIcon,
                          ),
                          if (task.course case final course?)
                            Text(
                              course,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.inkSecondary),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppLayout.space8),
                      Text(
                        task.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tenggat ${dateTimeLabel(task.deadlineAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${task.remainingMinutes} menit tersisa',
                        style: AppTypography.time.copyWith(
                          color: colors.inkSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppLayout.space8),
                DesignIcon(
                  'imgChevronRight',
                  size: 20,
                  color: colors.inkMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingGuideCard extends StatelessWidget {
  final PlannerController planner;
  final bool locked;

  const _OnboardingGuideCard({
    required this.planner,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasTask = planner.snapshot.tasks.isNotEmpty;
    final hasTimeWindow = planner.snapshot.timeWindows.isNotEmpty;
    final hasPreview =
        planner.preview != null || planner.snapshot.sessions.isNotEmpty;

    final completedCount =
        (hasTask ? 1 : 0) + (hasTimeWindow ? 1 : 0) + (hasPreview ? 1 : 0);

    final activeStep = !hasTask
        ? 1
        : !hasTimeWindow
        ? 2
        : 3;

    return PaperCard(
      borderColor: colors.primary.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Langkah awal penggunaan',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$completedCount dari 3 langkah selesai',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => planner.dismissOnboarding(),
                child: const Text('Lewati'),
              ),
            ],
          ),
          const SizedBox(height: AppLayout.space12),
          _OnboardingStepRow(
            stepNumber: 1,
            title: 'Buat satu tugas',
            description:
                'Masukkan nama tugas, tenggat, dan sisa waktu pengerjaan.',
            done: hasTask,
            active: activeStep == 1,
            actionLabel: 'Buat tugas',
            actionIcon: 'imgPlus',
            onAction: locked ? null : () => context.push('/task/new'),
          ),
          const SizedBox(height: AppLayout.space8),
          _OnboardingStepRow(
            stepNumber: 2,
            title: 'Tambah waktu belajar',
            description:
                'Tentukan rentang waktu luang agar jadwal bisa disusun.',
            done: hasTimeWindow,
            active: activeStep == 2,
            actionLabel: 'Tambah waktu belajar',
            actionIcon: 'imgClock',
            onAction: locked
                ? null
                : () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TimeFormScreen(planner: planner),
                    ),
                  ),
          ),
          const SizedBox(height: AppLayout.space8),
          _OnboardingStepRow(
            stepNumber: 3,
            title: 'Buka pratinjau pertama',
            description:
                'Lihat usulan jadwal otomatis sebelum Anda menyimpannya.',
            done: hasPreview,
            active: activeStep == 3,
            actionLabel: 'Buka pratinjau',
            actionIcon: 'imgCalendar',
            onAction: locked
                ? null
                : () async {
                    final ok = await planner.generatePreview();
                    if (!context.mounted) return;
                    if (ok) {
                      context.go('/schedule/preview');
                    } else {
                      context.go('/schedule');
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class _OnboardingStepRow extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String description;
  final bool done;
  final bool active;
  final String actionLabel;
  final String actionIcon;
  final VoidCallback? onAction;

  const _OnboardingStepRow({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.done,
    required this.active,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppLayout.space12),
      decoration: BoxDecoration(
        color: active
            ? colors.primarySoft.withValues(alpha: 0.55)
            : colors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? colors.primary.withValues(alpha: 0.4)
              : colors.outline.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DesignIcon(
                done ? 'imgCheckCircle' : 'imgArrowRight',
                size: 18,
                color: done
                    ? colors.successInk
                    : active
                    ? colors.primary
                    : colors.inkMuted,
              ),
              const SizedBox(width: AppLayout.space8),
              Expanded(
                child: Text(
                  '$stepNumber. $title',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: done ? colors.inkSecondary : colors.ink,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (done)
                StatusBadge(
                  'Selesai',
                  tone: StatusTone.success,
                ),
            ],
          ),
          if (active && !done) ...[
            const SizedBox(height: AppLayout.space4),
            Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.inkSecondary),
            ),
            const SizedBox(height: AppLayout.space12),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: actionLabel,
                icon: actionIcon,
                onPressed: onAction,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
