import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../pages/categories_page.dart';
import '../services/firestore_service.dart';
import '../utils/currency_data.dart';

class SettingsPage extends StatelessWidget {
  SettingsPage({super.key});

  final FirestoreService _firestore = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeScope.of(context);
    final theme = Theme.of(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;

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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme color',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pick an accent color for the app.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final option in themeController.colorOptions)
                        Semantics(
                          button: true,
                          selected:
                              option.color == themeController.seedColor,
                          label: option.label,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(28),
                            onTap: () =>
                                themeController.setSeedColor(option.color),
                            child: AnimatedContainer(
                              duration: kThemeAnimationDuration,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: option.color ==
                                          themeController.seedColor
                                      ? theme.colorScheme.primary
                                      : theme.dividerColor,
                                  width:
                                      option.color ==
                                              themeController.seedColor
                                          ? 3
                                          : 1,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: option.color,
                                child: option.color ==
                                        themeController.seedColor
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 18,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Default currency',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Used for new expenses unless you override it.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  if (uid == null)
                    Text(
                      'Sign in to choose a default currency.',
                      style: theme.textTheme.bodySmall,
                    )
                  else
                    StreamBuilder<String>(
                      stream: _firestore.streamDefaultCurrency(uid),
                      builder: (context, snapshot) {
                        final current = snapshot.data ?? defaultCurrencyCode;
                        final normalized = currencyOptionByCode(current).code;
                        return DropdownButtonFormField<String>(
                          value: normalized,
                          isExpanded: true,
                          items: currencyOptions
                              .map(
                                (option) => DropdownMenuItem(
                                  value: option.code,
                                  child: Text('${option.displayLabel} (${option.symbol})'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            _firestore.setDefaultCurrency(uid, value);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                            border: OutlineInputBorder(),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Categories'),
              subtitle: Text(
                uid == null
                    ? 'Sign in to manage categories.'
                    : 'Add, edit, and organize your categories.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: uid == null
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CategoriesPage(uid: uid),
                        ),
                      );
                    },
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
