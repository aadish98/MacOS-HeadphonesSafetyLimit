import AppKit
import SwiftUI

@main
@MainActor
struct HeadphoneSafetyApp: App {
    @StateObject private var audioController = AudioController()
    @StateObject private var settings = SettingsStore()

    init() {
        LaunchAtLoginManager.registerMonitorIfNeeded()
    }

    var body: some Scene {
        MenuBarExtra("Headphone Safety", systemImage: "headphones") {
            MenuView(audioController: audioController, settings: settings)
        }
        .menuBarExtraStyle(.window)
    }
}
