import Foundation
import CoreGraphics

// Prints the mouse events a session event tap sees, to debug remote input (e.g. Chrome Remote Desktop).
// Usage: swift Scripts/probe_events.swift [pass|swallow] [session|annotated]
//   pass      (default) log only; every event goes through unchanged
//   swallow   drop each right mouse-down, like Flipput does while it waits, and log what follows
//   session   (default) tap where events enter the login session, as Flipput does
//   annotated tap after events have been routed to an application
// Stops by itself after 20 seconds. Pause Flipput first so its own tap does not interfere.
let swallow = CommandLine.arguments.contains("swallow")
let location: CGEventTapLocation = CommandLine.arguments.contains("annotated") ? .cgAnnotatedSessionEventTap : .cgSessionEventTap
let start = ProcessInfo.processInfo.systemUptime
let names: [CGEventType: String] = [
    .leftMouseDown: "leftDown", .leftMouseUp: "leftUp", .rightMouseDown: "rightDown", .rightMouseUp: "rightUp",
    .rightMouseDragged: "rightDragged", .mouseMoved: "moved"]
let mask = names.keys.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }

let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput { print("tap disabled: \(type.rawValue)"); return nil }
    let dropped = swallow && type == .rightMouseDown
    print(String(format: "%7.3f %@ click=%lld num=%lld pid=%lld state=%lld flags=0x%llx hidRight=%d sessionRight=%d%@",
                 ProcessInfo.processInfo.systemUptime - start,
                 (names[type] ?? "type\(type.rawValue)").padding(toLength: 12, withPad: " ", startingAt: 0),
                 event.getIntegerValueField(.mouseEventClickState), event.getIntegerValueField(.mouseEventNumber),
                 event.getIntegerValueField(.eventSourceUnixProcessID), event.getIntegerValueField(.eventSourceStateID),
                 event.flags.rawValue,
                 CGEventSource.buttonState(.hidSystemState, button: .right) ? 1 : 0,
                 CGEventSource.buttonState(.combinedSessionState, button: .right) ? 1 : 0,
                 dropped ? "  <- dropped" : ""))
    return dropped ? nil : Unmanaged.passUnretained(event)
}

guard let tap = CGEvent.tapCreate(tap: location, place: .headInsertEventTap, options: .defaultTap,
                                  eventsOfInterest: mask, callback: callback, userInfo: nil) else {
    print("Could not create the event tap. Allow Terminal in System Settings > Privacy & Security > Accessibility.")
    exit(1)
}
CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0), .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
setvbuf(stdout, nil, _IOLBF, 0)
print("Mode: \(swallow ? "swallow" : "pass"), \(location == .cgAnnotatedSessionEventTap ? "annotated" : "session") tap. Right-click a few times now; stopping in 20 seconds.")
DispatchQueue.main.asyncAfter(deadline: .now() + 20) { print("done"); exit(0) }
CFRunLoopRun()
