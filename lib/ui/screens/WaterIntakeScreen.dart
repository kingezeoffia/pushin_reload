import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import '../theme/workouts_design_tokens.dart';

class WaterAmountFormatter {
  static String format(double amount) {
    if (amount >= 1.0) {
      return '${amount.toStringAsFixed(1)}L';
    } else {
      return '${(amount * 1000).toInt()}ml';
    }
  }
}

class Bubble {
  double x, y, radius, speed, opacity;
  Bubble(
      {required this.x,
      required this.y,
      required this.radius,
      required this.speed,
      required this.opacity});
}

class WaterIntakeScreen extends StatefulWidget {
  final double currentAmount;
  final double targetAmount;
  final Function(double) onAmountChanged;
  final Function(double) onTargetChanged;
  final Function(double) onWaterAdded;
  final Future<void> Function()? onEditGoal;

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

  late AnimationController _mainController;
  late AnimationController _waveController;
  late Animation<double> _fillAnimation;

  List<Bubble> _bubbles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _currentAmount = widget.currentAmount;
    _targetAmount = widget.targetAmount;
    _loadTodayLog();

    _mainController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _waveController =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();

    _fillAnimation = Tween<double>(
            begin: 0, end: (_currentAmount / _targetAmount).clamp(0.0, 1.0))
        .animate(CurvedAnimation(
            parent: _mainController, curve: Curves.easeInOutCubic));

