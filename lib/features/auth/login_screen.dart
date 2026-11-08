import 'package:flutter/material.dart';
import '../../state/auth_controller.dart';

class LoginScreen extends StatelessWidget {
  final AuthController auth;
  const LoginScreen({super.key, required this.auth});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'WaktuTugas',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Atur waktu yang tersedia. Kerjakan tugas selangkah demi selangkah.',
              ),
              const SizedBox(height: 24),
              const Text(
                'Demo lokal • data contoh\nPerubahan hanya disimpan selama aplikasi terbuka. Akun daring belum terhubung.',
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: auth.enterDemo,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Buka demo lokal'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
