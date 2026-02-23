import SwiftUI

@main
struct PasswordlessSudoApp: App {
    @StateObject private var sudoManager = SudoManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(sudoManager: sudoManager)
        } label: {
            Image(systemName: sudoManager.status.isEnabled ? "lock.open.fill" : "lock.fill")
        }
    }
}
