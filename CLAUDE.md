# PasswordlessSudo — Project Notes

## What This Is
macOS menu bar app that toggles passwordless sudo on/off with a single click.
Internal-use only — unsandboxed, no App Store, AppleScript privilege escalation.
Requires macOS Ventura+ (uses `MenuBarExtra`).

## Current Status
- App is fully built and working
- Enable/disable confirmed working via live sudo tests
- Archived via Xcode (Product → Archive → Custom → Copy App)

## Architecture

### Files
| File | Purpose |
|---|---|
| `SudoManager.swift` | Core logic — status detection, enable/disable, privilege escalation |
| `PasswordlessSudoApp.swift` | `@main` entry point, `MenuBarExtra` with lock icon |
| `MenuBarView.swift` | Dropdown UI — status label, toggle button, refresh, quit |
| `Info.plist` | `LSUIElement = true` (no dock icon) |
| `PasswordlessSudo.entitlements` | App sandbox disabled |
| `Assets.xcassets/` | Asset catalog (app icon placeholder) |
| `project.pbxproj` | Xcode project, targets macOS 13.0, Swift 5, auto signing |

### Status Detection (two signals)
1. **Managed file check:** `FileManager.default.fileExists(atPath: "/private/etc/sudoers.d/passwordless-sudo")`
2. **Behavioral sudo test:** `sudo -k -n /usr/bin/true` (exit 0 = truly passwordless, `-k` resets cache)

| File exists? | Sudo test | Status shown |
|---|---|---|
| Yes | Passes | Enabled |
| No | Fails | Disabled |
| No | Passes | Enabled (External) — toggle disabled |
| Yes | Fails | Error |
| — | "not allowed" stderr | Not Permitted — toggle disabled |

### Enable Flow (atomic)
All inside one privileged `osascript` call:
1. Write rule to pending file: `/private/etc/sudoers.d/.passwordless-sudo.pending` (dot = sudo ignores it)
2. `chown root:wheel`, `chmod 0440`
3. `visudo -c -f <pending>` — validate syntax
4. `mv -f pending → passwordless-sudo`
5. `visudo -c` — validate full policy
6. Rollback (`rm -f`) if validation fails

### Disable Flow
1. Privileged `osascript`: `rm -f /private/etc/sudoers.d/passwordless-sudo`
2. `visudo -c`
3. `sudo -k` (unprivileged) — clears cached credentials immediately

### Sudoers Rule
```
<username> ALL=(ALL) NOPASSWD: ALL
```
File: `/private/etc/sudoers.d/passwordless-sudo`
Owner: `root:wheel`, Mode: `0440`

### Key Implementation Notes
- Username from `NSUserName()`
- User cancel on auth dialog (AppleScript `-128` / "User canceled") is silently ignored — not treated as error
- `isBusy` flag prevents double-toggles while osascript is in flight
- All shell commands use absolute paths (AppleScript has minimal PATH)

## Distribution
- Build: Product → Archive in Xcode
- Export: Distribute App → Custom → Copy App
- Install: drag `.app` to `/Applications`
- If Gatekeeper blocks it: `xattr -d com.apple.quarantine /Applications/PasswordlessSudo.app`

## Auto-Launch (current workaround)
System Settings → General → Login Items & Extensions → add `PasswordlessSudo.app`

---

## Planned Features

### Launch at Login toggle (in-app)
Add a "Launch at Login" menu item that registers/unregisters the app from login items using `SMAppService`.

```swift
import ServiceManagement

// Register
try SMAppService.mainApp.register()

// Unregister
try SMAppService.mainApp.unregister()

// Check current state
SMAppService.mainApp.status == .enabled
```

UI addition to `MenuBarView.swift`:
- Toggle: `Toggle("Launch at Login", isOn: $launchAtLogin)`
- Persisted in `UserDefaults` and synced with `SMAppService` state
- Place it below the Refresh button, above Quit

No entitlement changes needed — `SMAppService` works without sandbox.
