import Foundation
import CoreGraphics

// Keys that can switch the input source. A modifier fires when pressed and released on its own;
// a function key fires on key down. Key events are never held back either way.
struct TriggerKey {
    let code: Int64
    let title: String
    let modifier: CGEventFlags?
}

let modifierTriggerKeys = [
    TriggerKey(code: 61, title: "오른쪽 Option", modifier: .maskAlternate),
    TriggerKey(code: 54, title: "오른쪽 Command", modifier: .maskCommand),
    TriggerKey(code: 62, title: "오른쪽 Control", modifier: .maskControl),
    TriggerKey(code: 60, title: "오른쪽 Shift", modifier: .maskShift),
    TriggerKey(code: 58, title: "왼쪽 Option", modifier: .maskAlternate),
    TriggerKey(code: 55, title: "왼쪽 Command", modifier: .maskCommand),
    TriggerKey(code: 59, title: "왼쪽 Control", modifier: .maskControl),
    TriggerKey(code: 56, title: "왼쪽 Shift", modifier: .maskShift)]
let functionTriggerKeys = [(105, "F13"), (107, "F14"), (113, "F15"), (106, "F16"), (64, "F17"), (79, "F18"), (80, "F19")]
    .map { TriggerKey(code: Int64($0.0), title: $0.1, modifier: nil) }
let triggerKeys = modifierTriggerKeys + functionTriggerKeys
let defaultTriggerKeyCode: Int64 = 61

final class KeyTrigger {
    private(set) var key: TriggerKey?
    private var tap: ModifierTap?

    func select(_ key: TriggerKey?) {
        self.key = key
        if let key, let modifier = key.modifier { tap = ModifierTap(keyCode: key.code, flag: modifier) } else { tap = nil }
    }

    // Call for keyDown and flagsChanged events. Returns true when the event completes the trigger.
    func handle(_ type: CGEventType, code: Int64, flags: CGEventFlags, isRepeat: Bool, now: TimeInterval) -> Bool {
        guard let key else { return false }
        if type == .flagsChanged { return tap?.flagsChanged(code: code, flags: flags, now: now, limit: 0.5) ?? false }
        guard type == .keyDown else { return false }
        tap?.interrupt()
        return key.modifier == nil && code == key.code && !isRepeat
    }

    // Clicks and scrolls cancel a modifier that is being held.
    func interrupt() { tap?.interrupt() }
}
