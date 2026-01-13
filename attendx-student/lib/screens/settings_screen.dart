import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final student = provider.student;
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            centerTitle: false,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Card
                _buildProfileCard(context, student, provider),
                
                const SizedBox(height: 24),
                
                // Settings Sections
                _buildSectionTitle('General'),
                _buildSettingsCard([
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    iconColor: AppColors.primary,
                    iconBgColor: const Color(0xFFEDE9FE),
                    title: 'Notifications',
                    subtitle: 'Manage notification preferences',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.language_rounded,
                    iconColor: const Color(0xFF3B82F6),
                    iconBgColor: const Color(0xFFDBEAFE),
                    title: 'Language',
                    subtitle: 'English',
                    onTap: () {},
                  ),
                ]).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05, end: 0),
                
                const SizedBox(height: 24),
                
                _buildSectionTitle('Support'),
                _buildSettingsCard([
                  _SettingsTile(
                    icon: Icons.help_outline_rounded,
                    iconColor: const Color(0xFF10B981),
                    iconBgColor: const Color(0xFFD1FAE5),
                    title: 'Help & Support',
                    subtitle: 'Get help with AttendX',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    iconBgColor: const Color(0xFFFEF3C7),
                    title: 'About',
                    subtitle: 'Version 1.0.0',
                    onTap: () => _showAboutDialog(context),
                  ),
                ]).animate(delay: 300.ms).fadeIn().slideY(begin: 0.05, end: 0),
                
                const SizedBox(height: 24),
                
                _buildSectionTitle('Account'),
                _buildSettingsCard([
                  _SettingsTile(
                    icon: Icons.logout_rounded,
                    iconColor: AppColors.danger,
                    iconBgColor: AppColors.dangerLight,
                    title: 'Logout',
                    subtitle: 'Sign out of your account',
                    onTap: () => _showLogoutDialog(context, provider),
                    isDestructive: true,
                  ),
                ]).animate(delay: 400.ms).fadeIn().slideY(begin: 0.05, end: 0),
                
                const SizedBox(height: 100),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileCard(BuildContext context, student, AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.sm,
        border: Border.all(color: AppColors.gray100),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                _getInitials(student?.name ?? 'S'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student?.name ?? 'Student',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  student?.studentId ?? 'N/A',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
          
          // Edit button
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              // Edit profile functionality
            },
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.edit_rounded,
                size: 20,
                color: AppColors.gray600,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.gray500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<_SettingsTile> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.sm,
        border: Border.all(color: AppColors.gray100),
      ),
      child: Column(
        children: tiles.asMap().entries.map((entry) {
          final index = entry.key;
          final tile = entry.value;
          final isLast = index == tiles.length - 1;
          
          return Column(
            children: [
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  tile.onTap();
                },
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(16) : Radius.zero,
                  bottom: isLast ? const Radius.circular(16) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: tile.iconBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          tile.icon,
                          color: tile.iconColor,
                          size: 22,
                        ),
                      ),
                      
                      const SizedBox(width: 14),
                      
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tile.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: tile.isDestructive ? AppColors.danger : AppColors.gray900,
                              ),
                            ),
                            if (tile.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                tile.subtitle!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.gray500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.gray400,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
              
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 74,
                  color: AppColors.gray100,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('About AttendX'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.fingerprint_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'AttendX Student',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.gray500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Smart biometric attendance system for modern classrooms.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.gray600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to logout? You\'ll need to re-enter your details to use the app again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await provider.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  (route) => false,
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }
}

class _SettingsTile {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });
}
