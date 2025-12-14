import 'package:flutter/material.dart';

/// ExpiredContentView - Displayed during grace period before full lock
///
/// CONTRACT COMPLIANCE (CRITICAL):
/// - Receives blockedTargets (content is blocked during grace period)
/// - Shows gracePeriodRemaining from controller.getGracePeriodRemaining()
/// - Does NOT use unlock time remaining (which would be 0)
/// - Urgent UI to encourage immediate workout
class ExpiredContentView extends StatelessWidget {
  final List<String> blockedTargets;
  final int gracePeriodRemaining; // Seconds - from getGracePeriodRemaining()

  const ExpiredContentView({
    Key? key,
    required this.blockedTargets,
    required this.gracePeriodRemaining,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Warning icon with animation suggestion
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.orange.shade400,
                width: 3,
              ),
            ),
            child: Icon(
              Icons.timer_off,
              size: 60,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 24),

          // Main message
          Text(
            'Time\'s Up!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
          const SizedBox(height: 8),

          // Grace period countdown
          // CONTRACT CRITICAL: This is grace period, NOT unlock time
          _buildGracePeriodCountdown(context),
          const SizedBox(height: 16),

          // Urgency message
          const Text(
            'Complete a workout to extend access',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Blocked targets warning
          // CONTRACT: Content is blocked during grace period
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block, color: Colors.red.shade600),
                    const SizedBox(width: 8),
                    Text(
                      '${blockedTargets.length} ${blockedTargets.length == 1 ? 'target' : 'targets'} blocked',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'All content will be fully locked when grace period ends',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Grace period countdown display
  /// CONTRACT CRITICAL: Shows remaining grace period (from getGracePeriodRemaining)
  /// NOT unlock time remaining (which is 0 in EXPIRED state)
  Widget _buildGracePeriodCountdown(BuildContext context) {
    final isUrgent = gracePeriodRemaining <= 2; // Last 2 seconds

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: isUrgent ? Colors.red.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent ? Colors.red.shade400 : Colors.orange.shade400,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Grace Period',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isUrgent ? Colors.red.shade900 : Colors.orange.shade900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hourglass_bottom,
                color: isUrgent ? Colors.red.shade700 : Colors.orange.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                '$gracePeriodRemaining ${gracePeriodRemaining == 1 ? 'second' : 'seconds'}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isUrgent ? Colors.red.shade900 : Colors.orange.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'until full lock',
            style: TextStyle(
              fontSize: 12,
              color: isUrgent ? Colors.red.shade800 : Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

