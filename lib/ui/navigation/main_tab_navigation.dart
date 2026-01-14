import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/pushin_app_controller.dart';
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

  @override
  void initState() {
    super.initState();
    // Check for pending workout navigation from iOS shield action
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingWorkoutNavigation();
      _setupWorkoutIntentCallback();
    });
  }

  void _setupWorkoutIntentCallback() {
    final controller = Provider.of<PushinAppController>(context, listen: false);
    // Set up callback for workout navigation from intents/shield actions
    controller.onStartWorkoutFromIntent = (blockedApp) {
      debugPrint('🏋️ Received workout intent callback');
      if (mounted) {
        setState(() {
          _selectedIndex = 0; // Switch to Workouts tab
        });
      }
    };
  }

  void _checkPendingWorkoutNavigation() {
    final controller = Provider.of<PushinAppController>(context, listen: false);
    if (controller.consumePendingWorkoutNavigation()) {
      debugPrint('🏋️ Navigating to Workouts tab from shield action');
      setState(() {
        _selectedIndex = 0; // Switch to Workouts tab
      });
    }
  }

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
