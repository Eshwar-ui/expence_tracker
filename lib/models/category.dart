import 'package:flutter/material.dart';

enum CategoryType { income, expense }

class Category {
  final String id;
  final String name;
  final int iconCode;
  final CategoryType type;
  final bool isDefault;

  static final Map<int, IconData> _materialIconsByCodePoint = {
    Icons.restaurant_rounded.codePoint: Icons.restaurant_rounded,
    Icons.directions_bus_rounded.codePoint: Icons.directions_bus_rounded,
    Icons.movie_rounded.codePoint: Icons.movie_rounded,
    Icons.shopping_bag_rounded.codePoint: Icons.shopping_bag_rounded,
    Icons.receipt_long_rounded.codePoint: Icons.receipt_long_rounded,
    Icons.medical_services_rounded.codePoint: Icons.medical_services_rounded,
    Icons.school_rounded.codePoint: Icons.school_rounded,
    Icons.more_horiz_rounded.codePoint: Icons.more_horiz_rounded,
    Icons.payments_rounded.codePoint: Icons.payments_rounded,
    Icons.work_rounded.codePoint: Icons.work_rounded,
    Icons.trending_up_rounded.codePoint: Icons.trending_up_rounded,
    Icons.card_giftcard_rounded.codePoint: Icons.card_giftcard_rounded,
    Icons.replay_rounded.codePoint: Icons.replay_rounded,
    Icons.home_rounded.codePoint: Icons.home_rounded,
    Icons.electrical_services_rounded.codePoint:
        Icons.electrical_services_rounded,
    Icons.water_drop_rounded.codePoint: Icons.water_drop_rounded,
    Icons.fitness_center_rounded.codePoint: Icons.fitness_center_rounded,
    Icons.pets_rounded.codePoint: Icons.pets_rounded,
    Icons.flight_rounded.codePoint: Icons.flight_rounded,
    Icons.sports_esports_rounded.codePoint: Icons.sports_esports_rounded,
    Icons.category.codePoint: Icons.category,
    Icons.category_rounded.codePoint: Icons.category_rounded,
  };

  Category({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.type,
    this.isDefault = false,
  });

  // Keep release icon tree-shaking enabled by returning predefined IconData.
  IconData get icon =>
      _materialIconsByCodePoint[iconCode] ?? Icons.category_rounded;

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
