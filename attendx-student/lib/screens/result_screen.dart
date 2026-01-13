import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import 'home_screen.dart';

class ResultScreen extends StatefulWidget {
  final AttendanceResult result;
  final bool usedFallback;

  const ResultScreen({
    super.key, 
    required this.result,
    this.usedFallback = false,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.result.success) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.vibrate();
    }
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.result.success) {
      if (widget.result.isFlagged) {
        return _buildFlaggedScreen();
      }
      return _buildSuccessScreen();
    }
    return _buildErrorScreen();
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            
            // Confetti placeholder (animated circles)
            Stack(
              alignment: Alignment.center,
              children: [
                // Ripple effects
                ...List.generate(3, (index) => 
                  Container(
                    width: 180 + (index * 40),
                    height: 180 + (index * 40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.success.withOpacity(0.2 - (index * 0.05)),
                        width: 2,
                      ),
                    ),
                  ).animate(delay: Duration(milliseconds: 200 + (index * 150)))
                    .scale(begin: const Offset(0.8, 0.8), duration: 600.ms)
                    .fadeIn(),
                ),
                
                // Main icon
                Container(
                  width: 140,
                  height: 140,
                  decoration: const BoxDecoration(
                    color: AppColors.successLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 72,
                    color: AppColors.success,
                  ),
                ).animate()
                  .scale(begin: const Offset(0, 0), duration: 500.ms, curve: Curves.easeOutBack),
              ],
            ),
            
            const SizedBox(height: 40),
            
            // Title
            const Text(
              'Attendance Marked!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.gray900,
              ),
            ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.2, end: 0),
            
            const SizedBox(height: 12),
            
            // Subtitle
            Text(
              'You\'re all set for this class',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.gray500,
              ),
            ).animate(delay: 500.ms).fadeIn(),
            
            const SizedBox(height: 48),
            
            // Details card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Status', 'Present', AppColors.success),
                    const Divider(height: 24, color: AppColors.gray200),
                    _buildDetailRow('Student ID', widget.result.studentId ?? 'N/A', AppColors.gray900),
                    const Divider(height: 24, color: AppColors.gray200),
                    _buildDetailRow('Time', _formatTime(DateTime.now()), AppColors.gray900),
                  ],
                ),
              ),
            ).animate(delay: 600.ms).fadeIn().slideY(begin: 0.1, end: 0),
            
            const Spacer(flex: 3),
            
            // Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _goHome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ).animate(delay: 700.ms).fadeIn(),
          ],
        ),
      ),
    );
  }

  Widget _buildFlaggedScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            
            // Warning icon
            Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                color: AppColors.warningLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_rounded,
                size: 72,
                color: AppColors.warning,
              ),
            ).animate()
              .scale(begin: const Offset(0, 0), duration: 500.ms, curve: Curves.easeOutBack)
              .then()
              .shake(duration: 400.ms, hz: 3),
            
            const SizedBox(height: 40),
            
            const Text(
              'Attendance Flagged',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.gray900,
              ),
            ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.2, end: 0),
            
            const SizedBox(height: 12),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                widget.usedFallback 
                    ? 'You used device PIN/pattern instead of biometric. Your attendance requires teacher approval.'
                    : 'Your attendance was recorded but flagged for review. This usually happens when using a different device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.gray500,
                  height: 1.5,
                ),
              ),
            ).animate(delay: 500.ms).fadeIn(),
            
            const SizedBox(height: 48),
            
            // Details card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.warningLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Status', 'Pending Approval', AppColors.warning),
                    const Divider(height: 24, color: AppColors.warning),
                    _buildDetailRow(
                      'Reason', 
                      widget.usedFallback ? 'Used PIN/pattern fallback' : 'Different device detected', 
                      AppColors.gray700
                    ),
                    const Divider(height: 24, color: AppColors.warning),
                    _buildDetailRow('Next Step', 'Teacher will approve', AppColors.gray700),
                  ],
                ),
              ),
            ).animate(delay: 600.ms).fadeIn().slideY(begin: 0.1, end: 0),
            
            const Spacer(flex: 3),
            
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _goHome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Got It',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ).animate(delay: 700.ms).fadeIn(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            
            // Error icon
            Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                color: AppColors.dangerLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 72,
                color: AppColors.danger,
              ),
            ).animate()
              .scale(begin: const Offset(0, 0), duration: 500.ms, curve: Curves.easeOutBack)
              .then()
              .shake(duration: 400.ms, hz: 4),
            
            const SizedBox(height: 40),
            
            const Text(
              'Attendance Failed',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.gray900,
              ),
            ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.2, end: 0),
            
            const SizedBox(height: 12),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                widget.result.error ?? 'Something went wrong. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.gray500,
                  height: 1.5,
                ),
              ),
            ).animate(delay: 500.ms).fadeIn(),
            
            const Spacer(flex: 3),
            
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Try Again',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  TextButton(
                    onPressed: _goHome,
                    child: const Text(
                      'Go Home',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray500,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate(delay: 600.ms).fadeIn(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.gray500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}
