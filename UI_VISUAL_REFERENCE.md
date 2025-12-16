# PUSHIN' MVP - Visual Reference Guide

This document describes the visual appearance of each screen based on the GO Club design aesthetic from your Figma file and screenshots.

---

## 🎨 Design Language

### Color Palette
```
Primary Blue:    #4F46E5 (Indigo 600)
Secondary Blue:  #3B82F6 (Blue 500)
Success Green:   #10B981 (Emerald 500)
Warning Yellow:  #F59E0B (Amber 500)
Error Red:       #EF4444 (Red 500)

Background Dark: #0F172A (Slate 900)
Surface Dark:    #1E293B (Slate 800)
Text Primary:    #FFFFFF (White)
Text Secondary:  #94A3B8 (Slate 400)
```

### Typography
```
Headline 1:  40pt Bold   (Hero headings)
Headline 2:  32pt Bold   (Page titles)
Headline 3:  24pt Semibold (Section headers)
Body 1:      18pt Regular (Primary text)
Body 2:      16pt Regular (Secondary text)
Button:      18pt Semibold (CTA buttons)
```

---

## 📱 Screen-by-Screen Visual Guide

### 1. ONBOARDING WELCOME SCREEN

**Layout**:
```
┌─────────────────────────────┐
│                             │
│         (Spacer)            │
│                             │
│      [Gradient Logo]        │
│       Fitness Icon          │
│                             │
│       PUSHIN'               │ ← Gradient text
│                             │
│  Transform Screen Time      │
│  into Fitness Time          │
│                             │
│  Complete workouts to...    │
│                             │
│         (Spacer)            │
│                             │
│  [Continue with Apple]      │ ← White bg, black text
│  [Continue with Google]     │ ← Blue bg
│  [Continue with Facebook]   │ ← Blue bg
│  [Continue with Email]      │ ← Dark bg
│                             │
│  By continuing, you agree...│
│                             │
└─────────────────────────────┘
```

**Visual Style**:
- Dark gradient background (top to bottom)
- Circular gradient logo (80x80px) with shadow
- Large gradient heading (48pt, "PUSHIN'")
- 4 sign-in buttons (56px height, pill-shaped)
- Small terms text at bottom

---

### 2. ONBOARDING GOAL SCREEN

**Layout** (matches Screenshot 1):
```
┌─────────────────────────────┐
│  ← Back                     │
│                             │
│         (Spacer)            │
│                             │
│      [App Icon]             │
│                             │
│    What's your              │
│    primary goal?            │ ← 44pt bold, white
│                             │
│                             │
│   [Lose weight]             │ ← Pill button
│                             │
│   [Daily activity]          │ ← Pill button
│                             │
│         (Spacer)            │
│                             │
│        [Next]               │ ← White button (appears when selected)
│                             │
└─────────────────────────────┘
```

**Visual Style**:
- Blue gradient at bottom (like screenshot)
- Large pill buttons (72px height)
- Selected state: Blue gradient with shadow
- Unselected: Semi-transparent with border

---

### 3. ONBOARDING FITNESS LEVEL SCREEN

**Layout** (matches Screenshot 5):
```
┌─────────────────────────────┐
│  ← Back                     │
│                             │
│      [Icon]                 │
│                             │
│      Current                │
│   fitness level?            │ ← 44pt bold
│                             │
│  ┌────────┬────────┐        │
│  │Beginner│Intermed│        │ ← 2x2 Grid
│  │  Icon  │  Icon  │        │
│  ├────────┼────────┤        │
│  │Advanced│Athletic│        │
│  │  Icon  │  Icon  │        │
│  └────────┴────────┘        │
│                             │
│         (Spacer)            │
│                             │
│        [Next]               │
│                             │
└─────────────────────────────┘
```

**Visual Style**:
- 2x2 grid of square cards
- Each card: Icon + Label
- Selected: Blue gradient background
- Unselected: Semi-transparent border

---

### 4. ONBOARDING PLAN READY SCREEN

