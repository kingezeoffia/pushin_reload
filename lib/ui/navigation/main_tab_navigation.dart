import 'package:flutter/material.dart';
import '../screens/enhanced_dashboard_screen.dart';
import '../screens/enhanced_workouts_screen.dart';
import '../screens/enhanced_settings_screen.dart';
import '../widgets/DevTools.dart'; // TEMPORARY: Remove before production
import '../widgets/pill_navigation_bar.dart';

/// Main tab navigation with bottom 3-tab bar
/// - Left: Workouts (configurable workouts with Cozy/Normal/Tuff modes)
/// - Center: Home/Dashboard (analytics & streak tracking)
/// - Right: Settings & Profile (app personalization)
class MainTabNavigation extends StatefulWidget {
  const MainTabNavigation({super.key});

  @override
  State<MainTabNavigation> createState() => _MainTabNavigationState();
}

class _MainTabNavigationState extends State<MainTabNavigation> {
  int _selectedIndex = 1; // Default to Home/Dashboard (center tab)

  // Create screens with unique keys to trigger animations on tab switch
  List<Widget> _getScreens() {
    return [
      EnhancedWorkoutsScreen(key: ValueKey('workouts_${_selectedIndex == 0}')),
      EnhancedDashboardScreen(key: ValueKey('dashboard_${_selectedIndex == 1}')),
      EnhancedSettingsScreen(key: ValueKey('settings_${_selectedIndex == 2}')),
    ];
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full screen content
          IndexedStack(
            index: _selectedIndex,
            children: _getScreens(),
          ),
          // TEMPORARY: Development tools - REMOVE BEFORE PRODUCTION
          DevTools(),
          // Pill navigation at the bottom - now self-positioned
          PillNavigationBar(
            selectedIndex: _selectedIndex,
            onTabChanged: _onTabTapped,
          ),
        ],
      ),
    );
  }
}
