//
//  magicallyEncircleApp.swift
//  magicallyEncircle
//

import SwiftUI

@main
struct magicallyEncircleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
