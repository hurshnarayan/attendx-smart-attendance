import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/models.dart';
import '../utils/constants.dart';

class HistoryItem extends StatelessWidget {
  final AttendanceRecord record;
  final int delay;

  const HistoryItem({
    super.key,
    required this.record,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.sm,
        border: Border.all(color: AppColors.gray100),
      ),
      child: Row(
        children: [
          // Status Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getStatusBgColor(),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _getStatusIcon(),
              color: _getStatusColor(),
              size: 24,
            ),
          ),
          
          const SizedBox(width: 14),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.classId ?? 'Class',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(record.time),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
          
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusBgColor(),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getStatusText(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getStatusColor(),
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: delay))
      .fadeIn(duration: 300.ms)
      .slideX(begin: 0.05, end: 0);
  }

  Color _getStatusColor() {
    if (record.isPresent) return AppColors.success;
    if (record.isFlagged) return AppColors.warning;
    return AppColors.gray500;
  }

  Color _getStatusBgColor() {
    if (record.isPresent) return AppColors.successLight;
    if (record.isFlagged) return AppColors.warningLight;
    return AppColors.gray100;
  }

  IconData _getStatusIcon() {
    if (record.isPresent) return Icons.check_rounded;
    if (record.isFlagged) return Icons.warning_rounded;
    return Icons.access_time_rounded;
  }

  String _getStatusText() {
    if (record.isPresent) return 'Present';
    if (record.isFlagged) return 'Flagged';
    return 'Pending';
  }

  String _formatDateTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inDays == 0) {
      final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
      final period = time.hour >= 12 ? 'PM' : 'AM';
      final minute = time.minute.toString().padLeft(2, '0');
      return 'Today, $hour:$minute $period';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[time.month - 1]} ${time.day}';
    }
  }
}
