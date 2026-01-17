import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../theme/pushin_theme.dart';

/// Native Apple Liquid Glass implementation for iOS
/// Uses UIVisualEffectView with UIBlurEffect for authentic Apple blur
class NativeLiquidGlass extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final bool useUltraThinMaterial;

  const NativeLiquidGlass({
    Key? key,
    required this.child,
    this.borderRadius = 32.0,
    this.blurSigma = 20.0,
    this.useUltraThinMaterial = true,
  }) : super(key: key);

  @override
  State<NativeLiquidGlass> createState() => _NativeLiquidGlassState();
}

class _NativeLiquidGlassState extends State<NativeLiquidGlass> {
  static const MethodChannel _channel =
      MethodChannel('com.pushin.native_liquid_glass');

  @override
  Widget build(BuildContext context) {
    // On iOS, use native implementation
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _buildNativeGlass();
    }

    // On other platforms, fallback to Flutter implementation
    return _buildFlutterFallback();
  }

  Widget _buildNativeGlass() {
    return FutureBuilder<bool>(
      future: _isNativeSupported(),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return SizedBox(
            width: double.infinity,
            height: 64, // Match original height
            child: Stack(
              children: [
                // Native iOS blur view using UiKitView for iOS
                UiKitView(
                  viewType: 'native_liquid_glass',
                  creationParams: <String, dynamic>{
                    'borderRadius': widget.borderRadius,
                    'blurSigma': widget.blurSigma,
                    'useUltraThinMaterial': widget.useUltraThinMaterial,
                  },
                  creationParamsCodec: const StandardMessageCodec(),
                ),
                // Content overlay
                widget.child,
              ],
            ),
          );
        } else {
          // Fallback to Flutter implementation
          return _buildFlutterFallback();
        }
      },
    );
  }

  Future<bool> _isNativeSupported() async {
    try {
      final result = await _channel.invokeMethod('isSupported');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  Widget _buildFlutterFallback() {
    // Enhanced Flutter fallback - very close to Apple but not native
    return SizedBox(
      height: 64, // Match original height
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Stack(
            children: [
              // ULTRA-BRIGHT APPLE LIQUID GLASS - Minimal blur, maximum transparency
              BackdropFilter(
                filter: ImageFilter.blur(
                    sigmaX: widget.blurSigma * 0.3,
                    sigmaY: widget.blurSigma * 0.3), // MINIMAL blur
                child: Container(
                  color:
                      Colors.white.withOpacity(0.01), // EXTREMELY transparent
                ),
              ),
              // No gradients or highlights - completely flat
              // Just the border - clean and modern
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: PushinTheme.primaryBlue
                        .withOpacity(0.3), // PURPLE border
                    width: 0.8, // Thicker outline
                  ),
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  // No shadows - completely flat
                ),
              ),
              // Content
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}
