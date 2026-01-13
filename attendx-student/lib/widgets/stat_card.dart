import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/constants.dart';

class StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final int delay;

  const StatCard({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.lg,
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.gray500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: delay))
      .fadeIn(duration: 400.ms)
      .slideY(begin: 0.2, end: 0, curve: Curves.easeOut);
  }
}
