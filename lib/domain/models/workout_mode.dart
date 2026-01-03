import 'package:flutter/material.dart';
import '../../ui/theme/workouts_design_tokens.dart';

enum WorkoutMode {
  cozy,
  normal,
  tuff;

  String get displayName {
    switch (this) {
      case WorkoutMode.cozy: return 'Cozy';
      case WorkoutMode.normal: return 'Normal';
      case WorkoutMode.tuff: return 'Tuff';
    }
  }

  String get description {
    switch (this) {
      case WorkoutMode.cozy: return 'Gentle start';
      case WorkoutMode.normal: return 'Balanced pace';
      case WorkoutMode.tuff: return 'Maximum gains';
    }
  }

  Color get color {
    switch (this) {
      case WorkoutMode.cozy: return WorkoutsDesignTokens.cozyGreen;
      case WorkoutMode.normal: return WorkoutsDesignTokens.normalBlue;
      case WorkoutMode.tuff: return WorkoutsDesignTokens.tuffOrange;
    }
  }

  LinearGradient get gradient {
    switch (this) {
      case WorkoutMode.cozy: return WorkoutsDesignTokens.cozyGradient;
      case WorkoutMode.normal: return WorkoutsDesignTokens.normalGradient;
      case WorkoutMode.tuff: return WorkoutsDesignTokens.tuffGradient;
    }
  }

  IconData get icon {
    switch (this) {
      case WorkoutMode.cozy: return Icons.self_improvement;
      case WorkoutMode.normal: return Icons.fitness_center;
      case WorkoutMode.tuff: return Icons.local_fire_department;
    }
  }

  double get multiplier {
    switch (this) {
      case WorkoutMode.cozy: return 0.7;
      case WorkoutMode.normal: return 1.0;
      case WorkoutMode.tuff: return 1.5;
    }
  }
}
