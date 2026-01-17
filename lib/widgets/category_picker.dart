import 'package:flutter/material.dart';

import '../models/category_model.dart';

class CategoryPicker extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  const CategoryPicker({
    super.key,
    required this.categories,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey(value ?? ''),
      initialValue: value,
      items: categories
          .map(
            (c) => DropdownMenuItem(
              value: c.id,
              child: Text('${c.icon ?? '🏷️'}  ${c.name}'),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
      decoration: const InputDecoration(
        labelText: 'Category (required)',
        border: OutlineInputBorder(),
      ),
    );
  }
}
