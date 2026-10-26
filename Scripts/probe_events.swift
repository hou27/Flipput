import AppKit
import Carbon
import CoreGraphics

// Prints the mouse or key events a session event tap sees, to debug remote input (e.g. Chrome Remote Desktop).
// Usage: swift Scripts/probe_events.swift [pass|swallow] [session|annotated] [keys]
//   pass      (default) log only; every event goes through unchanged
//   swallow   drop each right mouse-down, like Flipput does while it waits, and log what follows
//   session   (default) tap where events enter the login session
//   annotated tap after events have been routed to an application, as Flipput does
//   keys      log key events instead of mouse events (never dropped), with the front app and secure input state
// Stops by itself after 20 seconds. Pause Flipput first so its own tap does not interfere.
let swallow = CommandLine.arguments.contains("swallow")
let keys = CommandLine.arguments.contains("keys")
let location: CGEventTapLocation = CommandLine.arguments.contains("annotated") ? .cgAnnotatedSessionEventTap : .cgSessionEventTap
let start = ProcessInfo.processInfo.systemUptime
let names: [CGEventType: String] = keys
    ? [.keyDown: "keyDown", .keyUp: "keyUp", .flagsChanged: "flagsChanged"]
    : [.leftMouseDown: "leftDown", .leftMouseUp: "leftUp", .rightMouseDown: "rightDown", .rightMouseUp: "rightUp",
       .rightMouseDragged: "rightDragged", .mouseMoved: "moved"]
let mask = names.keys.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
// Keys worth trying as a trigger; anything else prints its raw key code.
let keyNames: [Int64: String] = [
    105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19",
    55: "leftCommand", 54: "rightCommand", 58: "leftOption", 61: "rightOption", 59: "leftControl", 62: "rightControl",
    56: "leftShift", 60: "rightShift", 57: "capsLock", 63: "fn", 102: "eisu/LANG2", 104: "kana/LANG1"]

let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput { print("tap disabled: \(type.rawValue)"); return nil }
    let time = ProcessInfo.processInfo.systemUptime - start
    let name = (names[type] ?? "type\(type.rawValue)").padding(toLength: 12, withPad: " ", startingAt: 0)
    if keys {
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        print(String(format: "%7.3f %@ code=%3lld %@ repeat=%lld pid=%lld flags=0x%llx secureInput=%d app=%@",
                     time, name, code, (keyNames[code] ?? "-").padding(toLength: 12, withPad: " ", startingAt: 0),
                     event.getIntegerValueField(.keyboardEventAutorepeat), event.getIntegerValueField(.eventSourceUnixProcessID),
                     event.flags.rawValue, IsSecureEventInputEnabled() ? 1 : 0,
                     NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"))
        return Unmanaged.passUnretained(event)
    }
    let dropped = swallow && type == .rightMouseDown
    print(String(format: "%7.3f %@ click=%lld num=%lld pid=%lld state=%lld flags=0x%llx hidRight=%d sessionRight=%d%@",
                 time, name,
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
    print("Could not create the event tap. Allow Terminal in System Settings > Privacy & Security > Accessibility"
          + (keys ? " (and Input Monitoring if key events still don't show up)." : "."))
    exit(1)
}
CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0), .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
setvbuf(stdout, nil, _IOLBF, 0)
let mode = keys ? "keys" : (swallow ? "swallow" : "pass")
print("Mode: \(mode), \(location == .cgAnnotatedSessionEventTap ? "annotated" : "session") tap. Stopping in 20 seconds.")
print(keys ? "Press the keys to try. Every key code is printed, so don't type passwords now. Secure input at start: \(IsSecureEventInputEnabled() ? 1 : 0)"
           : "Right-click a few times now.")
DispatchQueue.main.asyncAfter(deadline: .now() + 20) { print("done"); exit(0) }
CFRunLoopRun()
