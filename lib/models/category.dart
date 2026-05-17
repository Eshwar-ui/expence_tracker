import 'package:flutter/material.dart';

enum CategoryType { income, expense }

class Category {
  final String id;
  final String name;
  final int iconCode;
  final CategoryType type;
  final bool isDefault;

  Category({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.type,
    this.isDefault = false,
  });

  // Helper to get IconData
  IconData get icon {
    return IconData(iconCode, fontFamily: 'MaterialIcons');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconCode': iconCode,
      'type': type.name,
      'isDefault': isDefault,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      iconCode: json['iconCode'] as int? ?? Icons.category.codePoint,
      type: CategoryType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CategoryType.expense,
      ),
      isDefault: json['isDefault'] ?? false,
    );
  }

  // Helper factory to create from IconData
  factory Category.fromIconData({
    required String id,
    required String name,
    required IconData iconData,
    required CategoryType type,
    bool isDefault = false,
  }) {
    return Category(
      id: id,
      name: name,
      iconCode: iconData.codePoint,
      type: type,
      isDefault: isDefault,
    );
  }
}
