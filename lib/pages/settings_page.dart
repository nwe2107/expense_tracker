import 'package:flutter/material.dart';

import '../main.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('Dark mode'),
              subtitle: Text(
                themeController.isDarkMode
                    ? 'Use a dark theme'
                    : 'Use a light theme',
              ),
              secondary: Icon(
                themeController.isDarkMode
                    ? Icons.dark_mode
                    : Icons.light_mode,
              ),
              value: themeController.isDarkMode,
              onChanged: themeController.setDarkMode,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'More settings coming soon.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
