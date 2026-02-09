import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/category.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _categoriesCollection {
    if (_userId == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(_userId).collection('categories');
  }

  final List<Category> _defaultCategories = [
    // Expenses
    Category.fromIconData(
      id: 'food',
      name: 'Food',
      iconData: Icons.restaurant_rounded,
      type: CategoryType.expense,
      isDefault: true,
    ),
    Category.fromIconData(
      id: 'transport',
      name: 'Transportation',
      iconData: Icons.directions_bus_rounded,
      type: CategoryType.expense,
      isDefault: true,
    ),
    Category.fromIconData(
      id: 'entertainment',
      name: 'Entertainment',
      iconData: Icons.movie_rounded,
      type: CategoryType.expense,
      isDefault: true,
    ),
    Category.fromIconData(
      id: 'shopping',
      name: 'Shopping',
      iconData: Icons.shopping_bag_rounded,
      type: CategoryType.expense,
      isDefault: true,
    ),
    Category.fromIconData(
      id: 'bills',
      name: 'Bills',
      iconData: Icons.receipt_long_rounded,
      type: CategoryType.expense,
      isDefault: true,
    ),
    Category.fromIconData(
      id: 'healthcare',
      name: 'Healthcare',
      iconData: Icons.medical_services_rounded,
      type: CategoryType.expense,
      isDefault: true,
    ),
    Category.fromIconData(
      id: 'education',
      name: 'Education',
      iconData: Icons.school_rounded,
      type: CategoryType.expense,
      isDefault: true,
    ),
    Category.fromIconData(
      id: 'other_exp',
      name: 'Other',
      iconData: Icons.more_horiz_rounded,
      type: CategoryType.expense,
      isDefault: true,
    ),

    // Income
    Category.fromIconData(
      id: 'salary',
      name: 'Salary',
      iconData: Icons.payments_rounded,
      type: CategoryType.income,
      isDefault: true,
    ),
    Category.fromIconData(
      id: 'freelance',
      name: 'Freelance',
      iconData: Icons.work_rounded,
      type: CategoryType.income,
      isDefault: true,
    ),
    Category.fromIconData(
      id: 'investment',
      name: 'Investment',
      iconData: Icons.trending_up_rounded,
      type: CategoryType.income,
      isDefault: true,
    ),
    Category.fromIconData(
      id: 'bonus',
      name: 'Bonus',
      iconData: Icons.card_giftcard_rounded,
      type: CategoryType.income,
      isDefault: true,
    ),
    Category.fromIconData(
      id: 'refund',
      name: 'Refund',
      iconData: Icons.replay_rounded,
      type: CategoryType.income,
      isDefault: true,
    ),
    Category.fromIconData(
      id: 'other_inc',
      name: 'Other',
      iconData: Icons.more_horiz_rounded,
      type: CategoryType.income,
      isDefault: true,
    ),
  ];

  Future<List<Category>> getCategories() async {
    try {
      final snapshot = await _categoriesCollection.get();

      if (snapshot.docs.isEmpty) {
        // Initialize with default categories if empty
        for (var cat in _defaultCategories) {
          await _categoriesCollection.doc(cat.id).set(cat.toJson());
        }
        return _defaultCategories;
      }

      final result = snapshot.docs.map((doc) {
        return Category.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();
      print('DEBUG: Fetched ${result.length} categories from Firestore');
      return result;
    } catch (e) {
      print('Error fetching categories: $e');
      return _defaultCategories;
    }
  }

  Future<void> addCategory(Category category) async {
    print('DEBUG: Adding category: ${category.name} with ID: ${category.id}');
    await _categoriesCollection.doc(category.id).set(category.toJson());
    print('DEBUG: Category added successfully');
  }

  Future<void> deleteCategory(String id) async {
    await _categoriesCollection.doc(id).delete();
  }
}
