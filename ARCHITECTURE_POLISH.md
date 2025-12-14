# PUSHIN MVP Architecture Polish - Pre-UI State Mapping

## Overview

This document explains the surgical refinements made to harden the PUSHIN MVP core architecture before UI state mapping (Prompt F). All changes maintain BMAD v6 compliance and preserve existing semantics.

---

## A) EXPIRED State - Now Explicit and Stable

### Problem Addressed
EXPIRED was previously a transient state that could collapse into LOCKED on the next tick, making it difficult to reason about and map to UI states.

### Changes Made

**PushinController.tick()**:
- **Idempotent transitions**: `expiredAt` is set exactly once when UNLOCKED expires
- **Explicit persistence check**: EXPIRED remains until `now >= expiredAt + gracePeriodSeconds`
- **Guard clause**: `if (_expiredAt == null)` ensures `expiredAt` is set only once

### Why This Matters for UI State Mapping

UI state mapping (Prompt F) requires stable, observable states. EXPIRED must:
1. **Be observable**: UI can detect and display grace period countdown
2. **Persist predictably**: Multiple tick() calls within grace period don't cause flicker
3. **Transition deterministically**: Clear boundary when grace period elapses

Without this hardening, UI would see flickering between EXPIRED and LOCKED states during grace period, making countdown displays impossible.

---

## B) App Blocking - Explicit State Handling

### Problem Addressed
AppBlockingService used boolean shortcut logic (`currentState != PushinState.unlocked`) which collapses LOCKED, EARNING, and EXPIRED into a single "blocked" category.

### Changes Made

**MockAppBlockingService**:
- **Explicit switch statements**: Each state (LOCKED, EARNING, UNLOCKED, EXPIRED) handled explicitly
- **Future-proof structure**: Allows different blocking behavior per state in UI layer
- **Platform-agnostic**: No platform-specific logic introduced

### Why This Matters for UI State Mapping

UI state mapping will need to:
1. **Display different messages**: "Locked" vs "Earning" vs "Expired (grace period)"
2. **Show different actions**: "Start workout" vs "Continue workout" vs "Time expired"
3. **Handle state-specific UI**: Each state may have unique visual indicators

The explicit switch structure allows UI layer to query blocking service and receive state-specific results without controller changes.

---

## C) Test Hardening - Domain Contract Assertions

### Changes Made

**New Test: `UnlockSession.durationSeconds equals Workout.earnedTimeSeconds`**
- **Purpose**: Asserts domain contract that unlock duration comes from Workout model
- **Why**: Ensures no magic numbers leak into session creation

**Enhanced Test: `EXPIRED persists across multiple tick calls within grace period`**
- **Purpose**: Proves EXPIRED is stable state, not transient
- **Why**: Validates idempotent behavior required for UI state mapping

**Enhanced Test: `EXPIRED → LOCKED only after gracePeriodSeconds fully elapsed`**
- **Purpose**: Proves exact boundary condition for state transition
- **Why**: UI needs precise timing for countdown displays

### Why This Matters

These tests ensure:
1. **Domain contracts are enforced**: Workout.earnedTimeSeconds is the single source of truth
2. **State stability**: EXPIRED behaves predictably for UI rendering
3. **Boundary correctness**: Grace period transitions are deterministic

---

## Architecture Principles Maintained

✅ **Time Injection**: All time-dependent operations require explicit `DateTime now`  
✅ **Single Source of Truth**: Controller owns state, services are stateless  
✅ **Domain-Driven**: Unlock duration from Workout model, no magic numbers  
✅ **Deterministic**: All operations testable with explicit time values  
✅ **Platform Agnostic**: No platform-specific code or assumptions  

---

## Ready for Prompt F

The architecture is now:
- **Stable**: EXPIRED is a first-class state with predictable persistence
- **Explicit**: App blocking handles each state distinctly
- **Tested**: Domain contracts and state transitions are fully validated
- **UI-Ready**: State structure supports UI state mapping without core changes

**The PUSHIN MVP core is now architecturally sealed and ready for Prompt F (UI State Mapping).**

