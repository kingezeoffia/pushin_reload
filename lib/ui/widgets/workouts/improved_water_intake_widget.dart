import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../../theme/workouts_design_tokens.dart';
import '../../theme/dashboard_design_tokens.dart';
import '../../screens/WaterIntakeScreen.dart';
import '../../screens/WaterIntakeSetupScreen.dart';

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

class ImprovedWaterIntakeWidget extends StatefulWidget {
  final double current;
  final double target;
  final int delay;
  final bool compact;

  const ImprovedWaterIntakeWidget({
    super.key,
    required this.current,
    required this.target,
    this.delay = 0,
    this.compact = false,
  });

  @override
  State<ImprovedWaterIntakeWidget> createState() =>
      _ImprovedWaterIntakeWidgetState();
}

class _ImprovedWaterIntakeWidgetState extends State<ImprovedWaterIntakeWidget>
    with TickerProviderStateMixin {
  late double _currentAmount = 0.0;
  late double _targetAmount = 2.5;
  bool _hasCustomGoal = false;
  late AnimationController _fillController;
  late AnimationController _glowController;
  late AnimationController _waveController;
  late AnimationController _scaleController;
  late AnimationController _entranceController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadData();

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

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutQuart,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    ));

    // Start entrance animation immediately
    _entranceController.forward();

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _fillController.forward();
    });
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _targetAmount = prefs.getDouble('water_daily_goal') ?? 2.5;
        _currentAmount = prefs.getDouble('water_current_amount') ?? 0.0;
        _hasCustomGoal = prefs
            .containsKey('water_daily_goal'); // Check if custom goal was set

        // Reset if it's a new day
        final lastUpdated = prefs.getString('water_last_updated') ?? '';
        final today = DateTime.now().toIso8601String().split('T')[0];
        if (lastUpdated != today) {
          _currentAmount = 0.0;
          _saveData();
        }
      });
    } catch (e) {
      debugPrint('Error loading water data: $e');
    }
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('water_current_amount', _currentAmount);
      await prefs.setDouble('water_daily_goal', _targetAmount);
      await prefs.setString(
        'water_last_updated',
        DateTime.now().toIso8601String().split('T')[0],
      );
    } catch (e) {
      debugPrint('Error saving water data: $e');
    }
  }

  Future<void> _addWaterLog(double amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logJson = prefs.getString('water_log_today') ?? '[]';
      final List<dynamic> log = jsonDecode(logJson);

      log.add({
        'amount': amount,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await prefs.setString('water_log_today', jsonEncode(log));
    } catch (e) {
      debugPrint('Error adding water log: $e');
    }
  }

  void _showWaterTracker() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WaterIntakeScreen(
          currentAmount: _currentAmount,
          targetAmount: _targetAmount,
          onAmountChanged: (amount) {
            setState(() {
              _currentAmount = amount;
              _fillController.forward(from: 0.0);
            });
            _saveData();
          },
          onTargetChanged: (target) {
            setState(() {
              _targetAmount = target;
            });
            _saveData();
          },
          onWaterAdded: (amount) {
            _addWaterLog(amount);
          },
          onEditGoal: () async {
            // Navigate to the setup screen (don't replace, so we can navigate back to water screen)
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WaterIntakeSetupScreen(),
              ),
            );
            // Reload the goal from preferences after returning
            _loadData();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fillController.dispose();
    _glowController.dispose();
    _waveController.dispose();
    _scaleController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (_currentAmount / _targetAmount * 100).clamp(0, 100);

    return GestureDetector(
      onTapDown: (_) {
        _scaleController.forward();
      },
      onTapUp: (_) async {
        _scaleController.reverse();
        if (_hasCustomGoal) {
          _showWaterTracker();
        } else {
          // Navigate to setup screen for first-time setup
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const WaterIntakeSetupScreen(),
            ),
          );
          // Reload data after returning from setup
          if (mounted) {
            _loadData();
          }
        }
      },
      onTapCancel: () {
        _scaleController.reverse();
      },
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              height: widget.compact ? 165.0 : 185.0,
              decoration: BoxDecoration(
                // Clean, minimal design matching GreetingCard
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: _buildWaterContent(percentage.toDouble()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaterContent(double percentage) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.compact ? 14.0 : 16.0,
        widget.compact ? 12.0 : 14.0,
        widget.compact ? 14.0 : 16.0,
        widget.compact ? 14.0 : 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: widget.compact ? 55 : 70,
                  height: widget.compact ? 90 : 110,
                  child: _buildAnimatedGlass(percentage.toDouble()),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStats(percentage.toDouble()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Clean icon matching other widgets
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF7C8CFF).withOpacity(0.15),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.water_drop_rounded,
            color: Color(0xFF7C8CFF),
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Water Intake',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedGlass(double percentage) {
    return AnimatedBuilder(
      animation:
          Listenable.merge([_fillController, _glowController, _waveController]),
      builder: (context, child) {
        return CustomPaint(
          painter: WaterGlassPainter(
            fillPercentage: percentage,
            animationValue: _fillController.value,
            glowValue: _glowController.value,
            waveValue: _waveController.value,
            waterColor: WorkoutsDesignTokens.waterCyan,
          ),
          size: Size.infinite,
          child: Container(),
        );
      },
    );
  }

  Widget _buildStats(double percentage) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: widget.compact ? 2 : 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween(begin: 0, end: _currentAmount),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Text(
                WaterAmountFormatter.format(value),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.compact ? 20 : 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              );
            },
          ),
          SizedBox(height: widget.compact ? 2 : 4),
          Text(
            'of ${_targetAmount.toStringAsFixed(1)}L',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: widget.compact ? 10 : 11,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

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

class WaterTrackerModal extends StatefulWidget {
  final double currentAmount;
  final double targetAmount;
  final Function(double) onAmountChanged;
  final Function(double) onTargetChanged;
  final Function(double) onWaterAdded;

  const WaterTrackerModal({
    super.key,
    required this.currentAmount,
    required this.targetAmount,
    required this.onAmountChanged,
    required this.onTargetChanged,
    required this.onWaterAdded,
  });

  @override
  State<WaterTrackerModal> createState() => _WaterTrackerModalState();
}

class _WaterTrackerModalState extends State<WaterTrackerModal>
    with SingleTickerProviderStateMixin {
  late double _currentAmount;
  late double _targetAmount;
  final _customAmountController = TextEditingController();
  late AnimationController _successController;
  bool _showSuccess = false;
  List<Map<String, dynamic>> _todayLog = [];

  @override
  void initState() {
    super.initState();
    _currentAmount = widget.currentAmount;
    _targetAmount = widget.targetAmount;
    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _loadTodayLog();
  }

  Future<void> _loadTodayLog() async {
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
    if (amount <= 0 || amount > 2.0) {
      _showErrorFeedback();
      return;
    }

    setState(() {
      _currentAmount = (_currentAmount + amount).clamp(0.0, 10.0);
      _showSuccess = true;
    });

    widget.onAmountChanged(_currentAmount);
    widget.onWaterAdded(amount);
    _successController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() => _showSuccess = false);
      }
    });
    _loadTodayLog();
  }

  void _removeLastEntry() {
    if (_todayLog.isEmpty) return;

    final lastEntry = _todayLog.last;
    final amount = lastEntry['amount'] as double;

    setState(() {
      _currentAmount = (_currentAmount - amount).clamp(0.0, 10.0);
      _todayLog.removeLast();
    });

    widget.onAmountChanged(_currentAmount);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('water_log_today', jsonEncode(_todayLog));
    });
  }

  void _showErrorFeedback() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please enter a valid amount (0.1L - 2.0L)'),
        backgroundColor: Colors.red.shade400,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Container(
      decoration: BoxDecoration(
        // Sleek dark background matching settings modal
        color: const Color(0xFF0F0F18),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.85,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(isSmallScreen),
              SizedBox(height: isSmallScreen ? 16 : 20),
              _buildProgressSection(isSmallScreen),
              SizedBox(height: isSmallScreen ? 16 : 20),
              _buildGoalSection(isSmallScreen),
              SizedBox(height: isSmallScreen ? 16 : 20),
              _buildQuickAddSection(isSmallScreen),
              SizedBox(height: isSmallScreen ? 12 : 16),
              _buildCustomAmountSection(isSmallScreen),
              SizedBox(height: isSmallScreen ? 16 : 20),
              _buildTodayLogSection(isSmallScreen),
              SizedBox(height: isSmallScreen ? 16 : 20),
              _buildActionButtons(isSmallScreen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
          decoration: BoxDecoration(
            color: WorkoutsDesignTokens.waterCyan.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.water_drop,
            color: WorkoutsDesignTokens.waterCyan,
            size: isSmallScreen ? 24 : 28,
          ),
        ),
        SizedBox(width: isSmallScreen ? 8 : 12),
        Text(
          'Water Tracker',
          style: TextStyle(
            color: DashboardDesignTokens.textPrimary,
            fontSize: isSmallScreen ? 20 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (_showSuccess)
          AnimatedBuilder(
            animation: _successController,
            builder: (context, child) {
              return Transform.scale(
                scale: _successController.value,
                child: Icon(
                  Icons.check_circle,
                  color: DashboardDesignTokens.accentGreen,
                  size: isSmallScreen ? 28 : 32,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildProgressSection(bool isSmallScreen) {
    final percentage = (_currentAmount / _targetAmount * 100).clamp(0, 100);

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Progress',
                style: TextStyle(
                  color: DashboardDesignTokens.textSecondary,
                  fontSize: isSmallScreen ? 12 : 14,
                ),
              ),
              Text(
                '${percentage.toInt()}%',
                style: TextStyle(
                  color: DashboardDesignTokens.accentGreen,
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor:
                  AlwaysStoppedAnimation(WorkoutsDesignTokens.waterCyan),
              minHeight: isSmallScreen ? 10 : 12,
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          Text(
            '${WaterAmountFormatter.format(_currentAmount)} / ${_targetAmount.toStringAsFixed(1)}L',
            style: TextStyle(
              color: DashboardDesignTokens.textPrimary,
              fontSize: isSmallScreen ? 18 : 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalSection(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Goal',
          style: TextStyle(
            color: DashboardDesignTokens.textPrimary,
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: isSmallScreen ? 8 : 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(
                '${_targetAmount.toStringAsFixed(1)}L',
                style: TextStyle(
                  color: DashboardDesignTokens.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _targetAmount,
                  min: 0.5,
                  max: 5.0,
                  divisions: 45,
                  activeColor: WorkoutsDesignTokens.waterCyan,
                  inactiveColor: Colors.white.withOpacity(0.2),
                  onChanged: (value) {
                    setState(() => _targetAmount = value);
                  },
                  onChangeEnd: (value) {
                    widget.onTargetChanged(value);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAddSection(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Add',
          style: TextStyle(
            color: DashboardDesignTokens.textPrimary,
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: isSmallScreen ? 8 : 12),
        Row(
          children: [
            Expanded(child: _buildQuickAddButton(0.25, isSmallScreen)),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Expanded(child: _buildQuickAddButton(0.5, isSmallScreen)),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Expanded(child: _buildQuickAddButton(1.0, isSmallScreen)),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAddButton(double amount, bool isSmallScreen) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _addWater(amount),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                WorkoutsDesignTokens.waterCyan.withOpacity(0.2),
                WorkoutsDesignTokens.waterCyan.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: WorkoutsDesignTokens.waterCyan.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.add,
                color: WorkoutsDesignTokens.waterCyan,
                size: isSmallScreen ? 20 : 24,
              ),
              SizedBox(height: isSmallScreen ? 2 : 4),
              Text(
                WaterAmountFormatter.format(amount),
                style: TextStyle(
                  color: DashboardDesignTokens.textPrimary,
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAmountSection(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Custom Amount',
          style: TextStyle(
            color: DashboardDesignTokens.textPrimary,
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: isSmallScreen ? 8 : 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customAmountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  color: DashboardDesignTokens.textPrimary,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter liters (e.g., 0.3)',
                  hintStyle: TextStyle(
                    color: DashboardDesignTokens.textSecondary,
                    fontSize: isSmallScreen ? 13 : 14,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: WorkoutsDesignTokens.waterCyan,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Material(
              color: WorkoutsDesignTokens.waterCyan,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {
                  final amount = double.tryParse(_customAmountController.text);
                  if (amount != null) {
                    _addWater(amount);
                    _customAmountController.clear();
                  } else {
                    _showErrorFeedback();
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTodayLogSection(bool isSmallScreen) {
    if (_todayLog.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Today\'s Log',
              style: TextStyle(
                color: DashboardDesignTokens.textPrimary,
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton.icon(
              onPressed: _removeLastEntry,
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              label: const Text('Remove Last'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          constraints: BoxConstraints(maxHeight: isSmallScreen ? 120 : 150),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _todayLog.length,
            itemBuilder: (context, index) {
              final entry = _todayLog[_todayLog.length - 1 - index];
              final time = DateTime.parse(entry['timestamp']);
              final timeStr =
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.water_drop,
                      color: WorkoutsDesignTokens.waterCyan,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${WaterAmountFormatter.format(entry['amount'])}',
                      style: TextStyle(
                        color: DashboardDesignTokens.textPrimary,
                        fontSize: isSmallScreen ? 13 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: DashboardDesignTokens.textSecondary,
                        fontSize: isSmallScreen ? 11 : 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isSmallScreen) {
    return ElevatedButton(
      onPressed: () => Navigator.pop(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: WorkoutsDesignTokens.waterCyan,
        foregroundColor: Colors.white,
        minimumSize: Size(double.infinity, isSmallScreen ? 44 : 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        'Close',
        style: TextStyle(
          fontSize: isSmallScreen ? 14 : 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
