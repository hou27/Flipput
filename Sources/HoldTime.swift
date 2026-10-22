// Long right-click hold time: kept inside the menu slider's range on a 0.05 s grid.
let defaultHoldSeconds = 0.55
let holdSecondsRange = 0.2...1.5

func normalizedHoldSeconds(_ value: Double) -> Double {
    guard value.isFinite else { return defaultHoldSeconds }
    return (min(max(value, holdSecondsRange.lowerBound), holdSecondsRange.upperBound) * 20).rounded() / 20
}
