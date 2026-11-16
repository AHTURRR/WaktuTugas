import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/whatsapp_api.dart';
import '../../state/auth_controller.dart';
import '../../state/planner_controller.dart';
import '../shared.dart';
import 'whatsapp_screen.dart';

class AccountScreen extends StatelessWidget {
  final AuthController auth;
  final ValueNotifier<ThemeMode> themeMode;
  final WhatsAppApi? whatsapp;
  final PlannerController? planner;
  const AccountScreen({
    super.key,
    required this.auth,
    required this.themeMode,
    this.whatsapp,
    this.planner,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Akun Anda')),
      body: ListenableBuilder(
        listenable: auth,
        builder: (context, _) => PageContent(
          children: [
            FocusPanel(
              eyebrow: 'RUANG PRIBADI',
              icon: 'imgUserCircle',
              title: auth.userName ?? 'Mahasiswa demo',
              description:
                  auth.email ?? 'Coba, atur, dan jelajahi perencanaan lokal.',
              footer: Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(
                  auth.isCloud ? 'Akun daring' : 'Demo lokal',
                  tone: auth.isCloud ? StatusTone.success : StatusTone.neutral,
                  icon: 'imgUserCircle',
                ),
              ),
            ),
            const SectionHeader(title: 'Tampilan'),
            PaperCard(
              padding: EdgeInsets.zero,
              child: ValueListenableBuilder(
                valueListenable: themeMode,
                builder: (context, mode, _) => Material(
                  type: MaterialType.transparency,
                  child: RadioGroup<ThemeMode>(
                    groupValue: mode,
                    onChanged: (value) {
                      if (value != null) themeMode.value = value;
                    },
                    child: Column(
                      children: [
                        for (final (value, label) in const [
                          (ThemeMode.system, 'Ikuti sistem'),
                          (ThemeMode.light, 'Terang'),
                          (ThemeMode.dark, 'Gelap'),
                        ])
                          KeyboardFocusOutline(
                            child: RadioListTile(
                              value: value,
                              title: Text(label),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (planner != null && planner!.reminderService != null) ...[
              const SectionHeader(
                title: 'Pengingat sesi lokal',
                subtitle:
                    'Notifikasi Android terpisah dari pengingat WhatsApp.',
              ),
              ListenableBuilder(
                listenable: planner!,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PaperCard(
                      padding: EdgeInsets.zero,
                      child: Material(
                        type: MaterialType.transparency,
                        child: SwitchListTile(
                          title: const Text('Pengingat 15 menit sebelum sesi'),
                          subtitle: const Text(
                            'Aktifkan notifikasi lokal perangkat untuk sesi yang dikonfirmasi.',
                          ),
                          value: planner!.localReminderEnabled,
                          onChanged: (value) =>
                              planner!.setLocalReminderEnabled(value),
                        ),
                      ),
                    ),
                    if (planner!.localReminderError != null) ...[
                      const SizedBox(height: AppLayout.space8),
                      Notice(
                        title: 'Izin notifikasi diperlukan',
                        message: planner!.localReminderError!,
                        color: colors.warningBg,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppLayout.space16),
            ],
            if (auth.signedIn && auth.isCloud && whatsapp != null) ...[
              AppButton(
                label: 'Pengingat WhatsApp',
                icon: 'imgClock',
                secondary: true,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WhatsAppScreen(auth: auth, api: whatsapp!),
                  ),
                ),
              ),
              const SizedBox(height: AppLayout.space16),
            ],
            const SectionHeader(
              title: 'Akun & penyimpanan',
              subtitle: 'Kejelasan tentang data yang Anda gunakan.',
            ),
            Notice(
              title: auth.isCloud
                  ? 'Data terikat ke akun ini'
                  : 'Data contoh sementara',
              message: auth.isCloud
                  ? 'Cache akun lain tidak ditampilkan. Setelah keluar, masuk kembali untuk memuat data Anda.'
                  : 'Perubahan demo hanya tersimpan selama aplikasi terbuka.',
              color: auth.isCloud ? colors.primarySoft : colors.warningBg,
              icon: auth.isCloud ? 'imgCheckCircle' : 'imgAlertCircle',
            ),
            ErrorNotice(auth.error),
            AppButton(
              label: 'Keluar',
              icon: 'imgLogOut',
              secondary: true,
              onPressed: () async {
                final ok = await auth.logout();
                if (ok && context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
