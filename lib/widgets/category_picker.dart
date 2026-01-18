import 'package:flutter/material.dart';

import '../models/category_model.dart';
import '../pages/category_picker_page.dart';

class CategoryPicker extends StatelessWidget {
  final String uid;
  final List<CategoryModel> categories;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  const CategoryPicker({
    super.key,
    required this.uid,
    required this.categories,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  CategoryModel? _findCategory(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  Future<void> _openPicker(BuildContext context) async {
    if (!enabled) return;
    final selected = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => CategoryPickerPage(
          uid: uid,
          selectedId: value,
        ),
      ),
    );
    if (selected != null) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _findCategory(value);
    final label =
        selected == null ? 'Choose a category' : '${selected.icon ?? '🏷️'}  ${selected.name}';
    final textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: enabled ? null : Theme.of(context).disabledColor,
        );

    return InkWell(
      onTap: enabled ? () => _openPicker(context) : null,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Category (required)',
          border: OutlineInputBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: textStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.expand_more,
              color: enabled ? null : Theme.of(context).disabledColor,
            ),
          ],
        ),
      ),
    );
  }
}
