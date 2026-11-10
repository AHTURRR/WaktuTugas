import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../state/auth_controller.dart';
import '../shared.dart';

class AccountScreen extends StatelessWidget {
  final AuthController auth;
  const AccountScreen({super.key, required this.auth});

  @override
  Widget build(BuildContext context) => Scaffold(
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
                icon: 'imgUserCircle',
              ),
            ),
          ),
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
            color: auth.isCloud ? AppColors.primarySoft : AppColors.warning,
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
