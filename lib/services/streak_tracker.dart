import 'package:shared_preferences/shared_preferences.dart';

/// Service für Streak-Tracking und Workout-Aufzeichnung
/// Speichert Daten lokal mit SharedPreferences
class StreakTracker {
  static const String _lastWorkoutKey = 'last_workout_date';
  static const String _currentStreakKey = 'current_streak';
  static const String _longestStreakKey = 'longest_streak';
  static const String _totalWorkoutsKey = 'total_workouts';

  /// Gibt die aktuelle Streak zurück
  static Future<int> getCurrentStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastWorkoutStr = prefs.getString(_lastWorkoutKey);
      final currentStreak = prefs.getInt(_currentStreakKey) ?? 0;

      if (lastWorkoutStr == null) return 0;

      final lastWorkout = DateTime.parse(lastWorkoutStr);
      final today = _getDateOnly(DateTime.now());
      final difference = today.difference(_getDateOnly(lastWorkout)).inDays;

      // Streak bleibt erhalten wenn gestern oder heute trainiert wurde
      if (difference <= 1) {
        return currentStreak;
      } else {
        // Streak gebrochen - zurücksetzen
        await prefs.setInt(_currentStreakKey, 0);
        return 0;
      }
    } catch (e) {
      print('Fehler beim Laden der Streak: $e');
      return 0;
    }
  }

  /// Gibt die längste jemals erreichte Streak zurück
  static Future<int> getLongestStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_longestStreakKey) ?? 0;
    } catch (e) {
      print('Fehler beim Laden der längsten Streak: $e');
      return 0;
    }
  }

  /// Gibt die Gesamtanzahl aller Workouts zurück
  static Future<int> getTotalWorkouts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_totalWorkoutsKey) ?? 0;
    } catch (e) {
      print('Fehler beim Laden der Workout-Anzahl: $e');
      return 0;
    }
  }

  /// Workout aufzeichnen und Streak aktualisieren
  static Future<Map<String, dynamic>> recordWorkout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getDateOnly(DateTime.now());
      final todayStr = today.toIso8601String().split('T')[0];
      final lastWorkoutStr = prefs.getString(_lastWorkoutKey);
      final currentStreak = prefs.getInt(_currentStreakKey) ?? 0;
      final longestStreak = prefs.getInt(_longestStreakKey) ?? 0;
      final totalWorkouts = prefs.getInt(_totalWorkoutsKey) ?? 0;

      // Prüfen ob heute bereits trainiert wurde
      if (lastWorkoutStr != null && lastWorkoutStr == todayStr) {
        return {
          'success': true,
          'alreadyRecordedToday': true,
          'streak': currentStreak,
          'message': 'Du hast heute bereits trainiert! 💪',
        };
      }

      // Neuer Trainingstag
      final lastWorkout = lastWorkoutStr != null
          ? _getDateOnly(DateTime.parse(lastWorkoutStr))
          : null;

      final difference = lastWorkout != null
          ? today.difference(lastWorkout).inDays
          : 2;

      int newStreak;
      bool streakIncreased = false;

      if (difference == 1) {
        // Aufeinanderfolgender Tag - Streak erhöhen
        newStreak = currentStreak + 1;
        streakIncreased = true;
      } else if (difference == 0) {
        // Sollte nicht passieren, aber sicherheitshalber
        newStreak = currentStreak;
      } else {
        // Neue Streak starten
        newStreak = 1;
      }

      // Speichern
      await prefs.setString(_lastWorkoutKey, todayStr);
      await prefs.setInt(_currentStreakKey, newStreak);
      await prefs.setInt(_totalWorkoutsKey, totalWorkouts + 1);

      // Längste Streak aktualisieren falls nötig
      if (newStreak > longestStreak) {
        await prefs.setInt(_longestStreakKey, newStreak);
      }

      return {
        'success': true,
        'alreadyRecordedToday': false,
        'streak': newStreak,
        'streakIncreased': streakIncreased,
        'isNewRecord': newStreak > longestStreak,
        'message': _getSuccessMessage(newStreak, streakIncreased),
      };
    } catch (e) {
      print('Fehler beim Aufzeichnen des Workouts: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Prüft ob heute bereits trainiert wurde
  static Future<bool> hasWorkedOutToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastWorkoutStr = prefs.getString(_lastWorkoutKey);

      if (lastWorkoutStr == null) return false;

      final today = _getDateOnly(DateTime.now());
      final todayStr = today.toIso8601String().split('T')[0];

      return lastWorkoutStr == todayStr;
    } catch (e) {
      print('Fehler beim Prüfen des Workout-Status: $e');
      return false;
    }
  }

  /// Streak manuell zurücksetzen (für Testing oder User-Request)
  static Future<void> resetStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastWorkoutKey);
      await prefs.remove(_currentStreakKey);
      // Längste Streak und Total Workouts bleiben erhalten
    } catch (e) {
      print('Fehler beim Zurücksetzen der Streak: $e');
    }
  }

  /// ALLE Daten zurücksetzen (komplett neu starten)
  static Future<void> resetAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastWorkoutKey);
      await prefs.remove(_currentStreakKey);
      await prefs.remove(_longestStreakKey);
      await prefs.remove(_totalWorkoutsKey);
    } catch (e) {
      print('Fehler beim Zurücksetzen aller Daten: $e');
    }
  }

  /// Hilfsmethode: Gibt nur das Datum ohne Uhrzeit zurück
  static DateTime _getDateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Generiert eine motivierende Nachricht basierend auf der Streak
  static String _getSuccessMessage(int streak, bool streakIncreased) {
    if (!streakIncreased) {
      return 'Streak gestartet! 🎯';
    }

    if (streak == 2) return 'Tag 2! Bleib dran! 💪';
    if (streak == 3) return '3 Tage Streak! 🔥';
    if (streak == 7) return 'Eine ganze Woche! Unglaublich! 🏆';
    if (streak == 14) return '2 Wochen! Du bist eine Maschine! 🚀';
    if (streak == 30) return '30 Tage! LEGENDE! 👑';
    if (streak == 50) return '50 Tage! Unfassbar! 🌟';
    if (streak == 100) return '100 TAGE STREAK! 💯🔥';

    if (streak % 10 == 0) {
      return '$streak Tage Streak! 🔥';
    }

    return '$streak Tage und weiter gehts! 💪';
  }

  /// Debug-Methode: Gibt alle gespeicherten Daten aus
  static Future<void> debugPrintStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      print('=== STREAK DEBUG INFO ===');
      print('Letztes Workout: ${prefs.getString(_lastWorkoutKey)}');
      print('Aktuelle Streak: ${prefs.getInt(_currentStreakKey)}');
      print('Längste Streak: ${prefs.getInt(_longestStreakKey)}');
      print('Total Workouts: ${prefs.getInt(_totalWorkoutsKey)}');
      print('========================');
    } catch (e) {
      print('Fehler beim Debug-Print: $e');
    }
  }
}



