import 'package:flutter/material.dart';
import '../../state/auth_controller.dart';
import '../shared.dart';

class AccountScreen extends StatelessWidget {
  final AuthController auth;
  const AccountScreen({super.key, required this.auth});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Akun Anda')),
    body: PageContent(
      children: [
        const PageHeading(
          'Akun Anda',
          'Identitas untuk data dan jadwal pribadi.',
        ),
        PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DesignIcon('imgUserCircle', size: 48),
              const SizedBox(height: 16),
              Text(
                auth.userName ?? 'Mahasiswa demo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (auth.email != null) Text(auth.email!),
              const SizedBox(height: 16),
              StatusBadge(
                auth.isCloud ? 'Akun daring' : 'Demo lokal',
                icon: 'imgCheckCircle',
              ),
            ],
          ),
        ),
        Notice(
          title: auth.isCloud
              ? 'Data terikat ke akun ini'
              : 'Data contoh sementara',
          message: auth.isCloud
              ? 'Cache akun lain tidak ditampilkan. Setelah keluar, masuk kembali untuk memuat data Anda.'
              : 'Perubahan demo hanya tersimpan selama aplikasi terbuka.',
        ),
        AppButton(
          label: 'Keluar',
          icon: 'imgLogOut',
          secondary: true,
          onPressed: () async {
            await auth.logout();
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
    ),
  );
}
