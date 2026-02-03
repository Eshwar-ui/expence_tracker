import 'package:flutter/material.dart';

enum CategoryType { income, expense }

class Category {
  final String id;
  final String name;
  final IconData icon;
  final CategoryType type;
  final bool isDefault;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconCode': icon.codePoint,
      'iconFamily': icon.fontFamily,
      'iconPackage': icon.fontPackage,
      'type': type.name,
      'isDefault': isDefault,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      icon: IconData(
        json['iconCode'],
        fontFamily: json['iconFamily'],
        fontPackage: json['iconPackage'],
      ),
      type: CategoryType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CategoryType.expense,
      ),
      isDefault: json['isDefault'] ?? false,
    );
  }
}
