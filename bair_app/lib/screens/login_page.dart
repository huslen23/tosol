import 'package:flutter/material.dart';

import '../services/app_store.dart';
import '../widgets/property_card.dart';
import '../widgets/brand.dart';
import 'register_page.dart';
import 'password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false, hidden = true;
  Future<void> login() async {
    if (!_form.currentState!.validate()) return;
    final store = AppScope.read(context);
    setState(() => loading = true);
    try {
      await store.login(emailController.text, passwordController.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Нэвтрэх')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 36),
              const Center(child: BrandMark(size: 66)),
              const SizedBox(height: 16),
              const Text(
                'Өргөө',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Таны мөрөөдлийн байр', textAlign: TextAlign.center),
              const SizedBox(height: 40),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.text,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(
                  labelText: 'Хэрэглэгчийн нэр эсвэл и-мэйл',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Хэрэглэгчийн нэр эсвэл и-мэйл оруулна уу.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: hidden,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Нууц үг',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: hidden ? 'Нууц үг харах' : 'Нууц үг нуух',
                    onPressed: () => setState(() => hidden = !hidden),
                    icon: Icon(
                      hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Нууц үгээ оруулна уу.' : null,
                onFieldSubmitted: (_) {
                  if (!loading) login();
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: loading ? null : login,
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Нэвтрэх'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: loading
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PasswordPage(forgot: true),
                        ),
                      ),
                child: const Text('Нууц үгээ мартсан уу?'),
              ),
              TextButton(
                onPressed: loading
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      ),
                child: const Text('Бүртгэлгүй юу? Бүртгүүлэх'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
