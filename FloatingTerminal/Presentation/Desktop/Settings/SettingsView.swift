import SwiftUI

struct SettingsView: View {
    @State private var state: SettingsViewState

    init(state: SettingsViewState = SettingsViewState()) {
        _state = State(initialValue: state)
    }

    var body: some View {
        Form {
            Section("Global shortcut") {
                HotKeyRecorderView { keyCode, modifiers in
                    state.saveShortcut(keyCode: keyCode, modifiers: modifiers)
                }
                Text(state.shortcutDescription)
                    .foregroundStyle(.secondary)
                Button("Clear shortcut") { state.clearShortcut() }
            }

        }
        .padding()
        .frame(width: 360)
    }
}

#Preview {
    SettingsView(state: SettingsViewState())
}
