//
//  GesturePackage.swift
//  magicallyEncircle
//

import Foundation

/// 导出的图案文件格式，便于分享给他人导入。
/// `builtInOverrides` 为可选，兼容旧版本文件。
struct GesturePackage: Codable {
    var version: Int
    var gestures: [CustomGesture]
    var builtInOverrides: [String: [[[CodablePoint]]]]?
}
