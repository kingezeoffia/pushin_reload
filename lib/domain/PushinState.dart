/// Application state enum for PUSHIN MVP state machine.
enum PushinState {
  locked,    // Content blocked, must earn access
  earning,   // Actively earning through workout
  unlocked,  // Content accessible, timer running
  expired,   // Grace period before full lock
}

