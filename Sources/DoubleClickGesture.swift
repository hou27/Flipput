import Foundation
import CoreGraphics

// No event posting or UI here: the owner executes replay/menu effects in order.
final class DoubleClickGesture {
    struct Result {
        var consumed = false
        var replay: [CGEvent] = []
        var activate = false
    }
    private var events: [CGEvent] = []
    private var firstReleased = false
    private var secondPressed = false
    private var anchor = CGPoint.zero
    private(set) var deadline: TimeInterval?

    func flush() -> [CGEvent] {
        let result = events
        events = []; firstReleased = false; secondPressed = false; deadline = nil
        return result
    }

    func process(_ type: CGEventType, _ event: CGEvent, now: TimeInterval, interval: TimeInterval) -> Result {
        var result = Result()
        if let deadline, now >= deadline { result.replay += flush() }
        let modified = !event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty
        switch type {
        case .rightMouseDown:
            if modified { result.replay += flush(); return result }
            if firstReleased && hypot(event.location.x - anchor.x, event.location.y - anchor.y) <= 5 {
                secondPressed = true
                // A held second press must eventually be released back to the application.
                deadline = now + interval
            } else {
                result.replay += flush()
                anchor = event.location
                deadline = now + interval
            }
            if let copy = event.copy() { events.append(copy) }
            result.consumed = true
        case .rightMouseUp:
            guard !events.isEmpty else { return result }
            if modified || hypot(event.location.x - anchor.x, event.location.y - anchor.y) > 5 {
                result.replay += flush(); return result
            }
            if let copy = event.copy() { events.append(copy) }
            result.consumed = true
            if secondPressed {
                _ = flush()
                result.activate = true
            } else { firstReleased = true }
        case .rightMouseDragged:
            if !events.isEmpty && hypot(event.location.x - anchor.x, event.location.y - anchor.y) < 5 {
                result.consumed = true
            } else { result.replay += flush() }
        default:
            // Other clicks/scrolls must not overtake a delayed right-click.
            result.replay += flush()
        }
        return result
    }
}
