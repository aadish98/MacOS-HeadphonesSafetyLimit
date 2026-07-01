import AppKit
import HeadphoneSafetyCore
import SwiftUI

struct MenuView: View {
    @ObservedObject var audioController: AudioController
    @ObservedObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            limitControl
            footer
        }
        .padding(18)
        .frame(width: 300)
        .onAppear {
            audioController.apply(settings: settings)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(iconTint.opacity(0.16))
                Image(systemName: "headphones")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(iconTint)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text("Reduce Loud Audio")
                    .font(.system(size: 13, weight: .semibold))
                Text(statusLine)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: binding(\.protectionEnabled))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    private var limitControl: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text("Volume Limit")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(ceilingPercent)%")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
            }

            HStack(spacing: 9) {
                Image(systemName: "speaker.wave.1.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Slider(value: binding(\.volumeCeiling), in: 0.1...1.0)
                    .controlSize(.small)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Text("Approximately \(estimatedDB) dB max")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .opacity(settings.protectionEnabled ? 1 : 0.4)
        .disabled(!settings.protectionEnabled)
        .animation(.easeInOut(duration: 0.15), value: settings.protectionEnabled)
    }

    private var footer: some View {
        HStack(spacing: 0) {
            Text("Built-in speakers stay unlimited")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)

            Spacer(minLength: 8)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .keyboardShortcut("q")
        }
    }

    private var ceilingPercent: Int {
        Int((settings.volumeCeiling * 100).rounded())
    }

    private var estimatedDB: Int {
        VolumeLimitSettings.estimatedDB(forVolumeCeiling: settings.volumeCeiling)
    }

    private var statusLine: String {
        guard settings.protectionEnabled else { return "Protection off" }

        let route = audioController.route
        switch route.kind {
        case .unavailable:
            return "No output device"
        case .builtInSpeakers:
            return "Built-in speakers · not limited"
        case .wiredHeadphones, .bluetoothHeadphones, .usbHeadphones, .other:
            if !route.canSetVolume {
                return "\(route.deviceName) · volume read-only"
            }
            return "Limiting \(route.deviceName)"
        }
    }

    private var iconTint: Color {
        guard settings.protectionEnabled else { return .gray }
        return audioController.route.isLimited ? .green : .gray
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
