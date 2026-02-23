import SwiftUI

struct MenuBarView: View {
    @ObservedObject var sudoManager: SudoManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Passwordless Sudo")
                .font(.headline)

            Divider()

            Text(sudoManager.status.label)
                .font(.subheadline)

            if case .error(let message) = sudoManager.status {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Divider()

            toggleButton

            Divider()

            Button("Refresh") {
                sudoManager.refreshStatus()
            }
            .keyboardShortcut("r")

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(4)
    }

    @ViewBuilder
    private var toggleButton: some View {
        switch sudoManager.status {
        case .enabledExternal:
            Button("Externally managed") {}
                .disabled(true)
        case .notPermitted:
            Button("Account cannot use sudo") {}
                .disabled(true)
        default:
            Button(sudoManager.status.isEnabled ? "Disable" : "Enable") {
                sudoManager.toggle()
            }
            .disabled(!sudoManager.status.canToggle || sudoManager.isBusy)
        }
    }
}
