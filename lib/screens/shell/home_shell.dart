import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/tutorial.dart';
import '../../theme.dart';
import '../../widgets/brand_mark.dart';
import '../tabs/contact_tab.dart';
import '../tabs/home_tab.dart';
import '../tabs/post_tab.dart';
import '../tabs/profile_tab.dart';
import '../tabs/tutorials_tab.dart';
import '../tutorial/tutorial_detail_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _openTutorial(Tutorial t) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TutorialDetailScreen(tutorialId: t.tutorialId!),
    ));
  }

  void _openPost() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _PostPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      HomeTab(onOpenTutorial: _openTutorial),
      TutorialsTab(onOpenTutorial: _openTutorial),
      const ContactTab(),
      const ProfileTab(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_index != 0) {
          setState(() => _index = 0);
          return;
        }
        await SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          titleSpacing: 16,
          title: const BrandMark(fontSize: 20, iconSize: 30),
        ),
        body: SafeArea(
          top: false,
          child: IndexedStack(index: _index, children: tabs),
        ),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.centerDocked,
        floatingActionButton: SizedBox(
          width: 58,
          height: 58,
          child: FloatingActionButton(
            onPressed: _openPost,
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.background,
            elevation: 6,
            shape: const CircleBorder(),
            tooltip: 'Post Tutorial',
            child: const Icon(Icons.add, size: 30),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          color: AppColors.surface,
          elevation: 0,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavItem(
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home,
                        selected: _index == 0,
                        onTap: () => setState(() => _index = 0),
                      ),
                      _NavItem(
                        icon: Icons.play_circle_outline,
                        activeIcon: Icons.play_circle_fill,
                        selected: _index == 1,
                        onTap: () => setState(() => _index = 1),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavItem(
                        icon: Icons.mail_outline,
                        activeIcon: Icons.mail,
                        selected: _index == 2,
                        onTap: () => setState(() => _index = 2),
                      ),
                      _NavItem(
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        selected: _index == 3,
                        onTap: () => setState(() => _index = 3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Icon(
          selected ? activeIcon : icon,
          size: 26,
          color: selected ? AppColors.accent : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _PostPage extends StatelessWidget {
  const _PostPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Add Tutorial',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: const SafeArea(top: false, child: PostTab()),
    );
  }
}