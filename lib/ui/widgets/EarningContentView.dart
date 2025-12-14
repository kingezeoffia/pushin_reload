import 'package:flutter/material.dart';

/// EarningContentView - Displayed during workout
///
/// CONTRACT COMPLIANCE:
/// - Receives blockedTargets (content remains blocked during workout)
/// - Shows workout progress
/// - Content remains blocked until workout completion
class EarningContentView extends StatelessWidget {
  final List<String> blockedTargets;
  final double progress; // 0.0 to 1.0

  const EarningContentView({
    Key? key,
    required this.blockedTargets,
    required this.progress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).toInt();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Progress ring
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress < 1.0 ? Colors.blue : Colors.green,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 48,
                    color: progress < 1.0 ? Colors.blue : Colors.green,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Status message
          Text(
            progress < 1.0 ? 'Workout in Progress' : 'Workout Complete!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            progress < 1.0
                ? 'Keep going to unlock access'
                : 'Tap complete to unlock',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),

          // Blocked targets reminder
          // CONTRACT: Content remains blocked during workout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_clock, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  '${blockedTargets.length} ${blockedTargets.length == 1 ? 'target' : 'targets'} still blocked',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
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

