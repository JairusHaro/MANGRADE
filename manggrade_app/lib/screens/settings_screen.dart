import 'package:flutter/material.dart';
import '../services/history_store.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool saveHistory = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SettingTile(
            title: 'Camera Settings',
            subtitle: 'Capture and image quality preferences',
            trailing: Icon(Icons.chevron_right_rounded),
          ),
          const _SettingTile(
            title: 'Storage & Data',
            subtitle: 'Offline history and local storage',
            trailing: Icon(Icons.chevron_right_rounded),
          ),
          _SettingTile(
            title: 'Save classification history',
            subtitle: 'Store results on this device',
            trailing: Switch(
              value: saveHistory,
              activeTrackColor: AppColors.green,
              onChanged: null,
            ),
            onTap: () => setState(() => saveHistory = !saveHistory),
          ),
          const _SettingTile(
            title: 'Theme',
            subtitle: 'Application appearance',
            trailing: Text(
              'Light',
              style: TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const _SettingTile(
            title: 'Language',
            subtitle: 'Interface language',
            trailing: Text(
              'English',
              style: TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HistoryStore.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Demo history cleared.')),
                );
              },
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Text(
                      'Clear classification history',
                      style: TextStyle(
                        color: AppColors.reject,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.reject,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MangGrade',
                  style: TextStyle(
                    color: AppColors.green,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Version 1.0 • Offline research prototype',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'MobileNetV3 + PNS/BAFS 13:2024 visual grading reference',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}
