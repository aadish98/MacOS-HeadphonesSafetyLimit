import AppKit
import SwiftUI

struct MenuView: View {
    @ObservedObject var audioController: AudioController
    @ObservedObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()

            Toggle("Reduce Loud Audio", isOn: binding(\.protectionEnabled))
                .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Volume Ceiling")
                    Spacer()
                    Text("\(ceilingPercent)%")
                        .monospacedDigit()
                }

                Slider(value: binding(\.volumeCeiling), in: 0.1...1.0, step: 0.01)

                Text("\(roughDBLabel) · volume-cap proxy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            scopeControls

            Divider()

            statusSection

            Divider()

            Button("Quit Headphone Safety") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(14)
        .frame(width: 340)
        .onAppear {
            audioController.apply(settings: settings)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: statusIconName)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 2) {
                Text("Headphone Safety")
                    .font(.headline)
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var scopeControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Protect")
                .font(.subheadline.weight(.semibold))

            Toggle("Wired / USB headphones", isOn: binding(\.applyToWired))
            Toggle("Bluetooth headphones", isOn: binding(\.applyToBluetooth))
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Current Output")
                .font(.subheadline.weight(.semibold))

            Text(audioController.route.deviceName)
                .font(.body)

            Text(audioController.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !audioController.route.isHeadphones {
                Text("Not detected as headphones, so no cap is applied.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !audioController.route.canSetVolume {
                Text("This output appears read-only to CoreAudio.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var ceilingPercent: Int {
        Int((settings.volumeCeiling * 100).rounded())
    }

    private var currentVolumePercent: Int? {
        audioController.route.currentVolume.map { Int(($0 * 100).rounded()) }
    }

    private var headerSubtitle: String {
        guard settings.protectionEnabled else { return "Protection is off" }
        guard audioController.route.isHeadphones else { return "Waiting for headphones" }
        guard isCurrentRouteInScope else { return "Current headphones are out of scope" }
        return "Protecting at \(ceilingPercent)% max"
    }

    private var statusIconName: String {
        guard settings.protectionEnabled else { return "headphones" }
        return audioController.route.isHeadphones && isCurrentRouteInScope ? "ear.badge.checkmark" : "headphones"
    }

    private var isCurrentRouteInScope: Bool {
        switch audioController.route.kind {
        case .wiredHeadphones, .usbHeadphones:
            return settings.applyToWired
        case .bluetoothHeadphones:
            return settings.applyToBluetooth
        case .builtInSpeakers, .other, .unavailable:
            return false
        }
    }

    private var roughDBLabel: String {
        switch settings.volumeCeiling {
        case ..<0.4:
            return "~70 dB equivalent"
        case ..<0.55:
            return "~75 dB equivalent"
        case ..<0.7:
            return "~85 dB equivalent"
        case ..<0.85:
            return "~90 dB equivalent"
        default:
            return "~95+ dB equivalent"
        }
    }

    private func binding<Value>(_ keyPath: ReferenceWritableKeyPath<SettingsStore, Value>) -> Binding<Value> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                settings[keyPath: keyPath] = newValue
                audioController.apply(settings: settings)
            }
        )
    }
}
