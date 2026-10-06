//
//  PlaybackSpeed.swift
//  magicallyEncircle
//

import Foundation

/// 图案播放速度（倍速）。
enum PlaybackSpeed {
    static let options: [Double] = [0.25, 0.5, 0.75]

    private static let key = "magicallyEncircle.playbackSpeed"

    static var current: Double {
        get {
            let value = UserDefaults.standard.double(forKey: key)
            return options.contains(value) ? value : 0.5
        }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static func title(_ value: Double) -> String {
        String(format: "%g×", value)
    }
}
