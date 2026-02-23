# Passwordless Sudo

A lightweight macOS menu bar app that lets you toggle passwordless `sudo` on and off without ever touching the terminal.

---

## What it does

By default, macOS requires your password every time you run a `sudo` command. This app lets you flip that on or off from your menu bar in one click — no manual editing of sudoers files required.

When enabled, it writes a validated rule to `/etc/sudoers.d/passwordless-sudo` that grants your user account full passwordless sudo access. When disabled, it removes that file and clears your cached sudo credentials.

---

## Features

- **One-click toggle** — enable or disable passwordless sudo instantly
- **Lives in your menu bar** — no dock icon, stays out of your way
- **Color-coded status indicator** so you always know your current state
- **Safe by design** — validates the sudoers file with `visudo` before and after every change, rolls back automatically if anything goes wrong
- **Detects external rules** — if passwordless sudo is already active from another source, it shows that separately instead of overwriting it

---

## Status indicators

The menu bar icon shows a **closed lock** (`🔒`) when sudo requires a password, and an **open lock** (`🔓`) when passwordless sudo is active.

Click the icon to open the menu, where a color-coded dot shows the exact state:

| Dot | Label | Meaning |
|-----|-------|---------|
| 🟢 Green | Enabled | Passwordless sudo is active (managed by this app) |
| ⚫ Gray | Disabled | Password is required for sudo (normal state) |
| 🟠 Orange | Enabled (External) | Passwordless sudo is active but set by another rule — this app won't touch it |
| 🔴 Red | Error / Not Permitted | Something went wrong, or your account isn't in the sudoers file at all |

---

## Requirements

- macOS 13 Ventura or later
- Admin account (you'll be prompted for your password once when toggling — that's how it writes to `/etc/sudoers.d/`)

---

## Building from source

1. Clone the repo
```bash
git clone https://github.com/xxxNULLxxx/Passwordless-sudo.git
```

2. Open the project in Xcode

3. Select your Mac as the target and hit **Run**

No external dependencies or package manager required.

---

## How it works

When you hit **Enable**, the app runs a privileged shell script (via AppleScript's `do shell script ... with administrator privileges`) that:

1. Writes the sudoers rule to a temporary pending file
2. Sets the correct ownership (`root:wheel`) and permissions (`0440`)
3. Validates the file with `visudo -c`
4. Moves it into place at `/etc/sudoers.d/passwordless-sudo`
5. Validates the full sudoers config again
6. Rolls back and cleans up if any step fails

When you hit **Disable**, it removes the managed file and runs `sudo -k` to clear your cached credentials immediately.

The menu bar icon switches between a closed lock (`🔒`) and open lock (`🔓`) to reflect the current state at a glance.

---

## Keyboard shortcuts

| Key | Action |
|-----|--------|
| `R` | Refresh status |
| `Q` | Quit |

---

## License

MIT — see [LICENSE](LICENSE) for details.
