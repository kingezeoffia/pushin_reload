import 'package:flutter/material.dart';

/// LockedContentView - Displayed when content is blocked
///
/// CONTRACT COMPLIANCE:
/// - Receives blockedTargets (platform identifiers) for future Screen Time integration
/// - Displays blocked content indicators
/// - Encourages workout initiation
class LockedContentView extends StatelessWidget {
  final List<String> blockedTargets;

  const LockedContentView({
    Key? key,
    required this.blockedTargets,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Lock icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock,
              size: 60,
              color: Colors.red.shade400,
            ),
          ),
          const SizedBox(height: 24),

          // Main message
          const Text(
            'Content Locked',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          const Text(
            'Complete a workout to unlock access',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Blocked targets indicator
          // CONTRACT: Uses target list for platform integration readiness
          _buildBlockedTargetsIndicator(context),
        ],
      ),
    );
  }

  Widget _buildBlockedTargetsIndicator(BuildContext context) {
    // In production, this would show actual app icons/names
    // For now, show count and identifiers (for platform integration testing)
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, color: Colors.red.shade400),
              const SizedBox(width: 8),
              Text(
                '${blockedTargets.length} ${blockedTargets.length == 1 ? 'target' : 'targets'} blocked',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Platform identifiers (for integration verification)
          if (blockedTargets.isNotEmpty)
            Text(
              'Platform IDs: ${blockedTargets.take(3).join(', ')}${blockedTargets.length > 3 ? '...' : ''}',
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
}
