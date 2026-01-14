# PUSHIN' MVP - Product Requirements Document (PRD)

**Version**: 1.0  
**Date**: December 15, 2025  
**Status**: Draft  
**Owner**: Product Team

---

## 📋 Executive Summary

**PUSHIN'** is a freemium iOS/Android fitness-gamification app that helps users regain control of their digital life by requiring physical workouts to unlock screen time. Users select apps/websites to block, choose workouts, and earn unlock time by completing reps tracked via device sensors or camera.

### Business Model
- **Free Plan**: Ad-supported, 1 blocked app, 1 workout (Push-Ups), max 1 hour/day unlock time
- **Standard Plan** (€9.99/month): Ad-free, 3 blocked apps, 3 workouts
- **Advanced Plan** (€14.99/month): Ad-free, 5 blocked apps, 5 workouts

### Success Metrics
- **Primary KPI**: Daily Active Users (DAU) completing ≥1 workout
- **Monetization KPI**: Free-to-Paid conversion rate (target: 8-12%)
- **Engagement KPI**: Average daily workouts per user (target: 2.5+)
- **Retention KPI**: D7 retention (target: 40%+)

---

## 🎯 Product Vision & Goals

### Vision Statement
*"Transform phone addiction into fitness motivation—one rep at a time."*

### MVP Goals
1. **Validate Core Loop**: Prove users will complete workouts to unlock screen time
2. **Freemium Validation**: Test willingness to pay for more workouts/blocks
3. **Technical Feasibility**: Validate Apple Screen Time / Android blocking integrations
4. **Retention Baseline**: Establish D7/D30 retention benchmarks

### Out of Scope for MVP
- Social features (leaderboards, challenges, friends)
- Workout programs or coaching
- Apple Watch / wearable integrations
- Custom workout creation
- Family plans or admin controls

---

## 👥 Target Audience

### Primary Persona: **"Distracted Dave"**
- **Age**: 22-35
- **Occupation**: Knowledge worker, student, creative professional
- **Pain Point**: Knows he spends too much time on Instagram/TikTok/Reddit
- **Motivation**: Wants to get fit AND reduce screen time
- **Tech Savvy**: Comfortable with app permissions, willing to grant Screen Time access
- **Quote**: *"I need something more extreme than Screen Time limits—I just ignore those."*

### Secondary Persona: **"Busy Parent Brenda"**
- **Age**: 30-45
- **Occupation**: Working parent
- **Pain Point**: Scrolls social media after kids sleep, regrets lost time
- **Motivation**: Role model for kids, health goals
- **Quote**: *"If I had to do 20 squats before opening Facebook, maybe I'd finally stop."*

---

## 🏗️ System Architecture Context

### Existing State Machine (from Architecture Docs)
```
LOCKED → EARNING → UNLOCKED → EXPIRED → LOCKED
```

| State | Description | Screen Access | Next Transition |
|-------|-------------|---------------|----------------|
| **LOCKED** | Content blocked, no active session | Block screen / Home | Start workout → EARNING |
| **EARNING** | Workout in progress | Workout tracker screen | Complete → UNLOCKED |
| **UNLOCKED** | Active unlock session | Full app access | Time expires → EXPIRED |
| **EXPIRED** | Grace period (30s) | Grace notice overlay | Grace expires → LOCKED |

### Domain Models (Pre-Existing)
- `Workout` - Reps-based workout with `earnedTimeSeconds`
- `UnlockSession` - Time-based unlock session tracking
- `AppBlockTarget` - Blocked apps/sites list
- `PushinState` - State machine enum

---

## 💰 Paywall Tiers & Feature Matrix

| Feature | Free | Standard (€9.99/mo) | Advanced (€14.99/mo) |
|---------|------|---------------------|----------------------|
| **Ads** | ✅ Banner + Interstitial | ❌ Ad-free | ❌ Ad-free |
| **Blocked Apps** | 1 | 3 | 5 |
| **Available Workouts** | Push-Ups only | 3 workouts | 5 workouts |
| **Max Daily Unlock Time** | 1 hour | 3 hours | Unlimited |
| **Workout Types** | Push-Ups | Push-Ups, Squats, Sit-Ups | All + Plank, Jumping Jacks |
| **Grace Period** | 30 seconds | 60 seconds | 120 seconds |
| **Analytics Dashboard** | ❌ | ✅ Weekly stats | ✅ Detailed insights |

### Paywall Trigger Points
1. **App Block Selection**: Attempting to add 2nd blocked app (Free → Standard)
2. **Workout Selection**: Tapping a locked workout (grayed-out workout card)
3. **Daily Limit Reached**: Completing workout when 1hr daily cap reached (Free only)
4. **Settings → Upgrade**: Dedicated "Upgrade Plan" menu item
5. **Post-Workout Interstitial**: After 3rd workout completion (Free only, 20% show rate)

---

