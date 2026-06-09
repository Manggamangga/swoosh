import 'package:flutter/material.dart';

class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    super.key,
    required this.iconName,
    required this.color,
    this.size = 44,
  });

  final String iconName;
  final String color;
  final double size;

  static const _iconMap = {
    'shopping_cart': Icons.shopping_cart_outlined,
    'restaurant': Icons.restaurant_outlined,
    'directions_car': Icons.directions_car_outlined,
    'receipt_long': Icons.receipt_long_outlined,
    'subscriptions': Icons.subscriptions_outlined,
    'shopping_bag': Icons.shopping_bag_outlined,
    'movie': Icons.movie_outlined,
    'favorite': Icons.favorite_outline,
    'payments': Icons.payments_outlined,
    'swap_horiz': Icons.swap_horiz,
    'category': Icons.category_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final parsedColor = _parseColor(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: parsedColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _iconMap[iconName] ?? Icons.category_outlined,
        color: parsedColor,
        size: size * 0.45,
      ),
    );
  }

  Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}