**Layout** (matches Screenshot 6):
```
┌─────────────────────────────┐
│                             │
│         (Spacer)            │
│                             │
│          ✨                 │ ← Sparkle icon
│                             │
│          your               │
│      plan is ready!         │ ← Gradient text
│        are you?             │
│                             │
│  Start and experience...    │
│                             │
│  ┌─────────────────────┐   │
│  │ Today's Goal        │   │
│  │ Run 1 km + Walk 4 km│   │ ← Dark card
│  │ Jogging Intervals   │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │ Tomorrow's Goal  ✓  │   │
│  │ Walk 6 km           │   │ ← Blue gradient card
│  │ 60 min brisk        │   │
│  └─────────────────────┘   │
│                             │
│         (Spacer)            │
│                             │
│       [Let's GO!]           │
│                             │
└─────────────────────────────┘
```

**Visual Style**:
- Celebratory heading with gradient
- Two workout cards (icon + text)
- Tomorrow's card highlighted in blue
- White "Let's GO!" button at bottom

---

### 5. ONBOARDING PERMISSIONS SCREEN

**Layout** (matches Screenshot 7):
```
┌─────────────────────────────┐
│  ← Back                     │
│                             │
│         (Spacer)            │
│                             │
│   [❤️] ⟷ [💪]              │ ← Icon trio
│  Health  Link  PUSHIN'      │
│                             │
│       link to               │
│    Apple Health             │ ← Gradient text
│                             │
│  With this access, we can...│
│                             │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─       │ ← Dotted line
│                             │
│  ┌─────────────────────┐   │
│  │ 🔒 Your health data │   │ ← Privacy card
│  │    is never stored  │   │
│  │    or shared...     │   │
│  └─────────────────────┘   │
│                             │
│         (Spacer)            │
│                             │
│      [Continue]             │
│                             │
│     Skip for now            │ ← Underlined link
│                             │
└─────────────────────────────┘
```

**Visual Style**:
- Icon trio showing connection
- Large gradient heading
- Privacy reassurance card with lock icon
- White "Continue" button
- Subtle "Skip" link

---

### 6. WORKOUT SELECTION SCREEN

**Layout**:
```
┌─────────────────────────────┐
│  ← Back         Choose Your │
│                 Workout     │ ← Gradient text
│                             │
│  Complete exercises to      │
│  unlock screen time         │
│                             │
│  ┌─────────────────────┐   │
│  │ 💪 Push-Ups         │   │ ← Blue gradient card
│  │    20 reps          │   │   (unlocked)
│  │    ⏱ 10 minutes     │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │ 🦵 Squats      🔒   │   │ ← Dark card
│  │    30 reps          │   │   (locked, grayed out)
│  │    Standard Plan    │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │ 🧘 Plank       🔒   │   │
│  │    60 seconds       │   │
│  │    Advanced Plan    │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │ ⭐ Unlock More      │   │ ← Upgrade CTA
│  │    Workouts         │   │
│  │  [See Plans]        │   │
│  └─────────────────────┘   │
│                             │
└─────────────────────────────┘
```

**Visual Style**:
- Scrollable list of workout cards
- Unlocked: Blue gradient with shadow
- Locked: Dark gray, 50% opacity, lock icon
- Each card: Icon, title, reps/time, reward
- Upgrade CTA at bottom with border

---

### 7. REP COUNTER SCREEN

**Layout**:
```
┌─────────────────────────────┐
│  ✕         Push-Ups         │
│                             │
│         (Spacer)            │
│                             │
│     ╭────────────╮          │
│    │             │          │ ← Circular progress ring
│    │             │          │   (280px diameter)
│    │      15     │          │   Blue gradient arc
│    │   of 20     │          │
│    │             │          │
│     ╰────────────╯          │
│                             │
│   You're crushing it! 🔥    │
│                             │
│         (Spacer)            │
│                             │
│    [+ Add Rep]              │ ← Large button (72px)
│                             │   Blue gradient
│                             │
└─────────────────────────────┘
```

**Visual Style**:
- Minimal header (close button, workout name)
- Large circular progress ring (custom painter)
- Giant rep counter (96pt) with gradient
- Motivational message changes with progress
- Huge "+ Add Rep" button at bottom
- Pulse animation on tap

---

### 8. WORKOUT COMPLETION SCREEN

