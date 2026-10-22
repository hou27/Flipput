# Flipput

> A tiny macOS menu bar app that switches the Mac's input source (e.g., between Korean and English) with a right-click. It can be used to switch between Korean and English on a remote Mac when accessing it from a local machine through Chrome Remote Desktop.

> 우클릭 한 번으로 Mac의 입력 소스(e.g., 한/영 전환)를 전환하는 macOS용 메뉴 막대 앱입니다. Chrome 원격 데스크톱을 통해 로컬 호스트에서 원격 Mac을 사용할 때, 원격 Mac의 한국어와 영어 입력 전환이 불편한 것을 간단히 해소하기 위해 만든 프로그램입니다.

## Main Technologies Used

- Swift, AppKit
- CGEvent Tap
- Text Input Source Services (`TISSelectInputSource`)
- Accessibility API

## Requirements

- macOS 13+
- Xcode Command Line Tools

## Features

- Switch Korean/English with a **long right-click** or a **double right-click**.
- If there are _two_ input sources, it **switches to the other one right away** without a menu.
- If there are more, it shows a **picker menu** next to the cursor.
- It **selects the macOS input source directly** instead of faking keyboard shortcuts.
- Normal right-clicks, right-drags and modifier + right-clicks **work in the app as usual**.
- No network features, so **nothing is sent anywhere**.

# How to use

## 1. Build the app first

```bash
bash build.sh
```

- `dist/Flipput.app` is built for the current Mac's CPU (Apple Silicon / Intel).
- If the Mac mini is an Intel Mac, please build it on an Intel Mac.

## 2. Move it to Applications on the Mac mini and open it

- `한/A !` shows up in the menu bar. (`!` means it doesn't have permission yet)
- It's ad-hoc signed and not notarized, so macOS may block it on another Mac. In that case, building it on that Mac is the simplest way.

## 3. Allow Accessibility

- Menu bar → **손쉬운 사용 권한 요청** (Request Accessibility permission)
- System Settings → Privacy & Security → Accessibility → turn on **Flipput**
- Menu bar → **권한 적용 후 다시 연결** (Reconnect). If `!` is still there, quit and open the app again.
- The input sources you use (e.g. ABC, 2-Set Korean) should be added in System Settings → Keyboard → Text Input → Input Sources.

## 4. Now you can switch Korean/English with a right-click

| Trigger                    | How                                                     |
| -------------------------- | ------------------------------------------------------- |
| Long right-click (default) | Hold the right button for 0.55s, then release           |
| Double right-click         | Right-click twice quickly at the same spot (within 5pt) |

- You can change it in menu bar → **호출 방식** (Trigger), and it's kept after restarting.
- Long right-click: a short right-click is sent to the app when you release it, so context menus open a bit later than usual.
- Double right-click: uses the system double-click speed. The first right-click is held for that time, so a single right-click menu also opens a bit late.
- Right-drag (more than 5pt) and ⌘ / ⌃ / ⌥ / ⇧ + right-click are left to the app.
- In the picker menu, Esc or clicking outside cancels.

## 5. Try the menu bar options too!

- `A` / `한`: current input source (`⏸` paused, `!` no permission)
- **입력 언어** (Input source): pick one manually, anytime
- **우클릭 전환 일시 중지 / 재개** (Pause / Resume)
- **호출 방식** (Trigger): long right-click / double right-click
- **누르는 시간** (Hold time): 0.35 / 0.55 / 0.8s
- **종료** (Quit)

## Development

```bash
bash test.sh   # logic tests (no real mouse events)
bash build.sh  # build + ad-hoc sign
```

- `Sources/main.swift`: menu bar UI, event tap, long press, input source switching
- `Sources/DoubleClickGesture.swift`: double right-click detection
- `Sources/InputSelection.swift`: picks the other source when there are two
- `Scripts/make_icon.swift`: draws the app icon (`build.sh` turns it into `AppIcon.icns`)
- `Tests/main.swift`: tests
