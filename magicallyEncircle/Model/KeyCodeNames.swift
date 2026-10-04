//
//  KeyCodeNames.swift
//  magicallyEncircle
//

import CoreGraphics

/// 虚拟键码 → 显示名称，用于展示用户绑定的快捷键。
enum KeyCodeNames {
    static func name(for keyCode: CGKeyCode) -> String {
        map[keyCode] ?? "Key\(keyCode)"
    }

    /// 按 ⌃⌥⇧⌘ + 按键 的顺序拼接显示。
    static func displayString(keyCode: CGKeyCode, flags: CGEventFlags) -> String {
        var result = ""
        if flags.contains(.maskControl) { result += "⌃" }
        if flags.contains(.maskAlternate) { result += "⌥" }
        if flags.contains(.maskShift) { result += "⇧" }
        if flags.contains(.maskCommand) { result += "⌘" }
        result += name(for: keyCode)
        return result
    }

    private static let map: [CGKeyCode: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 50: "`",
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        71: "⌧", 76: "⌤", 117: "⌦",
        115: "↖", 116: "⇞", 119: "End", 121: "⇟", 123: "←", 124: "→",
        125: "↓", 126: "↑",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        103: "F11", 105: "F13", 107: "F14", 109: "F10", 111: "F12",
        113: "F15", 114: "Help", 118: "F4", 120: "F2", 122: "F1"
    ]
}
