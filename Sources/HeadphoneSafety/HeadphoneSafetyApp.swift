import AppKit
import SwiftUI

@main
struct HeadphoneSafetyApp: App {
    var body: some Scene {
        MenuBarExtra("Headphone Safety", systemImage: "headphones") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Headphone Safety")
                    .font(.headline)

                Text("CoreAudio protection will be available in the next milestone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding()
            .frame(width: 280)
        }
        .menuBarExtraStyle(.window)
    }
}
