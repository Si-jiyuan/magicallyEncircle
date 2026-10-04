//
//  CustomGesture.swift
//  magicallyEncircle
//

import CoreGraphics
import Foundation

struct CodablePoint: Codable {
    var x: Double
    var y: Double

    init(_ point: CGPoint) {
        x = Double(point.x)
        y = Double(point.y)
    }

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

/// 用户自己录制的图案，可绑定一个快捷键。
struct CustomGesture: Codable, Identifiable {
    let id: UUID
    var name: String
    var points: [CodablePoint]
    var keyCode: UInt16?
    var modifierFlags: UInt64
    var keyDisplay: String

    init(id: UUID = UUID(), name: String, points: [CGPoint]) {
        self.id = id
        self.name = name
        self.points = points.map(CodablePoint.init)
        self.keyCode = nil
        self.modifierFlags = 0
        self.keyDisplay = ""
    }

    var menuTitle: String {
        keyDisplay.isEmpty ? name : "\(name)（\(keyDisplay)）"
    }
}

/// 用 UserDefaults 持久化自定义手势。
final class CustomGestureStore {
    private let key = "magicallyEncircle.customGestures"

    func load() -> [CustomGesture] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([CustomGesture].self, from: data)) ?? []
    }

    func save(_ gestures: [CustomGesture]) {
        guard let data = try? JSONEncoder().encode(gestures) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
