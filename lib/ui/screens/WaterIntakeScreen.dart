import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../theme/workouts_design_tokens.dart';
import '../widgets/GOStepsBackground.dart';
import '../widgets/pill_navigation_bar.dart';

// Utility class for water amount formatting
class WaterAmountFormatter {
  static String format(double amount) {
    // Convert to string with 2 decimal places
    String formatted = amount.toStringAsFixed(2);
    // Remove trailing zeros after decimal point
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'\.?0+$'), '');
    }
    return '${formatted}L';
  }
}

class WaterIntakeScreen extends StatefulWidget {
  final double currentAmount;
  final double targetAmount;
  final Function(double) onAmountChanged;
  final Function(double) onTargetChanged;
  final Function(double) onWaterAdded;
  final VoidCallback? onEditGoal;

  const WaterIntakeScreen({
    super.key,
    required this.currentAmount,
    required this.targetAmount,
    required this.onAmountChanged,
    required this.onTargetChanged,
    required this.onWaterAdded,
    this.onEditGoal,
  });

  @override
  State<WaterIntakeScreen> createState() => _WaterIntakeScreenState();
}

class _WaterIntakeScreenState extends State<WaterIntakeScreen>
    with TickerProviderStateMixin {
  late double _currentAmount;
  late double _targetAmount;
  List<Map<String, dynamic>> _todayLog = [];

  late AnimationController _fillController;
  late AnimationController _glowController;
  late AnimationController _waveController;
  late Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();
    _currentAmount = widget.currentAmount;
    _targetAmount = widget.targetAmount;

    _fillController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    // Initialize fill animation to current percentage
    final initialPercentage =
        ((_currentAmount / _targetAmount * 100).clamp(0, 100)).toDouble();
    _fillAnimation = Tween<double>(
      begin: initialPercentage,
      end: initialPercentage,
    ).animate(
      CurvedAnimation(
        parent: _fillController,
        curve: Curves.easeInOutCubic,
      ),
    );

    // Start with full animation (no entrance delay for water screen)
    _fillController.value = 1.0;

    _loadTodayLog();
  }

  Future<void> _loadTodayLog() async {
    // Load today's log for water tracking
    try {
      final prefs = await SharedPreferences.getInstance();
      final logJson = prefs.getString('water_log_today') ?? '[]';
      final List<dynamic> log = jsonDecode(logJson);
      setState(() {
        _todayLog = log.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      debugPrint('Error loading today log: $e');
    }
  }

  void _addWater(double amount) {
    if (amount <= 0 || amount > 2.0) return;

    final oldAmount = _currentAmount;
    final oldPercentage =
        ((oldAmount / _targetAmount * 100).clamp(0, 100)).toDouble();

    setState(() {
      _currentAmount = (_currentAmount + amount).clamp(0.0, 10.0);
    });

    final newPercentage =
        ((_currentAmount / _targetAmount * 100).clamp(0, 100)).toDouble();

    widget.onAmountChanged(_currentAmount);
    widget.onWaterAdded(amount);

    // Add to today's log
    final newEntry = {
      'amount': amount,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _todayLog.add(newEntry);

    // Animate incrementally from current level to new level
    _fillAnimation = Tween<double>(
      begin: oldPercentage,
      end: newPercentage,
    ).animate(
      CurvedAnimation(
        parent: _fillController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _fillController.forward(from: 0.0);
  }

  Future<void> _removeLastEntry() async {
    if (_currentAmount <= 0) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final logJson = prefs.getString('water_log_today') ?? '[]';
      final List<dynamic> log = jsonDecode(logJson);

      if (log.isEmpty) return;

      final lastEntry = log.removeLast();
      final amount = lastEntry['amount'] as double;

      // Calculate new values
      final newAmount = (_currentAmount - amount).clamp(0.0, _targetAmount);
      final newPercentage = (newAmount / _targetAmount * 100).clamp(0, 100);

      // Smooth animation transition
      if (mounted) {
        setState(() {
          _currentAmount = newAmount;
          _fillAnimation = Tween<double>(
            begin: _fillAnimation.value,
            end: newPercentage.toDouble(),
          ).animate(CurvedAnimation(
            parent: _fillController,
            curve: Curves.easeInOutCubic,
          ));

          _fillController.forward(from: 0.0);
        });
      }

      // Update local state and storage
      setState(() {
        _todayLog = log.cast<Map<String, dynamic>>();
      });
      await prefs.setString('water_log_today', jsonEncode(log));
      widget.onAmountChanged(newAmount);
    } catch (e) {
      debugPrint('Error removing entry: $e');
    }
  }

  @override
  void dispose() {
    _fillController.dispose();
    _glowController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Water ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  WorkoutsDesignTokens.waterCyan,
                  WorkoutsDesignTokens.waterCyan.withOpacity(0.8),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(
                Rect.fromLTWH(0, 0, bounds.width, bounds.height),
              ),
              blendMode: BlendMode.srcIn,
              child: const Text(
                'Intake',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: widget.onEditGoal != null
            ? [
                TextButton(
                  onPressed: widget.onEditGoal,
                  child: Text(
                    'Edit',
                    style: TextStyle(
                      color: WorkoutsDesignTokens.waterCyan,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ]
            : null,
      ),
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: Stack(
          children: [
            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Water glass (takes most of screen)
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Center(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _fillController,
                            _glowController,
                            _waveController,
                          ]),
                          builder: (context, child) {
                            return CustomPaint(
                              size: const Size(250, 350),
                              painter: WaterGlassPainter(
                                fillPercentage: _fillAnimation.value,
                                animationValue:
                                    1.0, // Always fully animated now
                                glowValue: _glowController.value,
                                waveValue: _waveController.value,
                                waterColor: WorkoutsDesignTokens.waterCyan,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Big cool water amount text - positioned higher up
                  Container(
                    margin: const EdgeInsets.only(bottom: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated water amount display - using same animation as water glass
                        AnimatedBuilder(
                          animation: _fillController,
                          builder: (context, child) {
                            // Calculate the animated amount based on the fill animation progress
                            final animatedPercentage = _fillAnimation.value;
                            final animatedAmount =
                                (animatedPercentage / 100) * _targetAmount;

                            return Text(
                              '${WaterAmountFormatter.format(animatedAmount)} / ${WaterAmountFormatter.format(_targetAmount)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.5,
                                height: 1.0,
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // Minus button directly below
                        AnimatedBuilder(
                          animation: _fillAnimation,
                          builder: (context, child) {
                            final hasEntries = _currentAmount > 0;
                            return _buildMinusButton(hasEntries);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Spacer to push content up (buttons will be positioned at bottom)
                  const Spacer(),
                ],
              ),
            ),

            // Water intake buttons positioned at navigation pill level
            BottomActionContainer(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildWaterButton(0.25),
                  _buildWaterButton(0.5),
                  _buildWaterButton(1.0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterButton(double amount) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: GestureDetector(
          onTap: () => _addWater(amount),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(100), // Pill shape
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                WaterAmountFormatter.format(amount),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2A2A6A),
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinusButton(bool enabled) {
    return GestureDetector(
      onTap: enabled ? () => _removeLastEntry() : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.red.shade400.withOpacity(0.9)
              : Colors.grey.shade600.withOpacity(0.3),
          shape: BoxShape.circle,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.red.shade400.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Icon(
          Icons.remove,
          color: enabled ? Colors.white : Colors.white.withOpacity(0.3),
          size: 20,
        ),
      ),
    );
  }
}

// Keep the exact same WaterGlassPainter from the original widget
class WaterGlassPainter extends CustomPainter {
  final double fillPercentage;
  final double animationValue;
  final double glowValue;
  final double waveValue;
  final Color waterColor;

  WaterGlassPainter({
    required this.fillPercentage,
    required this.animationValue,
    required this.glowValue,
    required this.waveValue,
    required this.waterColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withOpacity(0.3);

    // Glass outline
    final glassPath = Path();
    final glassWidth = size.width * 0.6;
    final glassHeight = size.height * 0.8;
    final centerX = size.width / 2;
    final startY = size.height * 0.1;

    glassPath.moveTo(centerX - glassWidth / 2, startY);
    glassPath.lineTo(centerX - glassWidth / 2 + 10, startY + glassHeight);
    glassPath.lineTo(centerX + glassWidth / 2 - 10, startY + glassHeight);
    glassPath.lineTo(centerX + glassWidth / 2, startY);

    canvas.drawPath(glassPath, paint);

    // Water fill
    final currentFill = fillPercentage * animationValue / 100;
    if (currentFill > 0) {
      final waterPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            waterColor.withOpacity(0.6),
            waterColor,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      final waterHeight = glassHeight * currentFill;
      final waterPath = Path();

      final bottomY = startY + glassHeight;
      final topY = bottomY - waterHeight;

      // Calculate water edge positions that follow the glass shape
      // Glass gets narrower towards bottom by 10px on each side (20px total)
      final glassTopWidth = glassWidth;
      final glassBottomWidth = glassWidth - 20;

      // Calculate the width of the glass at the current water level
      final waterLevelRatio = waterHeight / glassHeight; // 0.0 to 1.0
      final waterWidthAtLevel = glassBottomWidth +
          (glassTopWidth - glassBottomWidth) * waterLevelRatio;

      // Water edges at current level
      final waterLeftX = centerX - waterWidthAtLevel / 2;
      final waterRightX = centerX + waterWidthAtLevel / 2;

      // Bottom reference points (always at glass bottom width)
      final waterBottomWidth = glassBottomWidth;
      final waterBottomLeftX = centerX - waterBottomWidth / 2;
      final waterBottomRightX = centerX + waterBottomWidth / 2;

      // Start from bottom left
      waterPath.moveTo(waterBottomLeftX, bottomY);

      // Draw left edge following glass slant to water level
      waterPath.lineTo(waterLeftX, topY);

      // Add wave effect across the water surface at current level
      final waveAmplitude = 3.0;
      final waveFrequency = 2.0;
      final wavePoints = <Offset>[];

      for (double i = 0; i <= waterWidthAtLevel; i += 2) {
        final x = waterLeftX + i;
        final wave = math.sin(
                (i / waterWidthAtLevel) * math.pi * waveFrequency +
                    waveValue * math.pi * 2) *
            waveAmplitude;
        wavePoints.add(Offset(x, topY + wave));
      }

      // Add all wave points
      for (final point in wavePoints) {
        waterPath.lineTo(point.dx, point.dy);
      }

      // Draw right edge following glass slant back to bottom
      waterPath.lineTo(waterRightX, topY);
      waterPath.lineTo(waterBottomRightX, bottomY);

      // Close the path
      waterPath.close();

      canvas.drawPath(waterPath, waterPaint);

      // Glow effect
      if (currentFill > 0.5) {
        final glowPaint = Paint()
          ..color = waterColor.withOpacity(0.2 * glowValue)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
        canvas.drawPath(waterPath, glowPaint);
      }

      // Reflection/highlight
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      final highlightPath = Path();
      highlightPath.addOval(Rect.fromLTWH(
        centerX - glassWidth / 4,
        topY + 10,
        glassWidth / 6,
        waterHeight / 3,
      ));
      canvas.drawPath(highlightPath, highlightPaint);
    }
  }

  @override
  bool shouldRepaint(WaterGlassPainter oldDelegate) =>
      oldDelegate.fillPercentage != fillPercentage ||
      oldDelegate.animationValue != animationValue ||
      oldDelegate.glowValue != glowValue ||
      oldDelegate.waveValue != waveValue;
}
