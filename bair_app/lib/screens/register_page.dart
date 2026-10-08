import 'package:flutter/material.dart';

import '../services/app_store.dart';
import '../widgets/property_card.dart';
import 'otp_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final form = GlobalKey<FormState>();
  final firstNameController = TextEditingController(),
      lastNameController = TextEditingController(),
      emailController = TextEditingController(),
      usernameController = TextEditingController(),
      passwordController = TextEditingController(),
      confirmationController = TextEditingController();
  bool loading = false;
  Future<void> register() async {
    if (!form.currentState!.validate()) return;
    final store = AppScope.read(context);
    setState(() => loading = true);
    try {
      final email = emailController.text.trim().toLowerCase();
      await store.api.request(
        'POST',
        'register/',
        body: {
          'email': email,
          'password': passwordController.text,
          'password_confirm': confirmationController.text,
          'username': usernameController.text.trim(),
          'first_name': firstNameController.text.trim(),
          'last_name': lastNameController.text.trim(),
        },
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OtpPage(email: email)),
      );
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String? requiredField(String? value) =>
      value == null || value.trim().isEmpty ? 'Энэ талбарыг бөглөнө үү.' : null;
  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    usernameController.dispose();
    confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Бүртгүүлэх')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.person_add_alt_1,
                size: 64,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(height: 20),
              const Text(
                'Өргөөнд тавтай морил',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'И-мэйл хаягаа кодоор баталгаажуулж бүртгүүлээрэй.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: lastNameController,
                validator: requiredField,
                decoration: const InputDecoration(
                  labelText: 'Овог',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: firstNameController,
                validator: requiredField,
                decoration: const InputDecoration(
                  labelText: 'Нэр',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: usernameController,
                autofillHints: const [AutofillHints.newUsername],
                validator: (v) =>
                    v == null ||
                        v.trim().isEmpty ||
                        v.contains('@') ||
                        v.trim().length > 150
                    ? 'Хэрэглэгчийн нэр оруулна уу. @ тэмдэг ашиглахгүй.'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Хэрэглэгчийн нэр',
                  prefixIcon: Icon(Icons.account_circle_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    v == null ||
                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(v.trim())
                    ? 'И-мэйл хаягаа зөв оруулна уу.'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'И-мэйл',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                validator: (v) => v == null || v.length < 6
                    ? 'Нууц үг хамгийн багадаа 6 тэмдэгт байна.'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Нууц үг',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: confirmationController,
                obscureText: true,
                validator: (v) =>
                    v == null || v.isEmpty || v != passwordController.text
                    ? 'Нууц үг таарахгүй байна.'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Нууц үг давтах',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: loading ? null : register,
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Бүртгүүлэх'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
