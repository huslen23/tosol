import 'package:flutter/material.dart';

import '../services/app_store.dart';
import '../widgets/property_card.dart';
import 'property_page.dart';
import 'property_form_page.dart';
import 'password_page.dart';
import 'admin_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool loggingOut = false;
  Future<void> logout() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Гарах уу?'),
        content: const Text(
          'Дахин нэвтэрч хадгалсан байр, заруудаа харах боломжтой.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Гарах'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final store = AppScope.read(context);
    setState(() => loggingOut = true);
    try {
      await store.logout();
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Миний профайл')),
        body: EmptyState(
          title: 'Өргөөнд тавтай морил',
          message: 'Нэвтэрч өөрийн зар, хадгалсан байр, профайлаа удирдаарай.',
          buttonLabel: 'Нэвтрэх / Бүртгүүлэх',
          onRetry: () async {
            await requireLogin(context);
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Миний профайл')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xFF2563EB),
                      child: Icon(Icons.person, size: 36, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Тавтай морилно уу',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${user['last_name']} ${user['first_name']}'.trim(),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${user['email']}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _ProfileTile(
              icon: Icons.person_outline,
              title: 'Профайл засах',
              subtitle: 'Овог, нэр, хэрэглэгчийн нэрээ шинэчлэх',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileEditPage()),
              ),
            ),
            _ProfileTile(
              icon: Icons.home_work_outlined,
              title: 'Миний зарууд',
              subtitle: 'Зараа харах, засах, устгах',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const PropertyPage(mine: true, standalone: true),
                ),
              ),
            ),
            _ProfileTile(
              icon: Icons.favorite_border,
              title: 'Хадгалсан байр',
              subtitle: 'Таалагдсан байрууд нэг дор',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const PropertyPage(saved: true, standalone: true),
                ),
              ),
            ),
            _ProfileTile(
              icon: Icons.add_circle_outline,
              title: 'Зар нэмэх',
              subtitle: 'Худалдах эсвэл түрээслэх',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PropertyFormPage()),
              ),
            ),
            _ProfileTile(
              icon: Icons.lock_outline,
              title: 'Нууц үг солих',
              subtitle: 'Хуучин нууц үгээр шинэчлэх',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PasswordPage()),
              ),
            ),
            _ProfileTile(
              icon: Icons.password,
              title: 'Нууц үг сэргээх',
              subtitle: 'Мартсан бол и-мэйл кодоор сэргээх',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PasswordPage(forgot: true),
                ),
              ),
            ),
            if (AppScope.of(context).isAdmin)
              _ProfileTile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Админ удирдлага',
                subtitle: 'Бүх зар, хотхон, дүүрэг удирдах',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminPage()),
                ),
              ),
            _ProfileTile(
              icon: Icons.info_outline,
              title: 'Өргөөний тухай',
              subtitle: 'Таны мөрөөдлийн байр',
              onTap: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Өргөө • 1.0.0'),
                  content: const Text(
                    'Таны мөрөөдлийн байр.\n\nМонголын үл хөдлөх хөрөнгийг хайх, хадгалах, худалдах, түрээслэх апп.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Хаах'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: loggingOut ? null : logout,
              icon: const Icon(Icons.logout),
              label: Text(loggingOut ? 'Гарч байна...' : 'Гарах'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: const Color(0xFF2563EB)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    ),
  );
}

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});
  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final form = GlobalKey<FormState>();
  final first = TextEditingController(), last = TextEditingController();
  final username = TextEditingController();
  bool initialized = false, saving = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      final user = AppScope.read(context).user!;
      first.text = '${user['first_name']}';
      last.text = '${user['last_name']}';
      username.text = '${user['username'] ?? ''}';
      initialized = true;
    }
  }

  @override
  void dispose() {
    first.dispose();
    last.dispose();
    username.dispose();
    super.dispose();
  }

  String? validate(String? v) => v == null || v.trim().isEmpty
      ? 'Энэ талбарыг бөглөнө үү.'
      : v.trim().length > 150
      ? '150 тэмдэгтээс бага байна.'
      : null;
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final store = AppScope.read(context);
    setState(() => saving = true);
    try {
      store.user = await store.api.request(
        'PATCH',
        'profile/',
        body: {
          'first_name': first.text.trim(),
          'last_name': last.text.trim(),
          'username': username.text.trim(),
        },
      ) as Map<String, dynamic>;
      store.changed();
      if (mounted) {
        showMessage(context, 'Профайл шинэчлэгдлээ.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Профайл засах')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: last,
              enabled: !saving,
              validator: validate,
              decoration: const InputDecoration(labelText: 'Овог'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: first,
              enabled: !saving,
              validator: validate,
              decoration: const InputDecoration(labelText: 'Нэр'),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: username,
              enabled: !saving,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Хэрэглэгчийн нэр'),
              validator: (value) {
                final error = validate(value);
                if (error != null) return error;
                return RegExp(
                      r'^[\p{L}\p{N}_.+\-]+$',
                      unicode: true,
                    ).hasMatch(value!.trim())
                    ? null
                    : 'Үсэг, тоо, _, ., +, - тэмдэг ашиглана уу.';
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'Хадгалж байна...' : 'Хадгалах'),
            ),
          ],
        ),
      ),
    ),
  );
}