    _mainController.forward();
    _generateBubbles();
  }

  Future<void> _loadTodayLog() async {
    final prefs = await SharedPreferences.getInstance();
    final logJson = prefs.getString('water_log_today') ?? '[]';
    setState(() {
      _todayLog = List<Map<String, dynamic>>.from(jsonDecode(logJson));
    });
  }

  void _generateBubbles() {
    _bubbles = List.generate(15, (_) => _createBubble());
  }

  Bubble _createBubble() {
    return Bubble(
      x: _random.nextDouble(),
      y: 1.1,
      radius: _random.nextDouble() * 3 + 1,
      speed: _random.nextDouble() * 0.002 + 0.001,
      opacity: _random.nextDouble() * 0.4,
    );
  }

  void _addWater(double amount) {
    HapticFeedback.lightImpact();
    final double oldFill = _currentAmount / _targetAmount;
    setState(() {
      _currentAmount = (_currentAmount + amount).clamp(0.0, 10.0);
      _todayLog
          .add({'amount': amount, 'time': DateTime.now().toIso8601String()});
    });
    _syncAndAnimate(oldFill);
    widget.onWaterAdded(amount);
    widget.onAmountChanged(_currentAmount);
  }

  void _removeLastEntry() {
    if (_todayLog.isEmpty) return;
    HapticFeedback.mediumImpact();
    final double oldFill = _currentAmount / _targetAmount;
    final lastEntry = _todayLog.removeLast();
    setState(() {
      _currentAmount =
          (_currentAmount - (lastEntry['amount'] as double)).clamp(0.0, 10.0);
    });
    _syncAndAnimate(oldFill);
    widget.onAmountChanged(_currentAmount);
  }

  void _syncAndAnimate(double oldFill) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('water_log_today', jsonEncode(_todayLog));

    // Update the animation to reflect the new fill level without transition
    setState(() {});
  }

  @override
  void dispose() {
    _mainController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Water Intake",
          style: TextStyle(
              fontWeight: FontWeight.w700, color: Colors.white, fontSize: 20),
        ),
        actions: [
          IconButton(
            onPressed: widget.onEditGoal,
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient Background Glow
            Positioned(
              top: 100,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: WorkoutsDesignTokens.waterCyan.withOpacity(0.15),
                ),
                child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                    child: Container()),
              ),
            ),

            // LAYER 1: Massive Liter Count (Behind Glass)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _currentAmount),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, child) => Text(
                    value >= 1.0
                        ? value.toStringAsFixed(1)
                        : (value * 1000).toInt().toString(),
                    style: TextStyle(
                      fontSize: 140,
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withOpacity(0.15),
                      letterSpacing: -5,
                    ),
                  ),
                ),
                Text(
                  _currentAmount >= 1.0 ? "LITERS" : "MILLILITERS",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withOpacity(0.1),
                    letterSpacing: 8,
                  ),
                ),
              ],
            ),

            // LAYER 2: Glass & Water Visualization
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Top Percentage
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                        begin: 0, end: (_currentAmount / _targetAmount) * 100),
                    duration: const Duration(milliseconds: 1000),
                    builder: (context, value, child) => Column(
                      children: [
                        Text(
                          "${value.toInt()}%",
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                        Text(
                          "DAILY GOAL",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.5),
                              letterSpacing: 2),
                        ),
                      ],
                    ),
                  ),

                  // The Glass Container
                  Expanded(
                    child: AnimatedBuilder(
                      animation:
                          Listenable.merge([_mainController, _waveController]),
                      builder: (context, child) {
                        _updateBubbles();
                        return CustomPaint(
                          size: const Size(200, 450),
                          painter: PremiumWaterPainter(
                            fillProgress: _fillAnimation.value,
                            wavePhase: _waveController.value,
                            bubbles: _bubbles,
                            accentColor: WorkoutsDesignTokens.waterCyan,
                          ),
                        );
                      },
                    ),
                  ),

                  // Minus Button (Undo Last)
                  _buildRemoveButton(),

                  const SizedBox(height: 30),

                  // Pill Shape Intake Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildPillButton("250ml", 0.25),
                        const SizedBox(width: 12),
                        _buildPillButton("500ml", 0.5),
                        const SizedBox(width: 12),
                        _buildPillButton("1.0L", 1.0),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateBubbles() {
    for (var b in _bubbles) {
      b.y -= b.speed;
      if (b.y < -0.1) {
        b.y = 1.1;
        b.x = _random.nextDouble();
      }
    }
  }

  Widget _buildRemoveButton() {
    final bool hasData = _todayLog.isNotEmpty;
    return GestureDetector(
      onTap: hasData ? _removeLastEntry : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: hasData
              ? Colors.red.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasData
                ? Colors.red.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.remove_circle_outline,
                size: 18, color: hasData ? Colors.redAccent : Colors.white24),
            const SizedBox(width: 8),
            Text(
              "REMOVE LAST",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: hasData ? Colors.redAccent : Colors.white24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillButton(String label, double amount) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _addWater(amount),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumWaterPainter extends CustomPainter {
  final double fillProgress;
  final double wavePhase;
  final List<Bubble> bubbles;
  final Color accentColor;

  PremiumWaterPainter({
    required this.fillProgress,
    required this.wavePhase,
    required this.bubbles,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double centerX = w / 2;

    // --- Bottle Dimensions ---
    final double neckWidth = w * 0.35;
    final double neckHeight = h * 0.12;
    final double shoulderWidth = w * 0.85;
    final double bodyWidth = w * 0.82; // Slight taper
    final double capHeight = 12.0;

    // --- Define the Bottle Silhouette Path ---
    final Path bottlePath = Path();

    // Start at top left of the neck (just below the cap)
    bottlePath.moveTo(centerX - neckWidth / 2, capHeight + 5);

    // Neck down to shoulder
    bottlePath.lineTo(centerX - neckWidth / 2, neckHeight);

    // Left Shoulder (Curved)
    bottlePath.quadraticBezierTo(
      centerX - neckWidth / 2, neckHeight + 30, // Control point
      centerX - shoulderWidth / 2, neckHeight + 60, // End point
    );

    // Left Body down to base
    bottlePath.lineTo(centerX - bodyWidth / 2, h - 30);

    // Rounded Base Left
    bottlePath.quadraticBezierTo(centerX - bodyWidth / 2, h, centerX, h);

    // Rounded Base Right
    bottlePath.quadraticBezierTo(
        centerX + bodyWidth / 2, h, centerX + bodyWidth / 2, h - 30);

    // Right Body up to shoulder
    bottlePath.lineTo(centerX + shoulderWidth / 2, neckHeight + 60);

    // Right Shoulder (Curved)
    bottlePath.quadraticBezierTo(centerX + neckWidth / 2, neckHeight + 30,
        centerX + neckWidth / 2, neckHeight);

    // Neck up to top
    bottlePath.lineTo(centerX + neckWidth / 2, capHeight + 5);
    bottlePath.close();

    // 1. Draw Bottle Back (Translucent Surface)
    final backPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withOpacity(0.05),
          Colors.white.withOpacity(0.01),
          Colors.white.withOpacity(0.05),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(bottlePath, backPaint);

    // 2. Draw Cap (The "Hardware" look)
    final capPaint = Paint()..color = Colors.white.withOpacity(0.15);
    final capRect = Rect.fromCenter(
      center: Offset(centerX, capHeight / 2),
      width: neckWidth + 10,
      height: capHeight,
    );
    canvas.drawRRect(
        RRect.fromRectAndRadius(capRect, const Radius.circular(4)), capPaint);

    // 3. Water Fill with Waves
    if (fillProgress > 0) {
      canvas.save();
      canvas.clipPath(bottlePath); // Clips water precisely to bottle shape

      final waterPath = Path();
      // Calculate height based on full bottle height including neck
      final currentWaterTop = h - (h * fillProgress);

      waterPath.moveTo(-20, h + 20); // Move below base

      // Dynamic Wave across the width
      for (double x = 0; x <= w; x++) {
        double wave1 = math.sin((x / 40) + (wavePhase * 2 * math.pi)) * 6;
        double wave2 = math.cos((x / 70) - (wavePhase * 2 * math.pi)) * 3;
        waterPath.lineTo(x, currentWaterTop + wave1 + wave2);
      }

      waterPath.lineTo(w + 20, h + 20);
      waterPath.close();

      final waterPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accentColor.withOpacity(0.4), // See-through top
            accentColor.withOpacity(0.75), // Deeper bottom
          ],
        ).createShader(
            Offset(0, currentWaterTop) & Size(w, h - currentWaterTop));

      canvas.drawPath(waterPath, waterPaint);

      // 4. Bubbles (Constrained by bottle clip)
      for (var b in bubbles) {
        double bubbleY = h - (b.y * h);
        if (bubbleY > currentWaterTop) {
          canvas.drawCircle(
            Offset(centerX - (bodyWidth / 2) + (b.x * bodyWidth), bubbleY),
            b.radius,
            Paint()..color = Colors.white.withOpacity(b.opacity),
          );
        }
      }
      canvas.restore();
    }

    // 5. Bottle Outline & 3D Reflections
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withOpacity(0.15);
    canvas.drawPath(bottlePath, outlinePaint);

    // Vertical "Specular" Highlight for Cylindrical Look
    final highlightPath = Path()
      ..addRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(
            centerX - (neckWidth / 2) + 5, capHeight + 20, 4, h * 0.7),
        topLeft: const Radius.circular(10),
        bottomLeft: const Radius.circular(10),
      ));
    canvas.drawPath(
        highlightPath,
        Paint()
          ..color = Colors.white.withOpacity(0.1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  }

  @override
  bool shouldRepaint(covariant PremiumWaterPainter oldDelegate) => true;
}
