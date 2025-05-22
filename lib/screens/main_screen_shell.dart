import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'feed_screen.dart';
import 'daily_progress_screen.dart';
import 'tools_screen.dart';
import 'profile_screen.dart';

class MainScreenShell extends StatefulWidget { // Renamed from MainScreen to MainScreenShell
  const MainScreenShell({super.key});
  @override
  _MainScreenShellState createState() => _MainScreenShellState();
}

class _MainScreenShellState extends State<MainScreenShell> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late TabController _tabController;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (mounted) {
        setState(() {
          _currentIndex = _tabController.index;
        });
      }
    });
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String userDataKey = 'user_data';

    final userDataString = prefs.getString(userDataKey);
    if (userDataString != null) {
      if (mounted) {
        setState(() {
          _userData = jsonDecode(userDataString);
        });
      }
    }
  }

  void updateUserData(Map<String, dynamic> newUserData) {
    setState(() {
      _userData = newUserData.isNotEmpty ? newUserData : null;
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(() {});
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          FeedScreen(userData: _userData),
          DailyProgressScreen(userData: _userData),
          ToolsScreen(userData: _userData),
          ProfileScreen(userData: _userData, updateUserData: updateUserData),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.shadow.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBottomNavItem(context, icon: Icons.feed_outlined, selectedIcon: Icons.feed, label: 'Feed', index: 0),
                _buildBottomNavItem(context, icon: Icons.check_circle_outline, selectedIcon: Icons.check_circle, label: 'Progress', index: 1),
                _buildBottomNavItem(context, icon: Icons.construction_outlined, selectedIcon: Icons.construction, label: 'Tools', index: 2),
                _buildBottomNavItem(context, icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile', index: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(BuildContext context, {required IconData icon, required IconData selectedIcon, required String label, required int index}) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _tabController.animateTo(index),
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isSelected ? selectedIcon : icon, color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}