**Layout**:
```
┌─────────────────────────────┐
│                             │
│         (Spacer)            │
│                             │
│      ╭────────╮             │
│      │   ✓    │             │ ← Gradient circle icon
│      ╰────────╯             │
│                             │
│       Workout               │
│      Complete!              │ ← Gradient text (48pt)
│                             │
│  20 Push-Ups completed      │
│                             │
│  ┌─────────────────────┐   │
│  │   You earned        │   │
│  │                     │   │
│  │      10 minutes     │   │ ← Giant number (72pt)
│  │                     │   │   with gradient
│  │  of screen time     │   │
│  └─────────────────────┘   │
│                             │
│  Keep it up! Build healthy  │
│  habits, one workout... 💪  │
│                             │
│         (Spacer)            │
│                             │
│      [Continue]             │ ← Blue gradient button
│                             │
│  [Do Another Workout]       │ ← Outline button
│                             │
└─────────────────────────────┘
```

**Visual Style**:
- Success icon with gradient and shadow
- "Complete!" in gradient text
- Earned time in bordered card
- Large gradient number display
- Two CTAs: Primary (filled) + Secondary (outline)
- Scale-in animation on mount

---

### 9. SETTINGS SCREEN

**Layout**:
```
┌─────────────────────────────┐
│                             │
│      Settings               │ ← Sticky header
│                             │
│  ┌─────────────────────┐   │
│  │ ⭐ Free Plan        │   │ ← Plan card
│  │    1 workout        │   │   (gradient if paid)
│  │    1 hour daily cap │   │
│  │  [Upgrade Plan]     │   │
│  └─────────────────────┘   │
│                             │
│  APP BLOCKING               │ ← Section header
│                             │
│  ┌─────────────────────┐   │
│  │ 🚫 Manage Blocked   │   │ ← Settings card
│  │     Apps         →  │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │ ⏰ Emergency Unlock │   │
│  │    5 minutes      → │   │
│  └─────────────────────┘   │
│                             │
│  ACCOUNT                    │
│                             │
│  ┌─────────────────────┐   │
│  │ 👤 Profile        → │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │ 🏋️ Fitness Level   → │   │
│  └─────────────────────┘   │
│                             │
│   [Log Out]                 │ ← Red button
│                             │
│   PUSHIN' v1.0.0            │
│                             │
└─────────────────────────────┘
```

**Visual Style**:
- Scrollable list with sections
- Plan card at top (gradient for paid, dark for free)
- Icon + title + subtitle pattern
- Color-coded icons (Block: Red, Time: Yellow, etc.)
- Arrow indicators for navigation
- Red log out button at bottom

---

### 10. MANAGE APPS SCREEN

**Layout**:
```
┌─────────────────────────────┐
│  ← Manage Blocked Apps      │
│                             │
│  ┌─────────────────────┐   │
│  │ 🚫 3 apps blocked   │   │ ← Summary card
│  │ Requires workout    │   │   Blue gradient
│  └─────────────────────┘   │
│                             │
│  [🔍 Search apps...]        │ ← Search bar
│                             │
│  ┌─────────────────────┐   │
│  │ 📷 Instagram        │   │ ← App tile with toggle
│  │    Social       [✓] │   │   (ON = blue highlight)
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │ 🎵 TikTok           │   │
│  │    Social       [✓] │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │ 🐦 Twitter          │   │
│  │    Social       [✓] │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │ 📘 Facebook         │   │
│  │    Social       [ ] │   │ ← OFF
│  └─────────────────────┘   │
│                             │
│ ────────────────────────────│
│ ℹ️ Blocked apps require    │ ← Bottom info bar
│    a workout to access      │
└─────────────────────────────┘
```

**Visual Style**:
- Summary card shows total blocked apps
- Search bar for filtering
- App tiles with icon, name, category, toggle
- Enabled apps: Blue border highlight
- Category colors (Social: Blue, Entertainment: Red)
- Sticky bottom info bar

---

### 11. PAYWALL SCREEN

