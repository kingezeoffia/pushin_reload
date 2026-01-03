import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../state/pushin_app_controller.dart';
import '../../../services/FocusModeService.dart';
import '../../../services/platform/ScreenTimeMonitor.dart';
import '../../theme/enhanced_settings_design_tokens.dart';

/// Screen Time Settings Card
///
/// Demonstrates Family Activity Picker integration
/// Shows current authorization status and allows app selection
class ScreenTimeSettingsCard extends StatefulWidget {
  const ScreenTimeSettingsCard({super.key});

  @override
  State<ScreenTimeSettingsCard> createState() => _ScreenTimeSettingsCardState();
}

class _ScreenTimeSettingsCardState extends State<ScreenTimeSettingsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: EnhancedSettingsDesignTokens.pageLoadDuration,
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PushinAppController>(
      builder: (consumerContext, pushinController, child) {
        final focusModeService = pushinController.focusModeService;
        if (focusModeService == null) {
          return const SizedBox.shrink();
        }
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(_slideAnimation),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: EnhancedSettingsDesignTokens.cardDark,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: EnhancedSettingsDesignTokens.primaryPurple
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.screen_lock_portrait,
                            color: EnhancedSettingsDesignTokens.primaryPurple,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Focus Sessions',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Block distracting apps during focus sessions to stay productive.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildStatusSection(focusModeService),
                    const SizedBox(height: 16),
                    _buildActionButtons(consumerContext, focusModeService),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusSection(FocusModeService focusModeService) {
    final status = focusModeService.authorizationStatus;
    final hasError = focusModeService.hasError;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _getStatusIcon(status),
            color: _getStatusColor(status),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusTitle(status),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  hasError
                      ? focusModeService.errorMessage!
                      : _getStatusDescription(status),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, FocusModeService focusModeService) {
    final status = focusModeService.authorizationStatus;

    return Row(
      children: [
        if (status == AuthorizationStatus.notDetermined ||
            status == AuthorizationStatus.denied)
          Expanded(
            child: ElevatedButton(
              onPressed: () => _requestPermission(context, focusModeService),
              style: ElevatedButton.styleFrom(
                backgroundColor: EnhancedSettingsDesignTokens.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Enable Focus Sessions'),
            ),
          )
        else
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _selectApps(context, focusModeService),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white30),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Edit blocked apps'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _startFocusSession(context, focusModeService),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('🚨 Hard Shield Test'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _stopFocusSession(context, focusModeService),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Stop Session'),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _requestPermission(
      BuildContext context, FocusModeService focusModeService) async {
    final result = await focusModeService.requestScreenTimePermission();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getPermissionResultMessage(result)),
          backgroundColor: result == AuthorizationResult.granted
              ? EnhancedSettingsDesignTokens.successMint
              : Colors.orange,
        ),
      );
    }
  }

  Future<void> _selectApps(
      BuildContext context, FocusModeService focusModeService) async {
    try {
      final result = await focusModeService.presentAppPicker();

      if (context.mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Selected ${result.totalSelected} apps/categories for blocking'),
            backgroundColor: EnhancedSettingsDesignTokens.primaryPurple,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to open app selector'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startFocusSession(
      BuildContext context, FocusModeService focusModeService) async {
    // 🚨 HARD SHIELD VALIDATION TEST
    // Temporary code to test ManagedSettings functionality
    // Starts a focus session with empty token lists to trigger hard shield

    try {
      final result = await focusModeService.startFocusSession(
        durationMinutes: 5, // Short test duration
        blockedAppTokens: [], // Empty - our iOS code blocks everything
        blockedCategoryTokens: [], // Empty - our iOS code blocks all categories
        sessionName: 'Hard Shield Test',
      );

      if (context.mounted) {
        if (result == FocusSessionResult.started) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '🚨 HARD SHIELD ENABLED - Try opening Safari/Instagram/WhatsApp'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 10),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to start session: $result'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopFocusSession(
      BuildContext context, FocusModeService focusModeService) async {
    // Stop the current focus session and disable hard shield
    try {
      final result = await focusModeService.endFocusSession();

      if (context.mounted) {
        if (result) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Session ended - Hard shield disabled'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to end session'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error stopping session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  IconData _getStatusIcon(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return Icons.check_circle;
      case AuthorizationStatus.denied:
        return Icons.cancel;
      case AuthorizationStatus.restricted:
        return Icons.warning;
      case AuthorizationStatus.notDetermined:
        return Icons.help;
    }
  }

  Color _getStatusColor(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return EnhancedSettingsDesignTokens.successMint;
      case AuthorizationStatus.denied:
        return Colors.red;
      case AuthorizationStatus.restricted:
        return Colors.orange;
      case AuthorizationStatus.notDetermined:
        return Colors.grey;
    }
  }

  String _getStatusTitle(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return 'Focus Sessions Ready';
      case AuthorizationStatus.denied:
        return 'Permission Required';
      case AuthorizationStatus.restricted:
        return 'Access Restricted';
      case AuthorizationStatus.notDetermined:
        return 'Not Configured';
    }
  }

  String _getStatusDescription(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return 'Ready to block distracting apps';
      case AuthorizationStatus.denied:
        return 'Grant permission to enable focus sessions';
      case AuthorizationStatus.restricted:
        return 'Device restrictions prevent this feature';
      case AuthorizationStatus.notDetermined:
        return 'Tap Enable to get started';
    }
  }

  String _getPermissionResultMessage(AuthorizationResult result) {
    switch (result) {
      case AuthorizationResult.granted:
        return 'Focus sessions enabled! Select apps to block.';
      case AuthorizationResult.denied:
        return 'Permission denied. You can enable later in Settings.';
      case AuthorizationResult.restricted:
        return 'Device restrictions prevent focus sessions.';
      case AuthorizationResult.error:
        return 'Failed to enable focus sessions. Try again.';
    }
  }
}
