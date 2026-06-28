import SwiftUI
import AppKit

@main
struct TossNoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 920, minHeight: 680)
        }
        .windowStyle(.titleBar)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let icon = packagedIcon() ?? developmentIcon() {
            NSApp.applicationIconImage = icon
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func packagedIcon() -> NSImage? {
        guard let iconURL = Bundle.main.url(forResource: "TossNote", withExtension: "icns") else {
            return nil
        }

        return NSImage(contentsOf: iconURL)
    }

    private func developmentIcon() -> NSImage? {
        guard let iconURL = Bundle.module.url(forResource: "TossNoteIcon", withExtension: "png") else {
            return nil
        }

        return NSImage(contentsOf: iconURL)
    }
}
