// Drive the Connect IQ simulator's Forerunner 265 like a person: press its
// buttons and capture the watch, for screen tests (tools/screens.sh).
//     swift tools/sim.swift press start|back|up|down|light
//     swift tools/sim.swift hold up            (a long press: Up's menu key)
//     swift tools/sim.swift shot out.png       (the simulator window)
//     swift tools/sim.swift bounds x           (its x,y,w,h, for screencapture -R)
// Needs Accessibility (to click) and Screen Recording (to capture) for the
// terminal, in System Settings > Privacy & Security.
import AppKit
import CoreGraphics

// Where each button sits in the simulator's window, as fractions of it
let buttons: [String: (Double, Double)] = [
    "start": (0.911, 0.344), "back": (0.911, 0.653),
    "up": (0.059, 0.487), "down": (0.099, 0.653), "light": (0.119, 0.347),
]

func simulatorWindow() -> (id: CGWindowID, bounds: CGRect, pid: pid_t)? {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    for w in list where (w[kCGWindowOwnerName as String] as? String) == "Connect IQ Device Simulator" {
        guard let b = w[kCGWindowBounds as String] as? [String: Any],
              let rect = CGRect(dictionaryRepresentation: b as CFDictionary),
              rect.height > 400 else { continue }
        return (w[kCGWindowNumber as String] as! CGWindowID, rect, w[kCGWindowOwnerPID as String] as! pid_t)
    }
    return nil
}

func click(_ point: CGPoint, holdFor: Double) {
    let src = CGEventSource(stateID: .hidSystemState)
    CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(50_000)
    CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(useconds_t(holdFor * 1_000_000))
    CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
}

let args = CommandLine.arguments
guard args.count >= 2, let win = simulatorWindow() else {
    FileHandle.standardError.write("usage: sim.swift press|hold <button> | shot <file>; simulator must be open\n".data(using: .utf8)!)
    exit(1)
}
switch args[1] {
case "press", "hold":
    guard let (fx, fy) = buttons[args[2]] else { print("unknown button \(args[2])"); exit(1) }
    NSRunningApplication(processIdentifier: win.pid)?.activate()
    usleep(150_000)
    let point = CGPoint(x: win.bounds.minX + fx * win.bounds.width, y: win.bounds.minY + fy * win.bounds.height)
    click(point, holdFor: args[1] == "hold" ? 1.5 : 0.08)
case "bounds":
    // The window as x,y,w,h in points, for screencapture -R
    print("\(Int(win.bounds.minX)),\(Int(win.bounds.minY)),\(Int(win.bounds.width)),\(Int(win.bounds.height))")
case "shot":
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    task.arguments = ["-x", "-o", "-l\(win.id)", args[2]]
    try task.run()
    task.waitUntilExit()
default:
    exit(1)
}
