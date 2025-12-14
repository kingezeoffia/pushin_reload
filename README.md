# PUSHIN MVP

A Flutter app that helps users regain control of their digital life through workout-based screen time management.

## 🎯 Overview

PUSHIN is an iOS-first, Android-ready Flutter MVP that combines physical activity with digital wellness. Users must complete workouts to unlock access to blocked apps and websites, creating a healthy balance between screen time and physical activity.

## 🏗️ Architecture

This project implements a **BMAD Method v6 compliant** architecture with:

- **Clean State Machine**: LOCKED → EARNING → UNLOCKED → EXPIRED → LOCKED
- **Domain-Driven Design**: Pure Dart models with explicit time handling
- **Service Layer**: Stateless calculators for workout tracking, unlock management, and content blocking
- **Controller Pattern**: Single source of truth for application state
- **Time Injection**: Fully deterministic, testable time handling
- **Platform Agnostic**: Ready for Apple Screen Time and Android integrations

## 📁 Project Structure

```
lib/
├── controller/
│   └── PushinController.dart          # State machine orchestrator
├── domain/
│   ├── Workout.dart                   # Reps-based workout model
│   ├── UnlockSession.dart             # Time-based unlock session
│   ├── AppBlockTarget.dart            # Blockable content targets
│   └── PushinState.dart               # State machine enum
└── services/
    ├── AppBlockingService.dart        # Blocking contract interface
    ├── WorkoutTrackingService.dart    # Workout tracking interface
    ├── UnlockService.dart             # Unlock session management
    └── Mock*.dart                     # Test implementations

test/
└── pushin_controller_test.dart        # Comprehensive unit tests
```

## 🚀 Key Features

### Core State Machine
- **LOCKED**: Content blocked, must start workout
- **EARNING**: Workout in progress, content blocked
- **UNLOCKED**: Workout completed, content accessible
- **EXPIRED**: Unlock time elapsed, grace period active

### Blocking Contract
- **Platform Agnostic**: Works with Apple Screen Time, Android Digital Wellbeing, or mocks
- **Target Lists Only**: No boolean blocking APIs - UI derives from target lists
- **Granular Control**: Knows exactly which apps/sites are blocked/accessible

### Time Handling
- **Explicit Injection**: All time-dependent logic receives `DateTime now`
- **Deterministic**: Same inputs produce same outputs
- **Testable**: Mock time for reliable testing

## 🛠️ Development

### Prerequisites
- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)

### Setup
```bash
# Install dependencies
flutter pub get

# Run tests
flutter test

# Run on device/emulator
flutter run
```

### Testing
```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

## 📚 Documentation

- **[BLOCKING_CONTRACT.md](./BLOCKING_CONTRACT.md)** - Blocking API contract specification
- **[ARCHITECTURE_HARDENING.md](./ARCHITECTURE_HARDENING.md)** - Core architecture hardening details
- **[ARCHITECTURE_POLISH.md](./ARCHITECTURE_POLISH.md)** - Final architecture polish
- **[MINI_RECOMMENDATION_LOGIC.md](./MINI_RECOMMENDATION_LOGIC.md)** - UI recommendation logic specification
- **[README-BMAD.md](./README-BMAD.md)** - BMAD Method setup guide

## 🎨 BMAD Method Integration

This project uses **BMAD Method v6** for development:

- **Product Manager**: `@.bmad/bmm/agents/pm`
- **Software Architect**: `@.bmad/bmm/agents/architect`
- **Solo Developer**: `@.bmad/bmm/agents/quick-flow-solo-dev`

See [README-BMAD.md](./README-BMAD.md) for usage instructions.

## 🔄 Current Status

✅ **Architecture Complete**: Core state machine implemented and tested
✅ **BMAD v6 Compliant**: Follows all architectural principles
✅ **Time Injection**: Fully deterministic time handling
✅ **Blocking Contract**: Platform-agnostic blocking ready
✅ **Unit Tests**: Comprehensive test coverage
✅ **Documentation**: Complete specification and guides

## 🚀 Next Steps

1. **UI State Mapping**: Implement Flutter UI that maps to state machine
2. **Platform Integration**: Add Apple Screen Time and Android Digital Wellbeing
3. **Persistence**: Add local data storage for workouts and sessions
4. **Analytics**: Add usage tracking (privacy-focused)

## 📄 License

This project is part of the PUSHIN MVP development using BMAD Method v6.

## 🤝 Contributing

This project follows BMAD Method v6 development practices. See [README-BMAD.md](./README-BMAD.md) for development workflow.

---

**Built with ❤️ using BMAD Method v6**

