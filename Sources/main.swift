import AppKit
import Carbon
import ApplicationServices

let replayMarker: Int64 = 0x48414E474D454E55

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var item: NSStatusItem!
    var tap: CFMachPort?
    var source: CFRunLoopSource?
    var pendingDown: CGEvent?
    var timer: Timer?
    var swallowedLongPress = false
    let doubleGesture = DoubleClickGesture()
    var doubleTimer: Timer?
    var doubleClickMode = UserDefaults.standard.bool(forKey: "doubleClickMode")
    var enabled = true
    var threshold: Double = UserDefaults.standard.object(forKey: "holdSeconds") as? Double ?? 0.55

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "한/A"
        rebuildStatusMenu()
        installTap()
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refreshTitle() }
    }

    func installTap() {
        guard tap == nil else { return }
        guard AXIsProcessTrusted() else { refreshTitle(); return }
        let mask = (CGEventMask(1) << CGEventType.rightMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.rightMouseUp.rawValue)
            | (CGEventMask(1) << CGEventType.rightMouseDragged.rawValue)
            | (CGEventMask(1) << CGEventType.leftMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.otherMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.scrollWheel.rawValue)
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                return Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue().handle(type, event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        if let tap {
            source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        refreshTitle()
    }

    func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            releasePending()
            swallowedLongPress = false
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == replayMarker {
            return Unmanaged.passUnretained(event)
        }
        guard enabled else { return Unmanaged.passUnretained(event) }
        if doubleClickMode { return handleDoubleClick(type, event) }
        switch type {
        case .rightMouseDown:
            // Let modifier-clicks retain their application-specific meaning.
            if !event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty {
                return Unmanaged.passUnretained(event)
            }
            pendingDown = event.copy()
            swallowedLongPress = false
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: threshold, repeats: false) { [weak self] _ in
                guard let self, self.pendingDown != nil else { return }
                self.pendingDown = nil
                self.swallowedLongPress = true
                // Wait for release before opening the menu, avoiding an unmatched mouse-up.
            }
            return nil
        case .rightMouseDragged:
            if swallowedLongPress { return nil }
            if let down = pendingDown {
                let distance = hypot(event.location.x - down.location.x, event.location.y - down.location.y)
                if distance < 5 { return nil }
                releasePending()
                if let drag = event.copy() { replay(drag) }
                return nil
            }
            return Unmanaged.passUnretained(event)
        case .rightMouseUp:
            timer?.invalidate(); timer = nil
            if swallowedLongPress {
                swallowedLongPress = false
                DispatchQueue.main.async { [weak self] in self?.showLanguageMenu() }
                return nil
            }
            if let down = pendingDown {
                pendingDown = nil
                replay(down)
                if let up = event.copy() { replay(up) }
                return nil
            }
            return Unmanaged.passUnretained(event)
        default: return Unmanaged.passUnretained(event)
        }
    }

    func handleDoubleClick(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let result = doubleGesture.process(type, event, now: ProcessInfo.processInfo.systemUptime,
                                           interval: NSEvent.doubleClickInterval)
        doubleTimer?.invalidate(); doubleTimer = nil
        for buffered in result.replay { replay(buffered) }
        if let deadline = doubleGesture.deadline {
            let timer = Timer(timeInterval: max(0.001, deadline - ProcessInfo.processInfo.systemUptime), repeats: false) { [weak self] _ in
                guard let self else { return }
                for buffered in self.doubleGesture.flush() { self.replay(buffered) }
                self.doubleTimer = nil
            }
            doubleTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
        if result.activate { DispatchQueue.main.async { [weak self] in self?.showLanguageMenu() } }
        if result.consumed { return nil }
        if !result.replay.isEmpty {
            if let copy = event.copy() { replay(copy) }
            return nil
        }
        return Unmanaged.passUnretained(event)
    }

    func replay(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: replayMarker)
        event.post(tap: .cgSessionEventTap)
    }
    func releasePending() {
        timer?.invalidate(); timer = nil
        doubleTimer?.invalidate(); doubleTimer = nil
        for event in doubleGesture.flush() { replay(event) }
        if let down = pendingDown { pendingDown = nil; replay(down) }
    }
    func property(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let value = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
    }
    func inputSources() -> [TISInputSource] {
        let filter = [kTISPropertyInputSourceIsEnabled as String: true,
                      kTISPropertyInputSourceIsSelectCapable as String: true] as CFDictionary
        let sources = TISCreateInputSourceList(filter, false).takeRetainedValue() as! [TISInputSource]
        return sources.filter { property($0, kTISPropertyInputSourceCategory) == (kTISCategoryKeyboardInputSource as String) }
    }
    func currentID() -> String {
        property(TISCopyCurrentKeyboardInputSource().takeRetainedValue(), kTISPropertyInputSourceID) ?? ""
    }
    func languageMenu() -> NSMenu {
        let menu = NSMenu()
        let current = currentID()
        let sources = inputSources()
        for source in sources {
            guard let id = property(source, kTISPropertyInputSourceID) else { continue }
            let label = property(source, kTISPropertyLocalizedName) ?? id
            let entry = NSMenuItem(title: label, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = id
            entry.isEnabled = sources.contains { property($0, kTISPropertyInputSourceID) == id }
            entry.state = current == id ? .on : .off
            menu.addItem(entry)
        }
        menu.autoenablesItems = false
        menu.addItem(.separator())
        let cancel = NSMenuItem(title: "취소", action: nil, keyEquivalent: "")
        menu.addItem(cancel)
        return menu
    }
    func showLanguageMenu() {
        let sources = inputSources()
        let current = currentID()
        if let id = alternateInputSource(ids: sources.compactMap { property($0, kTISPropertyInputSourceID) }, current: current) {
            switchLanguage(id)
            return
        }
        languageMenu().popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    @objc func selectLanguage(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        switchLanguage(id)
    }
    func switchLanguage(_ id: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let target = self.inputSources().first(where: { self.property($0, kTISPropertyInputSourceID) == id }) else {
                self.showError("입력 소스를 찾을 수 없습니다. 시스템 설정의 입력 소스를 확인해 주세요."); return
            }
            let status = TISSelectInputSource(target)
            if status != noErr { self.showError("입력 소스 전환 실패: \(status)") }
            self.refreshTitle()
        }
    }
    func refreshTitle() {
        item.button?.title = !enabled ? "한/A ⏸" : (tap == nil ? "한/A !" : (currentID().contains("Korean") ? "한" : "A"))
    }
    func rebuildStatusMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Flipput · 맥미니에서 실행", action: nil, keyEquivalent: ""))
        let language = NSMenuItem(title: "입력 언어", action: nil, keyEquivalent: "")
        language.submenu = languageMenu(); menu.addItem(language)
        add(menu, enabled ? "우클릭 전환 일시 중지" : "우클릭 전환 재개", #selector(toggle))
        let trigger = NSMenuItem(title: "호출 방식", action: nil, keyEquivalent: "")
        let triggers = NSMenu()
        for (title, useDouble) in [("길게 우클릭", false), ("우클릭 더블클릭", true)] {
            let entry = NSMenuItem(title: title, action: #selector(setTrigger(_:)), keyEquivalent: "")
            entry.target = self; entry.representedObject = useDouble
            entry.state = doubleClickMode == useDouble ? .on : .off
            triggers.addItem(entry)
        }
        trigger.submenu = triggers; menu.addItem(trigger)
        let timing = NSMenuItem(title: "누르는 시간", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for seconds in [0.35, 0.55, 0.8] {
            let entry = NSMenuItem(title: String(format: "%.2f초", seconds), action: #selector(setThreshold(_:)), keyEquivalent: "")
            entry.target = self; entry.representedObject = seconds
            entry.state = abs(threshold - seconds) < 0.01 ? .on : .off
            submenu.addItem(entry)
        }
        timing.submenu = submenu; menu.addItem(timing)
        menu.addItem(.separator())
        add(menu, "손쉬운 사용 권한 요청", #selector(requestPermission))
        add(menu, "권한 적용 후 다시 연결", #selector(retry))
        add(menu, "종료", #selector(quit))
        menu.delegate = self
        item.menu = menu
    }
    func menuWillOpen(_ menu: NSMenu) {
        if menu === item.menu { menu.items.first(where: { $0.title == "입력 언어" })?.submenu = languageMenu() }
    }
    func add(_ menu: NSMenu, _ title: String, _ action: Selector) {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self; menu.addItem(entry)
    }
    @objc func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    @objc func retry() { installTap(); if tap == nil { showError("손쉬운 사용 권한을 허용한 뒤 앱을 종료하고 다시 실행해 주세요.") } }
    @objc func toggle() { releasePending(); swallowedLongPress = false; enabled.toggle(); rebuildStatusMenu(); refreshTitle() }
    @objc func setTrigger(_ sender: NSMenuItem) {
        releasePending(); swallowedLongPress = false
        doubleClickMode = sender.representedObject as? Bool ?? false
        UserDefaults.standard.set(doubleClickMode, forKey: "doubleClickMode")
        rebuildStatusMenu()
    }
    @objc func setThreshold(_ sender: NSMenuItem) {
        threshold = sender.representedObject as? Double ?? 0.55
        UserDefaults.standard.set(threshold, forKey: "holdSeconds"); rebuildStatusMenu()
    }
    @objc func quit() { releasePending(); NSApplication.shared.terminate(nil) }
    func showError(_ message: String) {
        let alert = NSAlert(); alert.messageText = "Flipput"; alert.informativeText = message; alert.runModal()
    }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
