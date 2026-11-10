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
            FocusPanel(
              eyebrow: 'WAKTUTUGAS / STUDIO FOKUS',
              icon: 'imgCalendarAction',
              title: demo
                  ? 'Coba ritme\nbelajar Anda.'
                  : register
                  ? 'Buka ruang\nuntuk fokus.'
                  : confirmation
                  ? 'Periksa\nkotak masuk.'
                  : 'Tugas tertata.\nPikiran lega.',
              description: demo
                  ? 'Jelajahi perencanaan dengan data contoh, tanpa membuat akun.'
                  : register
                  ? 'Satu tempat untuk tugas kuliah, waktu luang, dan sesi pengerjaan.'
                  : confirmation
                  ? 'Buka tautan konfirmasi yang kami kirim sebelum masuk.'
                  : 'Atur yang perlu dikerjakan. Temukan waktu yang benar-benar tersedia.',
            ),
            if (demo) ...[
              const Notice(
                title: 'Demo lokal · data contoh',
                color: AppColors.warning,
                icon: 'imgAlertCircle',
                message:
                    'Perubahan hanya disimpan selama aplikasi terbuka. Akun daring belum terhubung.',
              ),
              PaperCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const DesignIcon(
                            'imgUserCircle',
                            size: 22,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mahasiswa demo',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '3 tugas · 540 menit tersisa',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    const Row(
                      children: [
                        DesignIcon(
                          'imgCalendar',
                          size: 15,
                          color: AppColors.inkMuted,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Senin, 9 November 2026 · 18:00 WIB',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.inkSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Text(
                'Kontrol memajukan jam hanya ada di Jadwal demo. Bukan waktu perangkat.',
                style: TextStyle(fontSize: 12, color: AppColors.inkSecondary),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Buka demo lokal',
                icon: 'imgArrowRight',
                onPressed: widget.auth.enterDemo,
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => changeView(_LoginView.login),
                  child: const Text('Kembali ke masuk'),
                ),
              ),
            ] else if (confirmation) ...[
              Notice(
                title: 'Konfirmasi email diperlukan',
                message:
                    'Buka tautan yang dikirim ke ${email.text.trim()} sebelum masuk.',
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Belum menerima email? Periksa folder spam.',
                  style: TextStyle(fontSize: 13, color: AppColors.inkSecondary),
                ),
              ),
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
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: pending
                      ? null
                      : () => changeView(_LoginView.login),
                  child: const Text('Kembali ke masuk'),
                ),
              ),
            ] else ...[
              if (!widget.auth.isCloud)
                const Notice(
                  title: 'Akun daring belum terhubung',
                  message:
                      'Gunakan demo lokal. Masuk dan daftar tersedia setelah layanan daring dikonfigurasi.',
                  color: AppColors.warning,
                  icon: 'imgAlertCircle',
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                      const SizedBox(height: 12),
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
                          child: DesignIcon(
                            'imgMail',
                            size: 20,
                            color: AppColors.inkSecondary,
                          ),
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
                        register
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
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
                          icon: const DesignIcon(
                            'imgEyeOff',
                            size: 20,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Kata sandi wajib diisi.'
                          : register && v.length < 8
                          ? 'Minimal 8 karakter.'
                          : null,
                    ),
                  ],
                ),
              ),
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
              const SizedBox(height: 10),
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
                  color: AppColors.surfaceMuted,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Ingin melihat dulu?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Coba contoh lokal. Tidak membuat akun daring dan tidak menyimpan data setelah ditutup.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSecondary,
                        ),
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