## 📱 User Flows & Acceptance Criteria

### Flow 1: First-Time Onboarding

**User Story**: *As a new user, I want a quick, motivating onboarding experience that explains the app's value and gets me to my first workout ASAP.*

#### Screens (Based on Visual References Provided)

**Screen 1: Welcome Splash**
- **Visual Reference**: Screenshot 1 (Blue gradient, "your plan is ready! are you?")
- **Content**:
  - Hero headline: *"your plan is ready! are you?"* (white + blue accent text)
  - Subheadline: "Start and experience your first week journey with us for free. Let's get you closer to your goal!"
  - Goal card preview: "Run 1 km + Walk 4 km • Jogging Intervals"
  - CTA: Large pill button "Let's GO!"
- **Acceptance Criteria**:
  - [ ] Displays on first app launch only
  - [ ] Full-screen immersive (no nav bar)
  - [ ] Button tap advances to Screen 2
  - [ ] Uses GO Club color palette (blue #4F46E5 gradient to #3B82F6)

**Screen 2: Fitness Level Selection**
- **Visual Reference**: Screenshot 2 ("Current fitness level?")
- **Content**:
  - Back button (top-left)
  - Icon: 3 overlapping rounded squares (blue gradient)
  - Headline: "Current fitness level?"
  - 4 options (2x2 grid): Beginner, Intermediate, Advanced, Athletic
  - Next button (bottom, faded until selection made)
- **Acceptance Criteria**:
  - [ ] Exactly 4 options, single-select only
  - [ ] Selection highlights button (darker blue fill)
  - [ ] "Next" button enables only after selection
  - [ ] Stored as user profile metadata (not blocking MVP launch)

**Screen 3: AI Recommendation Transition**
- **Visual Reference**: Screenshot 3 ("here's something just for you")
- **Content**:
  - Animated concentric circles (blue dots radiating outward)
  - Headline: "here's something just for you" (blue accent on "something")
  - Body: "Sit back, relax, and let GO AI do the thinking. You'll be walking like a pro in no time."
- **Acceptance Criteria**:
  - [ ] Auto-advances after 2 seconds (no tap required)
  - [ ] Circles animate smoothly (pulse effect)
  - [ ] Feels premium, not "loading spinner"

**Screen 4: Daily Steps Goal**
- **Visual Reference**: Screenshot 4 ("Daily steps")
- **Content**:
  - Back button (top-left)
  - Icon: Running shoe (blue gradient 3D)
  - Headline: "Daily steps"
  - Large number: "10,000" with +/- steppers
  - Info callout: "10,000 steps: A popular goal that can help keep your heart healthy, control diabetes, and aid in weight loss."
  - CTA: "Done" button (bottom)
- **Acceptance Criteria**:
  - [ ] Stepper buttons adjust in increments of 1,000 (range: 2,000 - 20,000)
  - [ ] Default value: 10,000
  - [ ] Info text updates dynamically per step count (future: remove for MVP simplicity)
  - [ ] "Done" button always enabled

**Screen 5: Primary Goal Selection**
- **Visual Reference**: Screenshot 5 ("What's your primary goal?")
- **Content**:
  - Icon: Target with arrow (blue gradient)
  - Headline: "What's your primary goal?"
  - 2 options: "Lose weight" | "Daily activity"
  - Next button (bottom, faded)
- **Acceptance Criteria**:
  - [ ] Single-select radio buttons
  - [ ] Selection highlights button
  - [ ] "Next" enabled only after selection
  - [ ] Goal stored but doesn't affect MVP workout logic (future: personalized plans)

**Screen 6: Apple Health Integration**
- **Visual Reference**: Screenshot 6 ("link to Apple Health")
- **Content**:
  - Icons: Apple Health (pink heart) + GO App (blue) + link icon
  - Headline: "link to Apple Health" (blue accent)
  - Body: "With this access, we can create a more personalised experience for you."
  - Divider line
  - Privacy section: Lock icon + reassurance text
  - CTA: "Continue" button (bottom)
- **Acceptance Criteria**:
  - [ ] "Continue" → triggers iOS HealthKit permission prompt
  - [ ] If user denies: show non-blocking warning, proceed to Screen 7
  - [ ] If granted: log success, proceed to Screen 7
  - [ ] Privacy text: "Your health data is never stored or shared with third parties. It remains private and is used only to enhance your experience while ensuring the highest standards of security."

**Screen 7: Workout Frequency**
- **Visual Reference**: Screenshot 7 ("How often can you walk?")
- **Content**:
  - Icon: Clock (blue gradient)
  - Headline: "How often can you walk?"
  - 6 options (2x3 grid):
    - 1 day / week
    - 2 days / week
    - 3 days / week
    - 4 days / week
    - 5-6 days / week
    - Daily
  - Next button (bottom)
- **Acceptance Criteria**:
  - [ ] Single-select, Next enabled after selection
  - [ ] Stored as user preference (future: notification cadence)
  - [ ] Next → completes onboarding → navigate to Home Screen (LOCKED state)

---

### Flow 2: App Block Setup

**User Story**: *As a user, I want to select which apps to block so PUSHIN' enforces my commitment.*

#### Screen: App Block Selection

**Entry Point**: 
- Home screen (LOCKED state) → "⚙️ Settings" → "Blocked Apps"
- OR first-time prompt after onboarding: "Let's block your first distracting app!"

**Layout**:
- **Header**: "Block Distracting Apps" + Info icon (explains blocking)
- **Current Plan Badge**: 
  - Free: "Free Plan: 1/1 apps blocked" (yellow badge)
  - Standard: "Standard Plan: 2/3 apps blocked" (blue badge)
  - Advanced: "Advanced Plan: 4/5 apps blocked" (purple badge)
- **Search Bar**: "Search apps..." (filters installed apps list)
- **App List**: 
  - Shows all installed apps (via iOS Screen Time / Android UsageStats API)
  - Each row: App icon + App name + Toggle switch
  - Blocked apps: Toggle ON (blue), shows checkmark
  - Unblocked apps: Toggle OFF (gray)
- **Upgrade CTA** (if at limit): 
  - Banner: "Want to block more apps? Upgrade to Standard" → Taps to Paywall

**Acceptance Criteria**:
- [ ] **Free Plan**: Can enable 1 toggle. Attempting 2nd → show paywall modal
- [ ] **Standard Plan**: Can enable up to 3 toggles. 4th attempt → show paywall (upgrade to Advanced)
- [ ] **Advanced Plan**: Can enable up to 5 toggles. 6th attempt → show paywall (or set hard cap)
- [ ] Toggle state persists immediately (save to local DB)
- [ ] Changes take effect on next state transition (don't interrupt active UNLOCKED session)
- [ ] **Paywall Modal** (if triggered):
  - Title: "Unlock More App Blocks"
  - Body: "You've reached your Free plan limit. Upgrade to block up to 3 apps."
  - CTA: "Upgrade to Standard (€9.99/mo)" → Navigate to Paywall screen
  - Dismiss: "Maybe Later" → Close modal

**Platform Integration Notes**:
- **iOS**: Use Screen Time API (`FamilyActivityPicker` for selection, `ManagedSettings` for enforcement)
- **Android**: Use Digital Wellbeing API or `UsageStatsManager` + overlay blocking
- **MVP Fallback**: If platform APIs unavailable, show "blocking not supported" error

---

### Flow 3: Workout Selection & Execution

**User Story**: *As a user in LOCKED state, I want to choose a workout, complete reps, and unlock my blocked apps.*

#### Screen: Home (LOCKED State)

**Layout**:
- **Status Card** (top):
  - Icon: 🔒 Lock icon (large, centered)
  - Headline: "Your apps are blocked"
  - Body: "Complete a workout to unlock 10 minutes of screen time."
  - Blocked apps row: Display 1-5 app icons (grayed out, semi-transparent)
- **Workout Selection Section**:
  - Header: "Choose Your Workout"
  - **Available Workouts** (Free Plan - 1 unlocked):
    - **Push-Ups** (ACTIVE):
      - Card style: Blue gradient, full opacity
      - Icon: Push-up illustration
      - Title: "Push-Ups"
      - Badge: "20 reps = 10 min unlock"
      - CTA: "Start Workout" button
    - **Squats** (LOCKED):
      - Card style: Grayed out, 40% opacity, lock icon overlay
      - Icon: Squat illustration (desaturated)
      - Title: "Squats" (gray text)
      - Badge: "🔒 Standard Plan"
      - Tap behavior: Show paywall modal
    - **Sit-Ups** (LOCKED):
      - Same as Squats
    - **Plank** (LOCKED - Advanced only):
      - Card style: Grayed out, 40% opacity, lock icon overlay
      - Badge: "🔒 Advanced Plan"
    - **Jumping Jacks** (LOCKED - Advanced only):
      - Same as Plank
- **Footer**:
  - Link: "View Workout History" → Navigate to History screen (future)
  - Link: "Upgrade Plan" → Navigate to Paywall

**Acceptance Criteria**:
- [ ] **Free Plan**: Only Push-Ups card is tappable and full-color
- [ ] **Standard Plan**: Push-Ups, Squats, Sit-Ups cards active; Plank/JJ grayed
- [ ] **Advanced Plan**: All 5 workout cards active and full-color
- [ ] Tapping locked workout → Show paywall modal:
  - Title: "Unlock More Workouts"
  - Body: "Squats are available in the Standard plan. Upgrade to access 3 workout types."
  - CTA: "Upgrade to Standard (€9.99/mo)"
  - Dismiss: "Not Now"
- [ ] Tapping "Start Workout" (Push-Ups) → Navigate to Workout Tracker screen (state: EARNING)
- [ ] Blocked apps row displays user's selected apps (max 5), grayed out
- [ ] If 0 apps blocked: Show banner "⚠️ You haven't blocked any apps yet. Tap here to set it up."

---

#### Screen: Workout Tracker (EARNING State)

**Entry Point**: Tapping "Start Workout" on active workout card (Home screen, LOCKED state)

**Layout**:
- **Header**:
  - Back button (top-left): "Cancel" → Show confirmation modal ("Stop workout? Progress will be lost.")
  - Timer: "00:45" (elapsed time, counts up)
- **Hero Section**:
  - Large circular progress ring (blue stroke, gray background)
    - Shows reps completed / total reps (e.g., "12 / 20")
    - Progress fills clockwise
  - Center: Rep counter (huge font): "12"
  - Below ring: "Push-Ups Completed"
- **Camera/Sensor Feed**:
  - **iOS**: Uses Vision framework for pose detection (front camera view)
  - **Android**: Uses ML Kit Pose Detection
  - **Overlay**: Skeleton overlay on user's body (real-time feedback)
  - **Feedback**: Green checkmark flash when rep counted
- **Instructions Panel** (bottom sheet, collapsible):
  - "How to do a proper push-up"
  - Illustration + 3 bullet points
  - User can swipe down to hide
- **Motivation Elements**:
  - Haptic feedback on each rep counted
  - Encouraging text every 5 reps: "You're crushing it! 💪", "Halfway there!", "Final push!"

**Acceptance Criteria**:
- [ ] Camera permission requested on first workout (if denied, fall back to manual rep counter)
- [ ] Rep counting uses ML pose detection:
  - Push-up rep = down position (elbows bent 90°) → up position (arms extended)
  - 500ms cooldown between reps (prevent double-counting)
- [ ] Manual fallback: "Can't detect? Tap to count manually" button (bottom)
- [ ] Progress ring animates smoothly (0-100%)
- [ ] On completion (20/20 reps):
  - Confetti animation
  - Success modal: "Workout Complete! 🎉"
  - Body: "You've unlocked 10 minutes of screen time."
  - CTA: "Unlock My Apps" → Navigate to Home screen (state: UNLOCKED)
- [ ] Timer saves to workout history (for analytics)

---

#### Screen: Home (UNLOCKED State)

**Layout**:
- **Status Card** (top):
  - Icon: ✅ Unlocked icon (green checkmark)
  - Headline: "Apps Unlocked!"
  - **Countdown Timer**: "8:32 remaining" (large, prominent, counts down in real-time)
  - Progress bar: Visual bar depleting left-to-right (green → yellow → red)
  - Body: "Use your earned time wisely. Apps will lock again when time expires."
  - Blocked apps row: Display app icons in full color (no longer grayed)
- **Quick Actions**:
  - Button: "Earn More Time" → Navigate back to Workout Selection (LOCKED screen)
  - Button: "End Session Early" → Confirm modal → Transition to LOCKED (forfeit remaining time)
- **Stats Panel** (collapsible):
  - "Today's Activity"
  - Workouts completed: 3
  - Total unlock time earned: 30 minutes
  - Time used: 21 minutes
  - Reps completed: 60 push-ups

**Acceptance Criteria**:
- [ ] Timer updates every second (real-time countdown)
- [ ] When timer reaches 0:00 → Transition to EXPIRED state (grace period)
- [ ] Progress bar color changes:
  - Green: >5 min remaining
  - Yellow: 2-5 min remaining
  - Red: <2 min remaining
- [ ] Tapping "Earn More Time" → State remains UNLOCKED, navigate to Workout Selection, allow starting new workout (stacks unlock time)
- [ ] "End Session Early" → Confirmation modal:
  - "Are you sure? You have 8:32 remaining."
  - "End Session" → Transition to LOCKED
  - "Keep Session" → Dismiss modal

---

#### Screen: Grace Period Overlay (EXPIRED State)

**Trigger**: UnlockSession timer reaches 0:00, grace period (30s Free, 60s Standard, 120s Advanced) begins

**Layout**:
- **Modal Overlay** (semi-transparent dark background, cannot dismiss):
  - Icon: ⏰ Clock icon (pulsing animation)
  - Headline: "Time's Up!"
  - Body: "Your unlock session has expired. You have 30 seconds to finish what you're doing."
  - **Grace Timer**: "00:28" (counts down, large red text)
  - CTA: "Start New Workout" → Dismiss modal → Navigate to Workout Selection (LOCKED state)
  - Link: "Lock Now" → Immediately transition to LOCKED (skip remaining grace time)
- **Behavior**:
  - Overlay appears over current screen (doesn't navigate away)
  - User can interact with underlying app during grace period
  - When grace timer reaches 0:00 → Force transition to LOCKED, show full-screen block message

**Acceptance Criteria**:
- [ ] Grace period duration based on plan:
  - Free: 30 seconds
  - Standard: 60 seconds
  - Advanced: 120 seconds
- [ ] Timer counts down in real-time (red text, bold)
- [ ] Modal is non-dismissible (no X button, must take action or wait)
- [ ] When grace expires → Transition to LOCKED, show Block Screen
- [ ] "Start New Workout" → Navigate to Home (LOCKED), dismiss overlay
- [ ] "Lock Now" → Immediately transition to LOCKED, dismiss overlay

---

### Flow 4: Paywall Experience

**User Story**: *As a free user who hits a plan limit, I want a clear, compelling paywall that shows me what I'll get if I upgrade.*

#### Screen: Paywall Modal (Triggered)

**Entry Points** (see "Paywall Trigger Points" section above):
1. Attempting to add 2nd blocked app (Free plan limit)
2. Tapping a locked workout card
3. Reaching 1-hour daily unlock limit (Free plan)
4. After 3rd workout completion (interstitial, 20% random show rate)
5. Tapping "Upgrade Plan" anywhere in app

**Layout**:
- **Header**:
  - Dismiss X (top-right, only if triggered from interstitial/settings)
  - Premium badge icon (top-center): Crown or star icon
- **Hero Section**:
  - Headline: "Unlock Your Full Potential" (gradient text)
  - Subheadline: "More workouts. More apps. More freedom."
- **Feature Comparison Table**:
  
  | Feature | Free | Standard | Advanced |
  |---------|------|----------|----------|
  | Blocked Apps | 1 | 3 | 5 |
  | Workouts | 1 | 3 | 5 |
  | Daily Unlock Cap | 1 hour | 3 hours | Unlimited |
  | Ads | Yes | No | No |
  | Grace Period | 30s | 60s | 120s |
  
- **Plan Selection** (segmented control):
  - Two options: "Standard" (selected by default) | "Advanced"
  - Standard card:
    - Badge: "Most Popular"
    - Price: "€9.99 / month"
    - Bullet list: "3 blocked apps", "3 workouts", "Ad-free", "3 hour daily cap"
  - Advanced card:
    - Badge: "Best Value"
    - Price: "€14.99 / month"
    - Bullet list: "5 blocked apps", "5 workouts", "Unlimited unlock time", "Priority support"
- **CTA Button** (large, prominent):
  - Text: "Start Free 5-Day Trial" (if first-time) OR "Subscribe Now"
  - Subtext: "Cancel anytime. Billed monthly."
- **Footer Links**:
  - "Restore Purchases" (if previously subscribed)
  - "Terms of Service" | "Privacy Policy"

**Acceptance Criteria**:
- [ ] Modal blocks interaction with underlying screen (full-screen takeover)
- [ ] Segmented control switches between Standard/Advanced plan details
- [ ] "Start Free Trial" button:
  - Triggers iOS StoreKit / Android Billing API
  - On success: Update user plan tier in database, dismiss modal, unlock features
  - On failure: Show error toast "Purchase failed. Try again."
- [ ] "Restore Purchases" button:
  - Queries StoreKit/Billing for active subscriptions
  - If found: Update user tier, show success toast
  - If not found: Show error "No active subscriptions found"
- [ ] Dismiss X only enabled if:
  - User came from Settings "Upgrade" button (optional action)
  - Interstitial context (20% post-workout show rate)
  - NOT enabled if: Triggered by hard limit (e.g., trying to add 2nd app) → Must take action or use "Maybe Later" escape hatch
- [ ] "Maybe Later" button (subtle, bottom):
  - Only shown in hard-limit contexts
  - Dismisses modal, returns to previous screen, does NOT grant access

---

## 🎨 UI/UX Design System

### Color Palette (GO Club Inspired)
- **Primary Blue**: `#4F46E5` (Indigo 600)
- **Secondary Blue**: `#3B82F6` (Blue 500)
- **Gradient**: `linear-gradient(180deg, #4F46E5 0%, #3B82F6 100%)`
- **Success Green**: `#10B981` (Emerald 500)
- **Warning Yellow**: `#F59E0B` (Amber 500)
- **Error Red**: `#EF4444` (Red 500)
- **Background Dark**: `#0F172A` (Slate 900)
- **Background Light**: `#F8FAFC` (Slate 50)
- **Text Primary**: `#FFFFFF` (White, on dark backgrounds)
- **Text Secondary**: `#94A3B8` (Slate 400)

### Typography
- **Headline Font**: SF Pro Display (iOS) / Roboto (Android), Bold, 32-40pt
- **Body Font**: SF Pro Text / Roboto, Regular, 16-18pt
- **Accent Text**: Same as headline, but specific words in gradient blue
- **Button Text**: SF Pro / Roboto, Semibold, 18pt

### Component Patterns
- **Pill Buttons**: Fully rounded corners (`border-radius: 100px`), 56px height, full-width or auto-width
- **Cards**: 16px corner radius, subtle shadow (`box-shadow: 0 4px 12px rgba(0,0,0,0.1)`)
- **Icons**: 3D-style gradient icons (see GO Club reference), 64x64px for hero icons
- **Progress Rings**: 200px diameter, 12px stroke width, animated with spring physics
- **Overlays**: `background: rgba(15, 23, 42, 0.85)` (dark slate with 85% opacity)

### Animations
- **Transitions**: 300ms ease-in-out for screen transitions
- **Micro-interactions**: 150ms spring animations for button taps, toggles
- **Progress Rings**: Animate with `CABasicAnimation` (iOS) / `AnimatedBuilder` (Flutter)
- **Confetti**: Use Lottie animation or native particle system (on workout completion)

### Accessibility
- **Contrast Ratios**: WCAG AA compliant (4.5:1 for body text, 3:1 for large text)
- **VoiceOver/TalkBack**: All buttons labeled, state changes announced
- **Dynamic Type**: Support iOS/Android system font scaling (up to 200%)
- **Haptics**: Use system haptics for rep counting, success events (can disable in settings)

---

## 🔐 Permissions & Privacy

### Required Permissions

| Permission | Platform | Purpose | Request Timing |
|------------|----------|---------|----------------|
| **Screen Time** | iOS | Enforce app blocking | After onboarding, before first block setup |
| **Usage Access** | Android | Query installed apps + block enforcement | Same as iOS |
| **Camera** | iOS/Android | Rep counting via pose detection | Before first workout (can deny, falls back to manual) |
| **HealthKit (iOS)** | iOS | Read step count, write workout data | During onboarding (Screen 6) |
| **Health Connect (Android)** | Android | Same as HealthKit | Same as iOS |
| **Notifications** | iOS/Android | Grace period warnings, workout reminders | After first workout completion (optional) |

### Permission Flows

**Screen Time / Usage Access** (Critical Path):
1. **Trigger**: User taps "Block Apps" for first time
2. **Modal**: 
   - Title: "PUSHIN' Needs Screen Time Access"
   - Body: "To block distracting apps, we need permission to manage your Screen Time settings. This data stays on your device."
   - Visual: Lock icon + app icons illustration
   - CTA: "Grant Access" → Opens iOS Settings > Screen Time > Content & Privacy
3. **iOS Limitation**: Can't deep-link directly, must show instructions:
   - "1. Open Screen Time settings"
   - "2. Tap Content & Privacy Restrictions"
   - "3. Enable PUSHIN' under Apps"
4. **Return to App**: Use `AppDelegate` lifecycle to detect return, verify permission granted
5. **If Denied**: Show error banner "Screen Time access required. Tap to try again."

**Camera** (Optional, Fallback Available):
1. **Trigger**: User taps "Start Workout" for first time
2. **System Prompt**: Native iOS/Android camera permission dialog
3. **If Granted**: Show camera feed with pose overlay
4. **If Denied**: Show manual rep counter UI with message:
   - "Can't access camera. Tap the button each time you complete a rep."
   - Large circular "Count Rep" button (center screen)

### Privacy Policy Highlights
- **Data Storage**: All data stored locally on device (Core Data iOS / Room DB Android)
- **No Server**: MVP has NO backend server; all logic runs on-device
- **HealthKit**: Only read step count (for onboarding context), write workout metadata
- **Analytics**: Anonymous usage events only (Workout completed, Plan upgraded, App opened) via Firebase Analytics (opt-out available)
- **No Selling**: Explicitly state "We never sell your data" in privacy policy

---

## 📊 Analytics & Tracking

### Events to Track (Firebase Analytics)

| Event Name | Parameters | Trigger |
|------------|------------|---------|
| `onboarding_completed` | `fitness_level`, `primary_goal`, `workout_frequency` | Screen 7 "Next" tap |
| `app_blocked` | `app_name`, `total_blocked_apps` | User enables app toggle |
| `workout_started` | `workout_type`, `plan_tier` | Tap "Start Workout" |
| `workout_completed` | `workout_type`, `reps_completed`, `duration_seconds`, `plan_tier` | Workout finishes (state: EARNING → UNLOCKED) |
| `workout_abandoned` | `workout_type`, `reps_completed`, `duration_seconds` | User taps "Cancel" during workout |
| `unlock_session_started` | `duration_seconds_earned`, `plan_tier` | State: UNLOCKED entered |
| `unlock_session_expired` | `time_remaining_seconds` | State: UNLOCKED → EXPIRED (grace starts) |
| `grace_period_ended` | `grace_duration_seconds`, `action` (`locked_automatically`, `started_workout`, `locked_manually`) | State: EXPIRED → LOCKED |
| `paywall_viewed` | `trigger_point` (`app_limit`, `workout_lock`, `daily_cap`, `post_workout`, `settings`) | Paywall modal displayed |
| `paywall_upgrade_tapped` | `plan_selected` (`standard`, `advanced`), `trigger_point` | "Subscribe" button tap |
| `subscription_completed` | `plan_tier`, `trial_start_date` | StoreKit/Billing successful purchase |
| `subscription_restored` | `plan_tier` | "Restore Purchases" successful |

### Funnels to Monitor
1. **Onboarding Funnel**: Screen 1 → 2 → 3 → 4 → 5 → 6 → 7 → Home (target: 70% completion)
2. **First Workout Funnel**: Home (LOCKED) → Workout Tracker → Workout Completed (target: 60% completion)
3. **Free-to-Paid Funnel**: Paywall Viewed → Upgrade Tapped → Subscription Completed (target: 8-12% conversion)

### A/B Tests (Post-MVP)
- Paywall copy variations (control vs. benefit-focused vs. urgency)
- Onboarding screen order (fitness level first vs. goal first)
- Free plan limits (1 app vs. 2 apps blocked, 30 min vs. 60 min daily cap)

---

## 🚀 Technical Implementation Notes

### State Machine Integration
- **Existing Architecture**: `PushinController` already implements LOCKED → EARNING → UNLOCKED → EXPIRED flow
- **UI Binding**: Flutter screens observe `PushinState` enum via `ValueNotifier` or `Provider`
- **State Transitions**:
  - `startWorkout(workoutType)` → LOCKED to EARNING
  - `completeWorkout(reps)` → EARNING to UNLOCKED (creates `UnlockSession`)
  - `checkSessionStatus(now)` → UNLOCKED to EXPIRED (when time expires)
  - `lockNow()` → Any state to LOCKED (force lock)

### Platform-Specific Considerations

**iOS**:
- **Min Version**: iOS 15.0+ (required for Screen Time API)
- **Frameworks**: 
  - `FamilyControls` (app blocking)
  - `ManagedSettings` (enforcement)
  - `Vision` (pose detection)
  - `HealthKit` (step tracking)
- **Blocking Limitation**: Screen Time shield can't be bypassed, but user can disable in system settings (show warning if detected)

**Android**:
- **Min Version**: Android 10+ (API 29) for Digital Wellbeing
- **Permissions**: `PACKAGE_USAGE_STATS`, `SYSTEM_ALERT_WINDOW` (for block overlay)
- **Blocking Implementation**: 
  - Option 1: Accessibility Service (more reliable, harder approval)
  - Option 2: Usage Stats + full-screen overlay (easier, less reliable)
- **Pose Detection**: ML Kit Pose Detection (requires Google Play Services)

### MVP Technical Debt
- **No Backend**: All data local; can't sync across devices (future: Firebase Firestore)
- **No Auth**: No user accounts (future: Firebase Auth for multi-device)
- **Hardcoded Workout Reps**: 20 reps = 10 min unlock (future: dynamic based on user fitness level)
- **Manual Camera Fallback**: Rep counter button isn't gameable (future: add basic fraud detection)

---

## ✅ Acceptance Criteria Summary

### Must-Have (MVP Launch Blockers)
- [ ] **Onboarding**: All 7 screens functional, skippable after first launch
- [ ] **App Blocking**: 
  - [ ] User can select 1 app (Free), 3 apps (Standard), 5 apps (Advanced)
  - [ ] iOS Screen Time integration enforces blocks
  - [ ] Android overlay/accessibility service enforces blocks
- [ ] **Workout Execution**:
  - [ ] Push-Ups workout fully functional (camera rep counting OR manual fallback)
  - [ ] State transitions work: LOCKED → EARNING → UNLOCKED → EXPIRED → LOCKED
  - [ ] Unlock duration calculated from workout reps (20 reps = 10 min)
- [ ] **Grace Period**: 30s (Free), 60s (Standard), 120s (Advanced) countdown overlay displays
- [ ] **Paywall**:
  - [ ] Triggers on 2nd app block attempt (Free), locked workout tap, daily cap
  - [ ] iOS StoreKit in-app purchase flow works (Standard/Advanced plans)
  - [ ] Android Billing Library flow works
  - [ ] "Restore Purchases" functional
- [ ] **Plan Enforcement**:
  - [ ] Free: 1 app, 1 workout, 1hr/day cap, ads visible
  - [ ] Standard: 3 apps, 3 workouts, 3hr/day cap, no ads
  - [ ] Advanced: 5 apps, 5 workouts, unlimited, no ads
- [ ] **Visual Polish**: UI matches GO Club style (blue gradient, 3D icons, pill buttons)

### Nice-to-Have (Post-MVP)
- [ ] Workout history screen (view past workouts, stats)
- [ ] Detailed analytics dashboard (weekly/monthly trends)
- [ ] Notification reminders ("Haven't worked out today! Your apps are blocked.")
- [ ] Additional workouts (Pull-Ups, Burpees, Lunges)
- [ ] Custom workout creation
- [ ] Social features (leaderboards, challenges)
- [ ] Apple Watch companion app

---

## 🗓️ Release Plan

### Phase 1: MVP Launch (Target: 6 weeks)
**Week 1-2**: Core state machine + blocking integration (iOS only)  
**Week 3-4**: UI implementation (onboarding + workout tracker + paywall)  
**Week 5**: Camera rep counting + HealthKit integration  
**Week 6**: QA, beta testing (TestFlight), polish  

### Phase 2: Android Parity (Target: +4 weeks)
- Port iOS features to Android
- Adapt blocking to Accessibility Service / overlay approach
- ML Kit Pose Detection integration
- Google Play beta release

### Phase 3: Monetization Optimization (Target: +2 weeks)
- A/B test paywall copy and pricing
- Add post-workout interstitial paywall
- Optimize daily cap enforcement (Free plan)

### Phase 4: Feature Expansion (Post-Launch)
- Add Squats, Sit-Ups, Plank, Jumping Jacks workouts
- Analytics dashboard
- Notification system
- Backend sync (Firebase)

---

## 🎯 Open Questions & Decisions Needed

### Business Questions
1. **Pricing**: Confirm €9.99 (Standard) and €14.99 (Advanced) are competitive. Research: Analyze competitors (Freedom, Opal, ClearSpace).
2. **Free Trial**: 7 days vs. 14 days? Industry standard is 7 days, but 14 may improve conversion.
3. **Daily Cap Enforcement (Free Plan)**: 
   - Option A: Hard cap at 1 hour (can't unlock more even with workouts)
   - Option B: Soft cap (show paywall but allow 1 more workout with warning)
   - **Decision**: Option A (more aggressive conversion push)
4. **Ad Strategy (Free Plan)**:
   - Banner ads only (less intrusive) vs. Interstitial ads (more revenue)
   - **Proposal**: Banner on Home screen (LOCKED state) + Interstitial after 3rd workout (20% show rate)

### Technical Questions
1. **Camera Pose Detection Accuracy**: Can we reliably count push-up reps? 
   - **Risk**: False positives (user cheats system) or false negatives (legit reps not counted)
   - **Mitigation**: Beta test with 20 users, measure accuracy %, iterate on ML thresholds
2. **Android Blocking Reliability**: Accessibility Service vs. Overlay approach?
   - **Decision**: Start with overlay (easier Google Play approval), add Accessibility as opt-in for power users
3. **Offline Mode**: What happens if user has no internet during workout?
   - **Answer**: App is fully offline (no backend), but StoreKit/Billing requires internet for purchases (show error if offline)
4. **Multi-Device Support**: What if user has iPhone + iPad with same Apple ID?
   - **MVP**: No sync, treat as separate installs (local data only)
   - **Future**: Firebase sync after backend added

### Design Questions
1. **Workout Card Visual Hierarchy**: Should locked workouts be grayed out or completely hidden?
   - **Decision**: Grayed out with lock icon (shows value of upgrading)
2. **Grace Period UX**: Should overlay be dismissible or force interaction?
   - **Decision**: Non-dismissible (must take action: start workout or accept lock)
3. **Blocked App Icons Display**: Show all blocked apps or just 3-5 with "+X more"?
   - **Decision**: Show max 5, "+X more" link expands full list modal

---

## 📝 Appendix

### Glossary
- **State Machine**: The core LOCKED → EARNING → UNLOCKED → EXPIRED → LOCKED flow
- **Unlock Session**: Time-based session where blocked apps are accessible (duration earned from workout)
- **Grace Period**: Short buffer (30-120s) after unlock session expires before hard lock enforced
- **Paywall Trigger**: UI event that displays subscription upsell modal
- **Rep**: Single workout repetition (e.g., 1 push-up down-and-up cycle)
- **Daily Cap**: Max unlock time per 24-hour period (Free plan only: 1 hour)

### References
- **Visual Design**: GO Club iOS app (screenshots provided)
- **Architecture Docs**: 
  - `ARCHITECTURE_HARDENING.md`
  - `ARCHITECTURE_POLISH.md`
  - `BLOCKING_CONTRACT.md`
- **Existing Codebase**: `lib/domain/`, `lib/controller/`, `lib/services/`
- **Competitor Research**: 
  - Freedom (web/app blocker, $7/mo)
  - Opal (screen time coach, $10/mo)
  - ClearSpace (intentional phone use, $9/mo)

---

**END OF PRD**

---

**Document Status**: 🟡 Draft - Pending Stakeholder Review  
**Next Steps**: 
1. Review with Product team for business model validation
2. Review with Engineering lead for technical feasibility sign-off
3. Review with Design lead for UI/UX alignment with GO Club style
4. Finalize and freeze PRD → Begin Architecture & UX Design phases

**Change Log**:
- v1.0 (Dec 15, 2025): Initial draft created by Product Manager (John)

