<p align="center">
  <h1 align="center">MenuBarTodo</h1>
  <p align="center">
    <strong>A featherweight TODO app that lives in your macOS menu bar.</strong>
  </p>
  <p align="center">
    Pure AppKit · C SQLite3 · Zero Dependencies · ~12 MB Memory
  </p>
</p>

---

Most TODO apps are Electron behemoths eating 200+ MB of RAM just to show a checkbox. **MenuBarTodo** takes a different approach — it's a native macOS app built with pure AppKit and raw C SQLite3 calls, with **zero third-party dependencies**. The entire binary is under 300 KB.

## Features

- **Menu bar native** — always one click (or hotkey) away, never clutters your Dock
- **Global hotkey** `Cmd+Shift+T` — instant access from anywhere
- **Ultra-lightweight** — ~12 MB physical memory, 280 KB app bundle
- **Priority levels** — color-coded dots (None / Low / Medium / High)
- **Due dates** — with overdue highlighting in red
- **Smart filters** — switch between All / Active / Completed views
- **Quick add** — type and press Return, that's it
- **Double-click to complete** — no fiddly checkbox hunting
- **Right-click to edit** — inline context menu for details
- **Export/Import** — JSON and CSV support for your data
- **Auto-backup** — daily database backups, keeps last 7 days
- **Dark mode** — fully supports macOS light and dark themes

## Screenshots

When you have pending tasks, the menu bar shows an **orange count**:

```
  3                          ← orange badge in menu bar
┌─────────────────────────┐
│ Add a new task... (⏎)  ⚙│
│ [All] [Active] [Done]   │
│──────────────────────────│
│ ● Buy groceries          │
│ ● Fix login bug     ⚡   │
│ ● Read chapter 5   📅   │
│──────────────────────────│
│ 3 tasks remaining  Clear │
└──────────────────────────┘
```

When all tasks are done, a clean **checkmark icon** appears:

```
  ✓                          ← template icon in menu bar
```

## Installation

### One-command install (recommended)

```bash
git clone https://github.com/jjliu090/MenuBarTodo.git
cd MenuBarTodo
./scripts/install.sh
```

This builds, packages, signs (ad-hoc), installs to `/Applications`, and launches — all in one step. No Xcode required, no Apple Developer account needed.

### Update

```bash
cd MenuBarTodo
git pull
./scripts/install.sh
```

Same command. It stops the running instance, rebuilds, and relaunches.

### Build manually

```bash
swift build -c release
```

The binary is at `.build/release/MenuBarTodo`.

## Usage

| Action | How |
|---|---|
| Open/close | Click menu bar icon or `Cmd+Shift+T` |
| Add task | Type in the text field, press `Return` |
| Complete task | Double-click the task row |
| Edit task | Right-click → Edit Task |
| Delete task | Right-click → Delete, or select + `Cmd+Delete` |
| Toggle with keyboard | Select row + `Space` |
| Filter tasks | Click All / Active / Completed |
| Export data | Gear icon → Export as JSON/CSV |
| Quit | Gear icon → Quit MenuBarTodo |

## Architecture

MenuBarTodo follows a strict ultra-low memory architecture:

```
┌─────────────────────────────────────────┐
│              AppDelegate                │
│  (permanent: status item + popover)     │
├─────────────────────────────────────────┤
│          TaskListController             │
│  (transient: created on open,           │
│   deallocated on close)                 │
├─────────────────────────────────────────┤
│             TaskStore                   │
│  (C SQLite3 FFI, WAL mode,             │
│   connection opened/closed with         │
│   popover lifecycle)                    │
└─────────────────────────────────────────┘
```

**Key design decisions:**

- **Pure AppKit** — no SwiftUI, no Combine, no reactive frameworks
- **C SQLite3 API** — direct `sqlite3_prepare_v2` / `sqlite3_step` / `sqlite3_finalize` calls, no ORM
- **Value-type models** — `TaskItem` is a struct (~120 bytes), stored in contiguous arrays
- **Transient lifecycle** — the entire view hierarchy and DB connection are created when the popover opens and fully released when it closes
- **Core Graphics rendering** — menu bar icon drawn programmatically, no image assets

**Memory profile:**

| Metric | Value |
|---|---|
| App bundle size | 280 KB |
| Binary size | 266 KB |
| Database (100 tasks) | ~24 KB |
| Physical memory (active) | ~12-16 MB |
| Dirty memory (exclusive) | ~12 MB |
| Third-party dependencies | **0** |

## Requirements

- macOS 13.0 (Ventura) or later
- Swift 5.9+

## Tech Stack

| Layer | Technology |
|---|---|
| UI Framework | AppKit (NSTableView, NSPopover) |
| Database | C SQLite3 via system `libsqlite3` |
| Icon Rendering | Core Graphics |
| Global Hotkey | Carbon `RegisterEventHotKey` API |
| Build System | Swift Package Manager |
| Signing | Ad-hoc (no developer account required) |

## Project Structure

```
MenuBarTodo/
├── Sources/
│   ├── main.swift              # App entry point
│   ├── AppDelegate.swift       # Status item + popover lifecycle
│   ├── StatusBarIcon.swift     # Core Graphics menu bar icon
│   ├── TaskItem.swift          # Value-type task model
│   ├── TaskStore.swift         # SQLite3 database layer
│   ├── TaskListController.swift# Main UI controller
│   ├── TaskCellView.swift      # Table cell with checkbox + priority
│   ├── TaskEditPopover.swift   # Edit popover for task details
│   └── DataExporter.swift      # JSON/CSV export + daily backup
├── scripts/
│   ├── install.sh              # One-command build + install
│   └── build-and-run.sh        # Build and launch (dev)
├── Package.swift               # SPM manifest
└── LICENSE
```

## License

[MIT](LICENSE) — use it however you like.

---

<p align="center">
  <em>Because your TODO app shouldn't need more RAM than your TODOs need brain cells.</em>
</p>
