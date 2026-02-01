import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/pushin_app_controller.dart';
import '../../state/auth_state_provider.dart';
import '../screens/enhanced_dashboard_screen.dart';
import '../screens/enhanced_workouts_screen.dart';
import '../screens/enhanced_settings_screen.dart';
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
  late int _selectedIndex;
  bool _hasInitializedForAuthUser = false;

  @override
  void initState() {
    super.initState();

    // Start on Home/Dashboard tab
    _selectedIndex = 1; // Home/Dashboard tab

    // Check if we need to reset to home tab for newly authenticated users
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForNewUserReset();
      _checkPendingWorkoutNavigation();
      _setupWorkoutIntentCallback();
    });
  }

  void _checkForNewUserReset() {
    final authProvider = Provider.of<AuthStateProvider>(context, listen: false);

    print('🏠 MainTabNavigation: Checking for new user reset');
    print('   - isAuthenticated: ${authProvider.isAuthenticated}');
    print('   - _hasInitializedForAuthUser: $_hasInitializedForAuthUser');
    print('   - current _selectedIndex: $_selectedIndex');

    // If user is authenticated and we haven't initialized for auth user yet,
    // and we're not already on the home tab, reset to home
    if (authProvider.isAuthenticated &&
        !_hasInitializedForAuthUser &&
        _selectedIndex != 1) {
      print(
          '🏠 MainTabNavigation: Resetting to home tab for new authenticated user');
      _hasInitializedForAuthUser = true;
      if (mounted) {
        setState(() {
          _selectedIndex = 1; // Home/Dashboard tab
        });
      }
    } else if (authProvider.isAuthenticated) {
      print(
          '🏠 MainTabNavigation: User is authenticated, marking as initialized');
      _hasInitializedForAuthUser =
          true; // Mark as initialized even if already on home
    } else {
      print('🏠 MainTabNavigation: User not authenticated, no reset needed');
    }
  }

  @override
  void dispose() {
    super.dispose();
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
      EnhancedDashboardScreen(
          key: ValueKey('dashboard_${_selectedIndex == 1}')),
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
