import 'package:equatable/equatable.dart';

class Category extends Equatable {
  const Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.icon,
    required this.color,
    this.parentId,
    required this.isSystem,
  });

  final String id;
  final String userId;
  final String name;
  final String icon;
  final String color;
  final String? parentId;
  final bool isSystem;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String? ?? 'category',
      color: json['color'] as String? ?? '#a855f7',
      parentId: json['parent_id'] as String?,
      isSystem: json['is_system'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, name];
}
