import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/whatsapp_api.dart';
import '../../state/auth_controller.dart';
import '../shared.dart';

class WhatsAppScreen extends StatefulWidget {
  final AuthController auth;
  final WhatsAppApi api;
  const WhatsAppScreen({super.key, required this.auth, required this.api});

  @override
  State<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends State<WhatsAppScreen> {
  final phone = TextEditingController();
  final code = TextEditingController();
  late final String? userId;
  WhatsAppSettings? settings;
  bool busy = false;
  String? error;

  bool get sameAccount =>
      widget.auth.isCloud &&
      widget.auth.signedIn &&
      widget.auth.userId == userId;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_checkAccount);
    userId = widget.auth.userId;
    _update('status');
  }

  void _checkAccount() {
    if (mounted && !sameAccount) {
      setState(() {
        settings = null;
        phone.clear();
        code.clear();
      });
    }
  }

  @override
  void dispose() {
    widget.auth.removeListener(_checkAccount);
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> _update(String action, {bool? enabled}) async {
    if (busy || !sameAccount) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.api.update(
        action,
        phone: action == 'request_code' ? phone.text.trim() : null,
        code: action == 'verify_code' ? code.text.trim() : null,
        enabled: enabled,
      );
      if (!mounted || !sameAccount) return;
      setState(() {
        settings = result;
        if (action != 'status') code.clear();
        if (action == 'request_code') phone.clear();
      });
    } on WhatsAppApiException catch (failure) {
      if (!mounted || !sameAccount) return;
      setState(() {
        settings = failure.settings ?? settings;
        error = switch (failure.code) {
          'invalid_phone' =>
            'Gunakan nomor seluler Indonesia berawalan 08 atau +628.',
          'invalid_code' => 'Masukkan kode 6 digit.',
          'wrong_code' => 'Kode salah. Periksa pesan WhatsApp Anda.',
          'expired' => 'Kode tidak berlaku lagi. Minta kode baru.',
          'attempts_exhausted' => 'Batas percobaan tercapai. Minta kode baru.',
          'rate_limited' =>
            'Tunggu minimal satu menit. Maksimal tiga permintaan per jam.',
          'gateway_unconfirmed' =>
            'Pengiriman kode belum terkonfirmasi. Jika kode tiba, masukkan di sini.',
          'verification_required' =>
            'Verifikasi nomor sebelum mengaktifkan pengingat.',
          'unauthenticated' => 'Sesi berakhir. Masuk kembali.',
          _ => 'Layanan pengingat belum dapat diakses. Coba lagi.',
        };
      });
    } on Exception {
      if (mounted && sameAccount) {
        setState(
          () => error =
              'Koneksi terputus. Muat ulang untuk memeriksa status terbaru.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengingat WhatsApp')),
      body: PageContent(
        children: [
          const PageHeading(
            'Pengingat tenggat',
            'Terima pesan WhatsApp sekitar 24 jam sebelum tenggat tugas yang belum selesai.',
          ),
          if (!sameAccount)
            const Notice(
              title: 'Masuk dengan akun daring untuk menggunakan pengingat.',
            )
          else ...[
            if (busy)
              const LinearProgressIndicator(
                semanticsLabel: 'Memperbarui pengingat',
              ),
            ErrorNotice(error),
            if (!busy && (current == null || error != null))
              TextButton(
                onPressed: () => _update('status'),
                child: const Text('Muat ulang status'),
              ),
            if (current != null) ...[
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(title: 'Nomor penerima'),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: StatusBadge(
                        current.verified
                            ? 'Terverifikasi'
                            : 'Belum terverifikasi',
                        tone: current.verified
                            ? StatusTone.success
                            : StatusTone.warning,
                      ),
                    ),
                    if (current.phone != null) ...[
                      const SizedBox(height: AppLayout.space8),
                      Text(current.phone!),
                    ],
                    const SizedBox(height: AppLayout.space16),
                    TextField(
                      controller: phone,
                      enabled: !busy,
                      keyboardType: TextInputType.phone,
                      maxLength: 40,
                      decoration: InputDecoration(
                        labelText: current.phone == null
                            ? 'Nomor WhatsApp'
                            : 'Ganti nomor WhatsApp',
                        hintText: '08… atau +628…',
                        helperText: current.verified
                            ? 'Mengganti nomor akan mematikan pengingat sampai nomor baru diverifikasi.'
                            : 'Kode dikirim ke nomor ini melalui WhatsApp.',
                      ),
                    ),
                    AppButton(
                      label: 'Kirim kode',
                      onPressed: busy ? null : () => _update('request_code'),
                    ),
                    if (current.awaitingCode) ...[
                      const SizedBox(height: AppLayout.space16),
                      TextField(
                        controller: code,
                        enabled: !busy,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: 'Kode verifikasi',
                        ),
                      ),
                      AppButton(
                        label: 'Verifikasi nomor',
                        onPressed: busy ? null : () => _update('verify_code'),
                      ),
                    ],
                    if (!current.verified && current.phone != null)
                      TextButton(
                        onPressed: busy ? null : () => _update('resend_code'),
                        child: const Text('Kirim ulang kode'),
                      ),
                  ],
                ),
              ),
              PaperCard(
                padding: EdgeInsets.zero,
                child: Material(
                  type: MaterialType.transparency,
                  child: KeyboardFocusOutline(
                    child: SwitchListTile(
                      title: const Text('Aktifkan pengingat'),
                      subtitle: Text(current.enabled ? 'Aktif' : 'Nonaktif'),
                      value: current.enabled,
                      onChanged: busy || !current.verified
                          ? null
                          : (enabled) => _update('enable', enabled: enabled),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
