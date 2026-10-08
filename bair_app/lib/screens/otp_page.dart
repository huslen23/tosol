import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_store.dart';
import '../widgets/property_card.dart';

class OtpPage extends StatefulWidget {
  final String email;
  const OtpPage({super.key, required this.email});
  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final otpController = TextEditingController();
  bool loading = false, resendLoading = false;
  int cooldown = 60;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (cooldown > 0) {
        setState(() => cooldown--);
      } else {
        timer?.cancel();
      }
    });
  }

  Future<void> verifyOtp() async {
    if (!RegExp(r'^\d{6}$').hasMatch(otpController.text)) {
      showMessage(context, '6 оронтой кодоо оруулна уу.');
      return;
    }
    final store = AppScope.read(context);
    setState(() => loading = true);
    try {
      await store.api.request(
        'POST',
        'verify/',
        body: {'email': widget.email, 'otp': otpController.text},
      );
      if (!mounted) return;
      showMessage(context, 'Бүртгэл баталгаажлаа. Одоо нэвтэрнэ үү.');
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.pop();
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resendOtp() async {
    final store = AppScope.read(context);
    setState(() => resendLoading = true);
    try {
      await store.api.request(
        'POST',
        'resend-otp/',
        body: {'email': widget.email},
      );
      if (!mounted) return;
      otpController.clear();
      setState(() => cooldown = 60);
      startTimer();
      showMessage(context, 'Шинэ код илгээгдлээ.');
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => resendLoading = false);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('И-мэйл баталгаажуулах')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 50),
            const Icon(
              Icons.mark_email_read_outlined,
              size: 80,
              color: Color(0xFF2563EB),
            ),
            const SizedBox(height: 24),
            const Text(
              'Таны код ирсэн үү?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(widget.email, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'И-мэйлээр ирсэн 6 оронтой кодыг оруулна уу. Код 10 минут хүчинтэй.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, letterSpacing: 10),
              decoration: const InputDecoration(
                labelText: 'Баталгаажуулах код',
              ),
              onSubmitted: (_) {
                if (!loading) verifyOtp();
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: loading || resendLoading ? null : verifyOtp,
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Баталгаажуулах'),
            ),
            TextButton(
              onPressed: resendLoading || loading || cooldown > 0
                  ? null
                  : resendOtp,
              child: Text(
                resendLoading
                    ? 'Илгээж байна...'
                    : cooldown > 0
                    ? 'Дахин илгээх • $cooldown сек'
                    : 'Код дахин илгээх',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
