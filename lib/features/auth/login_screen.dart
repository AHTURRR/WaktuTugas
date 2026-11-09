import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../state/auth_controller.dart';
import '../shared.dart';

enum _LoginView { login, register, demo, confirmation }

class LoginScreen extends StatefulWidget {
  final AuthController auth;
  const LoginScreen({super.key, required this.auth});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  late _LoginView view;
  bool pending = false, obscure = true, resent = false;
  @override
  void initState() {
    super.initState();
    view = widget.auth.isCloud ? _LoginView.login : _LoginView.demo;
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void changeView(_LoginView next) {
    setState(() {
      view = next;
      widget.auth.error = null;
      resent = false;
    });
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => pending = true);
    final registration = view == _LoginView.register;
    final ok = registration
        ? await widget.auth.register(
            name.text.trim(),
            email.text.trim(),
            password.text,
          )
        : await widget.auth.signIn(email.text.trim(), password.text);
    if (!mounted) return;
    setState(() {
      pending = false;
      if (ok && registration && !widget.auth.signedIn) {
        view = _LoginView.confirmation;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final demo = view == _LoginView.demo,
        register = view == _LoginView.register,
        confirmation = view == _LoginView.confirmation;
    return Scaffold(
      appBar: AppBar(title: const Text('WaktuTugas')),
      body: Form(
        key: form,
        child: PageContent(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: StudyIllustration(),
              ),
            ),
            PageHeading(
              demo
                  ? 'Coba tanpa akun'
                  : register
                  ? 'Mulai lebih terencana'
                  : confirmation
                  ? 'Periksa email Anda'
                  : 'Waktu untuk yang penting.',
              demo
                  ? 'Jelajahi alur dengan data contoh, tanpa terhubung ke layanan daring.'
                  : register
                  ? 'Buat akun untuk merencanakan tugas kuliah Anda.'
                  : confirmation
                  ? 'Buka tautan konfirmasi sebelum masuk.'
                  : 'Atur tugas, luangkan waktu, dan jalani satu sesi fokus pada satu waktu.',
            ),
            if (demo) ...[
              const Notice(
                title: 'Demo lokal · data contoh',
                color: AppColors.warning,
                icon: 'imgAlertCircle',
                message:
                    'Perubahan hanya disimpan selama aplikasi terbuka. Akun daring belum terhubung.',
              ),
              const PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mahasiswa demo',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8),
                    Text('3 tugas · 540 menit tersisa'),
                    Text('Senin, 9 November 2026 · 18:00 WIB'),
                  ],
                ),
              ),
              const Text(
                'Kontrol memajukan jam hanya ada di Jadwal demo. Bukan waktu perangkat.',
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Buka demo lokal',
                icon: 'imgArrowRight',
                onPressed: widget.auth.enterDemo,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => changeView(_LoginView.login),
                child: const Text('Kembali ke masuk'),
              ),
            ] else if (confirmation) ...[
              Notice(
                title: 'Konfirmasi email diperlukan',
                message:
                    'Buka tautan yang dikirim ke ${email.text.trim()} sebelum masuk.',
              ),
              const Text('Belum menerima email? Periksa folder spam.'),
              ErrorNotice(widget.auth.error),
              AppButton(
                label: pending
                    ? 'Mengirim…'
                    : resent
                    ? 'Email dikirim ulang'
                    : 'Kirim ulang email',
                secondary: true,
                onPressed: pending
                    ? null
                    : () async {
                        setState(() => pending = true);
                        final ok = await widget.auth.resendConfirmation(
                          email.text.trim(),
                        );
                        if (mounted) {
                          setState(() {
                            pending = false;
                            resent = ok;
                          });
                        }
                      },
              ),
              TextButton(
                onPressed: pending ? null : () => changeView(_LoginView.login),
                child: const Text('Kembali ke masuk'),
              ),
            ] else ...[
              if (!widget.auth.isCloud)
                const Notice(
                  title: 'Akun daring belum terhubung',
                  message:
                      'Gunakan demo lokal. Masuk dan daftar tersedia setelah layanan daring dikonfigurasi.',
                  color: AppColors.warning,
                ),
              if (register) ...[
                TextFormField(
                  controller: name,
                  enabled: !pending && widget.auth.isCloud,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(labelText: 'Nama'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Nama wajib diisi.'
                      : null,
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: email,
                enabled: !pending && widget.auth.isCloud,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  suffixIcon: Padding(
                    padding: EdgeInsets.all(14),
                    child: DesignIcon('imgMail', size: 20),
                  ),
                ),
                validator: (v) =>
                    v == null ||
                        !RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(v.trim())
                    ? 'Masukkan alamat email yang valid.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: password,
                enabled: !pending && widget.auth.isCloud,
                obscureText: obscure,
                autofillHints: [
                  register ? AutofillHints.newPassword : AutofillHints.password,
                ],
                onFieldSubmitted: (_) {
                  if (!pending && widget.auth.isCloud) submit();
                },
                decoration: InputDecoration(
                  labelText: 'Kata sandi',
                  helperText: register ? 'Minimal 8 karakter.' : null,
                  suffixIcon: IconButton(
                    tooltip: obscure
                        ? 'Tampilkan kata sandi'
                        : 'Sembunyikan kata sandi',
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: const DesignIcon('imgEyeOff', size: 20),
                  ),
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Kata sandi wajib diisi.'
                    : register && v.length < 8
                    ? 'Minimal 8 karakter.'
                    : null,
              ),
              const SizedBox(height: 16),
              if (pending)
                const Notice(
                  title: 'Sedang memproses…',
                  message: 'Menunggu jawaban layanan. Jangan kirim ulang.',
                ),
              ErrorNotice(widget.auth.error),
              AppButton(
                label: pending
                    ? 'Memeriksa akun…'
                    : register
                    ? 'Daftar'
                    : 'Masuk',
                onPressed: pending || !widget.auth.isCloud ? null : submit,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: register
                    ? 'Sudah punya akun? Masuk'
                    : 'Belum punya akun? Daftar',
                secondary: true,
                onPressed: pending
                    ? null
                    : () => changeView(
                        register ? _LoginView.login : _LoginView.register,
                      ),
              ),
              if (!register && !widget.auth.isCloud) ...[
                const SizedBox(height: 16),
                PaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Ingin melihat dulu?',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Coba contoh lokal. Tidak membuat akun daring dan tidak menyimpan data setelah ditutup.',
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Coba demo lokal',
                        secondary: true,
                        onPressed: pending
                            ? null
                            : () => changeView(_LoginView.demo),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
