import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import '../theme/workouts_design_tokens.dart';
import '../widgets/GOStepsBackground.dart';

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

    // Animate water fill smoothly but quickly without bounce
    final newFill = (_currentAmount / _targetAmount).clamp(0.0, 1.0);
    _fillAnimation = Tween<double>(begin: oldFill, end: newFill).animate(
        CurvedAnimation(parent: _mainController, curve: Curves.linear));

    // Quick smooth animation
    _mainController.duration = const Duration(milliseconds: 200);
    _mainController.forward(from: 0);
  }

  @override
  void dispose() {
    _mainController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive sizing based on screen width
    final percentageFontSize = screenWidth * 0.25; // ~25% of screen width
    final goalTextFontSize = screenWidth * 0.03; // ~3% of screen width
    final verticalOffset = screenHeight * -0.02; // -2% of screen height
    final textSpacing = screenHeight * -0.01; // -1% of screen height

    return WillPopScope(
      onWillPop: () async => true,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          // Only respond to swipe from left edge (first 25% of screen width)
          // and check if the velocity suggests a back swipe
          if (details.localPosition.dx < screenWidth * 0.25 &&
              details.velocity.pixelsPerSecond.dx > 200) {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 22),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            actions: [
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.onEditGoal?.call();
                },
                icon:
                    const Icon(Icons.settings_outlined, color: Colors.white70),
              )
            ],
          ),
          body: GOStepsBackground(
            child: Stack(
              alignment: Alignment.center,
              children: [
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
                  // Setting bottom to false allows us to handle the bottom padding manually
                  // so the buttons can sit closer to the physical edge if desired.
                  bottom: false,
                  child: Column(
                    children: [
                      // Top Percentage
                      Transform.translate(
                        offset: Offset(0, verticalOffset),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                              begin: 0,
                              end: (_currentAmount / _targetAmount) * 100),
                          duration: const Duration(milliseconds: 1000),
                          builder: (context, value, child) => Column(
                            children: [
                              Text(
                                "${value.toInt()}%",
                                style: TextStyle(
                                    fontSize: percentageFontSize,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white),
                              ),
                              Transform.translate(
                                offset: Offset(0, textSpacing),
                                child: Text(
                                  "DAILY GOAL",
                                  style: TextStyle(
                                      fontSize: goalTextFontSize,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.5),
                                      letterSpacing: 2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // The Glass Container - This fills all available middle space
                      Expanded(
                        child: AnimatedBuilder(
                          animation: Listenable.merge(
                              [_mainController, _waveController]),
                          builder: (context, child) {
                            _updateBubbles();
                            return Center(
                              child: CustomPaint(
                                size: const Size(200, 450),
                                painter: PremiumWaterPainter(
                                  fillProgress: _fillAnimation.value,
                                  wavePhase: _waveController.value,
                                  bubbles: _bubbles,
                                  accentColor: WorkoutsDesignTokens.waterCyan,
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Spacer to position minus button more centrally between bottle and add buttons
                      const SizedBox(height: 24),

                      // Minus Button (Undo Last)
                      _buildRemoveButton(),

                      // Spacer between Remove button and Intake buttons
                      const SizedBox(height: 32),

                      // Pill Shape Intake Buttons
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          0,
                          24,
                          // This ensures buttons respect the system "Home Bar" on modern phones
                          MediaQuery.of(context).padding.bottom > 0
                              ? MediaQuery.of(context).padding.bottom
                              : 20,
                        ),
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
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: hasData ? Colors.red : Colors.grey.shade600,
          shape: BoxShape.circle,
          boxShadow: hasData
              ? [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: const Icon(
          Icons.remove,
          color: Colors.white,
          size: 24,
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
  bool shouldRepaint(covariant PremiumWaterPainter oldDelegate) {
    return oldDelegate.fillProgress != fillProgress ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.bubbles.length != bubbles.length ||
        oldDelegate.accentColor != accentColor;
  }
}
