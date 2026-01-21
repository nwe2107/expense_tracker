import 'package:flutter/material.dart';

import 'profile_page.dart';
import 'tabs/home_tab.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Profile',
          icon: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.person,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            );
          },
        ),
        title: const Text('Expense Tracker'),
      ),
      body: const HomeTab(),
    );
  }
}