**Layout**:
```
┌─────────────────────────────┐
│  ✕                 Restore  │
│                             │
│      ╭────────╮             │
│      │   ⭐   │             │ ← Gradient star icon
│      ╰────────╯             │
│                             │
│     Unlock Your             │
│   Full Potential            │ ← Gradient text
│                             │
│  Choose the plan that fits  │
│  your fitness journey       │
│                             │
│  ┌─────────────────────┐   │
│  │ Standard   POPULAR  │   │ ← Selected = gradient
│  │ €9.99/month     ✓   │   │
│  │ ✓ 3 workout types   │   │
│  │ ✓ 3 hours daily cap │   │
│  │ ✓ Progress tracking │   │
│  │ ✓ Email support     │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │ Advanced            │   │ ← Unselected = dark
│  │ €14.99/month        │   │
│  │ ✓ 5 workout types   │   │
│  │ ✓ Unlimited usage   │   │
│  │ ✓ Advanced analytics│   │
│  │ ✓ Priority support  │   │
│  │ ✓ Custom plans      │   │
│  └─────────────────────┘   │
│                             │
│  Compare Plans              │
│  ┌─────────────────────┐   │
│  │Feature│Free│Std│Adv │   │ ← Comparison table
│  │Workouts│ 1 │ 3 │ 5  │   │
│  │Daily Cap│1h│3h│∞   │   │
│  └─────────────────────┘   │
│                             │
│  Join 10,000+ Users         │
│  ★★★★★ 4.9 out of 5        │
│                             │
│                             │
│ ────────────────────────────│
│  [Start Standard Plan]      │ ← Fixed bottom CTA
│  Cancel anytime. Terms apply│
└─────────────────────────────┘
```

**Visual Style**:
- Scrollable content
- Plan cards with selection state
- Selected: Blue gradient + shadow
- "POPULAR" badge on recommended plan
- Comparison table with color coding
- Social proof with stars
- Fixed bottom CTA with gradient

---

## 🎥 Animation Patterns

### Entrance Animations
- **Scale In**: Completion screen success icon (0.8 → 1.0, elastic curve)
- **Fade In**: All screens fade from 0 → 1 on mount
- **Slide Up**: Bottom sheets and dialogs

### Interaction Animations
- **Pulse**: Rep counter on tap (1.0 → 1.1 → 1.0, 800ms)
- **Ripple**: All buttons have ink splash on tap
- **Progress Arc**: Rep counter ring animates smoothly

### Transition Animations
- **Selection State**: 200ms color/shadow transition
- **Navigation**: 300ms screen transitions
- **Toggle Switch**: Platform-native animation

---

## 📐 Layout Principles

### Spacing (8px grid)
```
XS:  4px  - Tight spacing (icon gaps)
SM:  8px  - Small margins
MD:  16px - Standard padding
LG:  24px - Section spacing
XL:  32px - Large gaps
XXL: 48px - Hero spacing
```

### Button Sizes
```
Small:    48px height
Standard: 56px height
Large:    64px height
XL:       72px height (workout selection)
```

### Border Radius
```
Small:  8px  - Input fields
Medium: 16px - Cards
Large:  24px - Large cards
Pill:   100px - Fully rounded buttons
```

### Shadows
```
Card Shadow:
  - Color: rgba(0,0,0,0.2)
  - Blur: 12px
  - Offset: (0, 4px)

Button Shadow:
  - Color: Primary Blue @ 30% opacity
  - Blur: 16-24px
  - Offset: (0, 4-8px)
```

---

## 🌈 Gradient Usage

### Primary Gradient (Buttons, Selected States)
```css
linear-gradient(
  top to bottom,
  #4F46E5 → #3B82F6
)
```

### Surface Gradient (Backgrounds)
```css
linear-gradient(
  top-left to bottom-right,
  #1E293B → #0F172A
)
```

### Text Gradient (Headings)
```css
linear-gradient(
  left to right,
  #FFFFFF → #E0E7FF
)
```

---

## ✅ Checklist for Visual QA

When testing screens, verify:

- [ ] Dark background gradient applied
- [ ] Primary blue gradient on CTAs
- [ ] White text readable on all backgrounds
- [ ] Icons properly sized (24-48px)
- [ ] Buttons have pill shape (100px radius)
- [ ] Cards have subtle shadows
- [ ] Selection states show gradient
- [ ] Animations run smoothly (60fps)
- [ ] Spacing follows 8px grid
- [ ] Typography sizes match spec
- [ ] Gradient text renders correctly
- [ ] Touch targets minimum 56px
- [ ] Safe area padding on all edges
- [ ] Scrolling works smoothly
- [ ] Transitions feel natural (300ms)

---

## 📱 Responsive Behavior

### Small Screens (4.7" - iPhone SE)
- Font sizes: 90% of spec
- Padding: 20px instead of 24px
- Button heights: 56px instead of 64px

### Standard Screens (5.8" - 6.1")
- Use spec as-is
- Optimal layout

### Large Screens (6.5"+)
- Font sizes: 110% of spec
- More vertical spacing
- Button heights: 64-72px

---

**This visual guide ensures 100% fidelity to the GO Club design aesthetic you provided! 🎨**












