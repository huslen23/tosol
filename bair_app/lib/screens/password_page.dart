import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_store.dart';
import '../widgets/property_card.dart';

class PasswordPage extends StatefulWidget {
  final bool forgot;
  const PasswordPage({super.key, this.forgot = false});
  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), code = TextEditingController();
  final oldPassword = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false;
  String? resetToken;
  String? sentEmail;
  int cooldown = 0;
  Timer? timer;

  @override
  void dispose() {
    timer?.cancel();
    for (final controller in [
      email,
      code,
      oldPassword,
      password,
      confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> sendCode() async {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim())) {
      form.currentState!.validate();
      return;
    }
    final store = AppScope.read(context);
    setState(() => busy = true);
    try {
      final result = await store.api.request(
        'POST',
        'password/forgot/',
        body: {'email': email.text.trim()},
      ) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        resetToken = result['reset_token'] as String;
        sentEmail = email.text.trim();
        cooldown = 60;
      });
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => cooldown--);
        if (cooldown <= 0) t.cancel();
      });
      showMessage(context, result['message']);
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final store = AppScope.read(context);
    setState(() => busy = true);
    try {
      if (widget.forgot) {
        await store.api.request(
          'POST',
          'password/reset/',
          body: {
            'reset_token': resetToken,
            'code': code.text.trim(),
            'new_password': password.text,
            'password_confirm': confirmation.text,
          },
        );
        await store.clearAuthentication();
      } else {
        await store.changePassword(
          oldPassword.text,
          password.text,
          confirmation.text,
        );
      }
      if (mounted) {
        showMessage(
          context,
          widget.forgot
              ? 'Нууц үг сэргээгдлээ. Шинэ нууц үгээр нэвтэрнэ үү.'
              : 'Нууц үг шинэчлэгдлээ.',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget passwordField(
    TextEditingController controller,
    String label,
    String? Function(String?) validator,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !busy,
      obscureText: true,
      decoration: InputDecoration(labelText: label),
      validator: validator,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.forgot ? 'Нууц үг сэргээх' : 'Нууц үг солих'),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.forgot) ...[
              const Text(
                'Бүртгэлтэй и-мэйлдээ код авч шинэ нууц үг тохируулна. Код 10 минут хүчинтэй.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: email,
                enabled: !busy && resetToken == null,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'И-мэйл'),
                validator: (v) =>
                    v == null ||
                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(v.trim())
                    ? 'И-мэйл хаягаа зөв оруулна уу.'
                    : null,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: busy || cooldown > 0 ? null : sendCode,
                child: Text(
                  cooldown > 0
                      ? 'Дахин код авах • $cooldown сек'
                      : resetToken == null
                      ? 'Код авах'
                      : 'Дахин код авах',
                ),
              ),
              if (resetToken != null) ...[
                TextButton(
                  onPressed: busy
                      ? null
                      : () {
                          timer?.cancel();
                          setState(() {
                            resetToken = null;
                            sentEmail = null;
                            cooldown = 0;
                            code.clear();
                          });
                        },
                  child: const Text('Өөр и-мэйл ашиглах'),
                ),
                Text('Код илгээх хаяг: $sentEmail'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: code,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '6 оронтой код'),
                  validator: (v) =>
                      v == null || !RegExp(r'^\d{6}$').hasMatch(v.trim())
                      ? '6 оронтой код оруулна уу.'
                      : null,
                ),
                const SizedBox(height: 16),
              ],
            ] else
              passwordField(
                oldPassword,
                'Хуучин нууц үг',
                (v) => v == null || v.isEmpty
                    ? 'Хуучин нууц үгээ оруулна уу.'
                    : null,
              ),
            if (!widget.forgot || resetToken != null) ...[
              passwordField(
                password,
                'Шинэ нууц үг',
                (v) => v == null || v.length < 6 || v.length > 128
                    ? 'Нууц үг 6–128 тэмдэгттэй байна.'
                    : null,
              ),
              passwordField(
                confirmation,
                'Шинэ нууц үг давтах',
                (v) => v == null || v.isEmpty || v != password.text
                    ? 'Нууц үг таарахгүй байна.'
                    : null,
              ),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Хадгалж байна...' : 'Нууц үг хадгалах'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
