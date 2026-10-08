import 'package:flutter/material.dart';

import '../services/app_store.dart';
import '../widgets/property_card.dart';
import 'home_page.dart';
import 'property_page.dart';
import 'property_form_page.dart';
import 'profile_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: [
          const HomePage(),
          const PropertyPage(),
          store.loggedIn
              ? const PropertyPage(saved: true)
              : EmptyState(
                  title: 'Таалагдсан байраа хадгалаарай',
                  message: 'Нэвтэрч ороод хадгалсан заруудаа бүх төхөөрөмжөөсөө хараарай.',
                  buttonLabel: 'Нэвтрэх',
                  onRetry: () async {
                    await requireLogin(context);
                  },
                ),
          const ProfilePage(),
        ],
      ),
      floatingActionButton: currentIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () async {
                if (!await requireLogin(context) || !context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PropertyFormPage()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Зар нэмэх'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        height: 72,
        onDestinationSelected: (i) => setState(() => currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Нүүр',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.manage_search),
            label: 'Хайх',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Хадгалсан',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Профайл',
          ),
        ],
      ),
    );
  }
}
