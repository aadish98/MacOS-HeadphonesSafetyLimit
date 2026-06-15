import AppKit
import SwiftUI

@main
@MainActor
struct HeadphoneSafetyApp: App {
    @StateObject private var audioController = AudioController()
    @StateObject private var settings = SettingsStore()

    var body: some Scene {
        MenuBarExtra("Headphone Safety", systemImage: menuBarIconName) {
            MenuView(audioController: audioController, settings: settings)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIconName: String {
        guard settings.protectionEnabled else { return "headphones" }
        return audioController.route.isLimited ? "ear.badge.checkmark" : "headphones"
    }
}
