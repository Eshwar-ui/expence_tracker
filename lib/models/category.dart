import 'package:flutter/material.dart';

enum CategoryType { income, expense }

class Category {
  final String id;
  final String name;
  final int iconCode;
  final String? iconFontFamily;
  final String? iconFontPackage;
  final CategoryType type;
  final bool isDefault;

  Category({
    required this.id,
    required this.name,
    required this.iconCode,
    this.iconFontFamily,
    this.iconFontPackage,
    required this.type,
    this.isDefault = false,
  });

  // Helper to get IconData
  IconData get icon {
    if (iconFontFamily == null && iconFontPackage == null) {
      return IconData(iconCode, fontFamily: 'MaterialIcons');
    } else if (iconFontPackage == null) {
      return IconData(iconCode, fontFamily: iconFontFamily);
    } else if (iconFontFamily == null) {
      return IconData(iconCode, fontPackage: iconFontPackage);
    } else {
      return IconData(iconCode,
          fontFamily: iconFontFamily, fontPackage: iconFontPackage);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconCode': iconCode,
      'iconFamily': iconFontFamily,
      'iconPackage': iconFontPackage,
      'type': type.name,
      'isDefault': isDefault,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      iconCode: json['iconCode'] as int? ?? Icons.category.codePoint,
      iconFontFamily: json['iconFamily'] as String?,
      iconFontPackage: json['iconPackage'] as String?,
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
      iconFontFamily: iconData.fontFamily,
      iconFontPackage: iconData.fontPackage,
      type: type,
      isDefault: isDefault,
    );
  }
}
