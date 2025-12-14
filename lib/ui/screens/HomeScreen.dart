import 'package:flutter/material.dart';
import '../view_models/HomeViewModel.dart';
import '../models/HomeUIState.dart';
import '../widgets/LockedContentView.dart';
import '../widgets/EarningContentView.dart';
import '../widgets/UnlockedContentView.dart';
import '../widgets/ExpiredContentView.dart';

/// HomeScreen - Main UI Container
///
/// CONTRACT COMPLIANCE:
/// - Never calls controller directly (always through ViewModel)
/// - Never generates time (time flows from external scheduler)
/// - Always validates UI state via target lists (through ViewModel)
class HomeScreen extends StatelessWidget {
  final HomeViewModel viewModel;

  const HomeScreen({
    Key? key,
    required this.viewModel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        final uiState = viewModel.uiState;

        return Scaffold(
          appBar: AppBar(
            title: const Text('PUSHIN'),
            centerTitle: true,
            actions: [
              // Lock button only visible in unlocked state
              if (uiState.canLock)
                IconButton(
                  icon: const Icon(Icons.lock_outline),
                  tooltip: 'Lock Now',
                  onPressed: () => viewModel.lock(),
                ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // State-specific content (main UI area)
                  Expanded(
                    child: _buildContent(context, uiState),
                  ),
                  const SizedBox(height: 16),
                  // Action buttons (state-dependent)
                  _buildActions(context, uiState),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build content based on UI state
  /// CONTRACT: Each content view receives target lists for platform integration
  Widget _buildContent(BuildContext context, HomeUIState uiState) {
    switch (uiState.type) {
      case HomeUIStateType.locked:
        return LockedContentView(
          blockedTargets: uiState.blockedTargets,
        );

      case HomeUIStateType.earning:
        return EarningContentView(
          blockedTargets: uiState.blockedTargets,
          progress: uiState.workoutProgress!,
        );

      case HomeUIStateType.unlocked:
        return UnlockedContentView(
          accessibleTargets: uiState.accessibleTargets,
          timeRemaining: uiState.timeRemaining!,
          showRecommendations: uiState.canShowRecommendations,
        );

      case HomeUIStateType.expired:
        return ExpiredContentView(
          blockedTargets: uiState.blockedTargets,
          gracePeriodRemaining: uiState.timeRemaining!,
        );
    }
  }

  /// Build action buttons based on UI state
  Widget _buildActions(BuildContext context, HomeUIState uiState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Start Workout button (locked, expired)
        if (uiState.canStartWorkout)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => viewModel.startWorkout(),
              icon: const Icon(Icons.fitness_center),
              label: Text(
                uiState.type == HomeUIStateType.expired
                    ? 'Emergency Workout'
                    : 'Start Workout',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: uiState.type == HomeUIStateType.expired
                    ? Colors.orange
                    : null,
              ),
            ),
          ),

        // Cancel button (earning)
        if (uiState.canCancel) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showCancelConfirmation(context),
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],

        // Lock Now button (unlocked, shown in app bar but can also be here)
        if (uiState.canLock) ...[
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showLockConfirmation(context),
              icon: const Icon(Icons.lock),
              label: const Text('Lock Now'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showCancelConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Workout?'),
        content: const Text(
          'Canceling will forfeit your progress and return to locked state.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CONTINUE WORKOUT'),
          ),
          TextButton(
            onPressed: () {
              viewModel.cancelWorkout();
              Navigator.pop(context);
            },
            child: const Text('CANCEL WORKOUT'),
          ),
        ],
      ),
    );
  }

  void _showLockConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lock Content Now?'),
        content: const Text(
          'You can unlock again by completing another workout.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('STAY UNLOCKED'),
          ),
          TextButton(
            onPressed: () {
              viewModel.lock();
              Navigator.pop(context);
            },
            child: const Text('LOCK NOW'),
          ),
        ],
      ),
    );
  }
}

