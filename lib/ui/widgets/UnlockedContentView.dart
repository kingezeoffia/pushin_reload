import 'package:flutter/material.dart';

/// UnlockedContentView - Displayed when content is accessible
///
/// CONTRACT COMPLIANCE:
/// - Only rendered when blockedTargets.isEmpty AND accessibleTargets.isNotEmpty
/// - Receives accessibleTargets (platform identifiers) for Screen Time integration
/// - Shows mini-recommendations ONLY when accessibleTargets.isNotEmpty
/// - Displays unlock time remaining countdown
class UnlockedContentView extends StatelessWidget {
  final List<String> accessibleTargets;
  final int timeRemaining; // Seconds
  final bool showRecommendations;

  const UnlockedContentView({
    Key? key,
    required this.accessibleTargets,
    required this.timeRemaining,
    required this.showRecommendations,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final minutes = timeRemaining ~/ 60;
    final seconds = timeRemaining % 60;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Unlock icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_open,
              size: 60,
              color: Colors.green.shade400,
            ),
          ),
          const SizedBox(height: 24),

          // Main message
          const Text(
            'Content Unlocked',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Time remaining
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} remaining',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Accessible targets indicator
          // CONTRACT: Uses target list for platform integration
          _buildAccessibleTargetsIndicator(context),
          const SizedBox(height: 24),

          // Mini-recommendations
          // CONTRACT: Only shown when showRecommendations is true
          // (which is derived from accessibleTargets.isNotEmpty)
          if (showRecommendations) _buildMiniRecommendations(context),
        ],
      ),
    );
  }

  Widget _buildAccessibleTargetsIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600),
              const SizedBox(width: 8),
              Text(
                '${accessibleTargets.length} ${accessibleTargets.length == 1 ? 'target' : 'targets'} accessible',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Platform identifiers (for integration verification)
          if (accessibleTargets.isNotEmpty)
            Text(
              'Platform IDs: ${accessibleTargets.take(3).join(', ')}${accessibleTargets.length > 3 ? '...' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  /// Mini-recommendations - ONLY shown when accessible targets exist
  /// CONTRACT: Visibility derived from accessibleTargets.isNotEmpty
  Widget _buildMiniRecommendations(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.blue.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lightbulb, color: Colors.purple.shade600),
              const SizedBox(width: 8),
              Text(
                'Recommended',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Try mindful browsing during your unlocked time',
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // In production, this would show personalized recommendations
          Wrap(
            spacing: 8,
            children: [
              Chip(
                label: const Text('5-min meditation'),
                backgroundColor: Colors.purple.shade100,
              ),
              Chip(
                label: const Text('Educational content'),
                backgroundColor: Colors.blue.shade100,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
