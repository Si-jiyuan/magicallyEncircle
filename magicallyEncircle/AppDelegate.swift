//
//  AppDelegate.swift
//  magicallyEncircle
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusMenu: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        MagicController.shared.start()
        statusMenu = StatusMenuController(controller: MagicController.shared)
    }

    func applicationWillTerminate(_ notification: Notification) {
        MagicController.shared.stop()
    }
}
