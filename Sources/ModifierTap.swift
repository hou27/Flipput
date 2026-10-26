import Foundation
import CoreGraphics

// Recognizes one modifier key pressed and released on its own. It only observes: the owner passes
// every key event through, so shortcuts that use the same modifier keep working.
final class ModifierTap {
    private let keyCode: Int64
    private let flag: CGEventFlags
    private var pressedAt: TimeInterval?
    private var alone = false

    init(keyCode: Int64, flag: CGEventFlags) { self.keyCode = keyCode; self.flag = flag }

    // Call for every flagsChanged event. Returns true when the key is released after a lone press within `limit`.
    func flagsChanged(code: Int64, flags: CGEventFlags, now: TimeInterval, limit: TimeInterval) -> Bool {
        guard code == keyCode else { alone = false; return false }
        if let pressedAt {
            self.pressedAt = nil
            return alone && now - pressedAt <= limit
        }
        // Remote input has no left/right modifier bits, so press and release are told apart by order;
        // a release without a recorded press is skipped.
        guard flags.contains(flag) else { return false }
        pressedAt = now
        alone = flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).subtracting(flag).isEmpty
        return false
    }

    // Any other key, click or scroll while the modifier is held cancels the tap.
    func interrupt() { alone = false }
}
