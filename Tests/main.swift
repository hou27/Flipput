import Foundation
import CoreGraphics

func event(_ type: CGEventType, x: Double = 10, flags: CGEventFlags = []) -> CGEvent {
    let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: CGPoint(x: x, y: 10), mouseButton: .right)!
    e.flags = flags
    return e
}
var count = 0
func check(_ condition: Bool, _ message: String) {
    precondition(condition, message); count += 1
}
let g = DoubleClickGesture()
func send(_ t: CGEventType, _ time: Double, x: Double = 10, flags: CGEventFlags = []) -> DoubleClickGesture.Result {
    g.process(t, event(t, x: x, flags: flags), now: time, interval: 0.5)
}
check(send(.rightMouseDown, 0).consumed, "First down buffered")
check(send(.rightMouseUp, 0.1).consumed, "First up buffered")
check(send(.rightMouseDown, 0.2).consumed, "Second down buffered")
let double = send(.rightMouseUp, 0.3)
check(double.activate && double.consumed && double.replay.isEmpty && g.deadline == nil, "Double click activates once, sends no context click")
check(!send(.rightMouseUp, 0.4).activate, "Unmatched up cannot activate")
_ = send(.rightMouseDown, 1); _ = send(.rightMouseUp, 1.1)
let single = g.flush()
check(single.map { $0.type } == [.rightMouseDown, .rightMouseUp], "Timeout replays single click in order")
_ = send(.rightMouseDown, 2); _ = send(.rightMouseUp, 2.1)
let late = send(.rightMouseDown, 2.6)
check(late.replay.count == 2 && !late.activate && late.consumed, "Late click starts independent sequence")
_ = g.flush()
_ = send(.rightMouseDown, 3); _ = send(.rightMouseUp, 3.1)
let distant = send(.rightMouseDown, 3.2, x: 30)
check(distant.replay.count == 2 && !distant.activate, "Distant click is not double click")
_ = g.flush()
_ = send(.rightMouseDown, 4)
let drag = send(.rightMouseDragged, 4.1, x: 30)
check(drag.replay.count == 1 && !drag.consumed, "Drag releases buffered down before drag")
check(!send(.rightMouseUp, 4.2, x: 30).consumed, "Drag release passes through")
_ = send(.rightMouseDown, 5); _ = send(.rightMouseUp, 5.1)
let modified = send(.rightMouseDown, 5.2, flags: .maskCommand)
check(modified.replay.count == 2 && !modified.consumed, "Modifier-click flushes and bypasses recognizer")
_ = send(.rightMouseDown, 6); _ = send(.rightMouseUp, 6.1)
let left = send(.leftMouseDown, 6.2)
check(left.replay.count == 2 && !left.consumed, "Other click preserves ordering")
_ = send(.rightMouseDown, 7); _ = send(.rightMouseUp, 7.1); _ = send(.rightMouseDown, 7.2)
let secondDrag = send(.rightMouseDragged, 7.3, x: 30)
check(secondDrag.replay.count == 3 && !secondDrag.activate, "Second click drag restores all buffered events")
_ = send(.rightMouseDown, 8); _ = send(.rightMouseUp, 8.1); _ = send(.rightMouseDown, 8.2)
let longSecond = send(.rightMouseUp, 8.8)
check(longSecond.replay.count == 3 && !longSecond.consumed && !longSecond.activate, "Held second press expires safely")
print("Passed \(count) double-click state checks; no events posted.")

check(alternateInputSource(ids: ["ABC", "Korean"], current: "ABC") == "Korean", "English toggles to Korean")
check(alternateInputSource(ids: ["ABC", "Korean"], current: "Korean") == "ABC", "Korean toggles to English")
check(alternateInputSource(ids: ["ABC"], current: "ABC") == nil, "One source uses menu")
check(alternateInputSource(ids: ["ABC", "Korean", "Japanese"], current: "ABC") == nil, "Three sources use menu")
check(alternateInputSource(ids: ["ABC", "Korean"], current: "Other") == nil, "Unknown current source uses menu")

check(normalizedHoldSeconds(0.35) == 0.35 && normalizedHoldSeconds(0.55) == 0.55 && normalizedHoldSeconds(0.8) == 0.8, "Presets are kept")
check(normalizedHoldSeconds(0.62) == 0.6 && normalizedHoldSeconds(0.63) == 0.65, "Hold time snaps to 0.05 s")
check(normalizedHoldSeconds(0.05) == 0.2 && normalizedHoldSeconds(9) == 1.5, "Hold time stays in slider range")
check(normalizedHoldSeconds(.nan) == defaultHoldSeconds, "Invalid stored hold time falls back to default")
print("Passed \(count) total gesture, language selection and hold time checks.")
