import 'package:flutter/material.dart';

import '../models/category_model.dart';
import '../services/firestore_service.dart';

class CategoryPickerPage extends StatefulWidget {
  final String uid;
  final String? selectedId;

  const CategoryPickerPage({
    super.key,
    required this.uid,
    this.selectedId,
  });

  @override
  State<CategoryPickerPage> createState() => _CategoryPickerPageState();
}

class _CategoryPickerPageState extends State<CategoryPickerPage> {
  final FirestoreService _firestore = FirestoreService();

  Future<void> _showUpsertDialog({CategoryModel? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final iconController = TextEditingController(text: existing?.icon ?? '');

    final result = await showDialog<_CategoryDialogResult>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'Add Category' : 'Edit Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name (required)',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: iconController,
                decoration: const InputDecoration(
                  labelText: 'Icon (optional, e.g. 🍔)',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  _CategoryDialogResult(
                    name: nameController.text.trim(),
                    icon: iconController.text.trim(),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    if (result.name.isEmpty) return;

    final icon = result.icon.isEmpty ? null : result.icon;

    try {
      if (existing == null) {
        await _firestore.addCategory(
          widget.uid,
          CategoryModel(id: '', name: result.name, icon: icon),
        );
      } else {
        await _firestore.updateCategory(
          widget.uid,
          existing.id,
          existing.copyWith(name: result.name, icon: icon),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save category: $e')),
      );
    } finally {
      nameController.dispose();
      iconController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            tooltip: 'Add category',
            icon: const Icon(Icons.add),
            onPressed: () => _showUpsertDialog(),
          ),
        ],
      ),
      body: StreamBuilder<List<CategoryModel>>(
        stream: _firestore.streamCategories(widget.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = snapshot.data ?? const <CategoryModel>[];
          if (categories.isEmpty) {
            return const Center(child: Text('No categories yet.'));
          }

          return ListView.separated(
            itemCount: categories.length,
            separatorBuilder: (context, index) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = category.id == widget.selectedId;
              return ListTile(
                leading: CircleAvatar(
                  child: Text(category.icon ?? '🏷️'),
                ),
                title: Text(category.name),
                trailing: isSelected ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(category.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryDialogResult {
  final String name;
  final String icon;

  const _CategoryDialogResult({required this.name, required this.icon});
}
