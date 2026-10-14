import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme.dart';
import 'about_tab.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _kDark = 'settings_dark_appearance';
  static const _kNotifications = 'settings_notifications';
  static const _kPrivateProfile = 'settings_private_profile';
  static const _kAppLock = 'settings_app_lock';

  bool _darkAppearance = true;
  bool _notifications = true;
  bool _privateProfile = false;
  bool _appLock = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _darkAppearance = prefs.getBool(_kDark) ?? true;
      _notifications = prefs.getBool(_kNotifications) ?? true;
      _privateProfile = prefs.getBool(_kPrivateProfile) ?? false;
      _appLock = prefs.getBool(_kAppLock) ?? false;
      _loaded = true;
    });
  }

  Future<void> _persist(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 9),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: AppColors.background,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _section('Appearance', [
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark appearance'),
                subtitle: const Text('Use the Alight Creators dark theme'),
                value: _darkAppearance,
                onChanged: (value) {
                  setState(() => _darkAppearance = value);
                  _persist(_kDark, value);
                },
              ),
            ]),
            const SizedBox(height: 22),
            _section('Notifications', [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('Tutorial notifications'),
                subtitle: const Text('Hear about new lessons and updates'),
                value: _notifications,
                onChanged: (value) {
                  setState(() => _notifications = value);
                  _persist(_kNotifications, value);
                },
              ),
            ]),
            const SizedBox(height: 22),
            _section('Privacy & Security', [
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off_outlined),
                title: const Text('Private profile'),
                subtitle: const Text('Limit who can view your profile'),
                value: _privateProfile,
                onChanged: (value) {
                  setState(() => _privateProfile = value);
                  _persist(_kPrivateProfile, value);
                },
              ),
              const Divider(height: 1, color: AppColors.border),
              SwitchListTile(
                secondary: const Icon(Icons.lock_outline),
                title: const Text('App lock'),
                subtitle: const Text('Require device authentication to open'),
                value: _appLock,
                onChanged: (value) {
                  setState(() => _appLock = value);
                  _persist(_kAppLock, value);
                },
              ),
            ]),
            const SizedBox(height: 22),
            _section('Information', [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About Alight Creators'),
                subtitle: const Text('Learn more about the community'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}