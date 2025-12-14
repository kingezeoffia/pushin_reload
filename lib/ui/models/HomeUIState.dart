/// UI State Definition - Platform-Agnostic
///
/// These states are derived from:
/// - PushinState (domain state)
/// - blockedTargets (from controller.getBlockedTargets())
/// - accessibleTargets (from controller.getAccessibleTargets())
///
/// CONTRACT COMPLIANCE:
/// - Never inferred from PushinState alone
/// - Always validated with target lists
/// - Contains platform identifiers for Screen Time / Digital Wellbeing integration

enum HomeUIStateType { locked, earning, unlocked, expired }

class HomeUIState {
  final HomeUIStateType type;
  final List<String> blockedTargets; // Platform identifiers for blocking
  final List<String> accessibleTargets; // Platform identifiers for access
  final double? workoutProgress; // 0.0 to 1.0
  final int? timeRemaining; // Seconds (unlock time or grace period)
  final bool canStartWorkout;
  final bool canCancel;
  final bool canLock;
  final bool canShowRecommendations;

  HomeUIState._({
    required this.type,
    required this.blockedTargets,
    required this.accessibleTargets,
    this.workoutProgress,
    this.timeRemaining,
    required this.canStartWorkout,
    required this.canCancel,
    required this.canLock,
    required this.canShowRecommendations,
  });

  /// LockedUI - Content blocked, encourage workout initiation
  factory HomeUIState.locked({
    required List<String> blockedTargets,
    required bool canStartWorkout,
  }) =>
      HomeUIState._(
        type: HomeUIStateType.locked,
        blockedTargets: blockedTargets,
        accessibleTargets: [],
        canStartWorkout: canStartWorkout,
        canCancel: false,
        canLock: false,
        canShowRecommendations: false, // Never show in blocked state
      );

  /// EarningUI - Workout in progress, content still blocked
  factory HomeUIState.earning({
    required List<String> blockedTargets,
    required double workoutProgress,
    required bool canCancel,
  }) =>
      HomeUIState._(
        type: HomeUIStateType.earning,
        blockedTargets: blockedTargets,
        accessibleTargets: [],
        workoutProgress: workoutProgress,
        canStartWorkout: false,
        canCancel: canCancel,
        canLock: false,
        canShowRecommendations: false, // Never show in blocked state
      );

  /// UnlockedUI - Content accessible, show time remaining
  /// CONTRACT: Only created when blockedTargets.isEmpty AND accessibleTargets.isNotEmpty
  factory HomeUIState.unlocked({
    required List<String> accessibleTargets,
    required int timeRemaining,
    required bool canShowRecommendations,
    required bool canLock,
  }) =>
      HomeUIState._(
        type: HomeUIStateType.unlocked,
        blockedTargets: [], // Must be empty for unlocked state
        accessibleTargets: accessibleTargets,
        timeRemaining: timeRemaining,
        canStartWorkout: false,
        canCancel: false,
        canLock: canLock,
        canShowRecommendations: canShowRecommendations,
      );

  /// ExpiredUI - Grace period before full lock
  /// CONTRACT: timeRemaining is grace period (from getGracePeriodRemaining)
  factory HomeUIState.expired({
    required List<String> blockedTargets,
    required int gracePeriodRemaining,
    required bool canStartWorkout,
  }) =>
      HomeUIState._(
        type: HomeUIStateType.expired,
        blockedTargets: blockedTargets,
        accessibleTargets: [],
        timeRemaining: gracePeriodRemaining, // Grace period, NOT unlock time
        canStartWorkout: canStartWorkout,
        canCancel: false,
        canLock: false,
        canShowRecommendations: false, // Never show in blocked state
      );
}

