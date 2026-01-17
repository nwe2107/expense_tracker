import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id;
  final String name;
  final String? icon;
  final int? color;
  final int? order;

  const CategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.order,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (order != null) 'order': order,
    };
  }

  factory CategoryModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return CategoryModel(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      icon: data['icon'] as String?,
      color: (data['color'] as num?)?.toInt(),
      order: (data['order'] as num?)?.toInt(),
    );
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? icon,
    int? color,
    int? order,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      order: order ?? this.order,
    );
  }
}

