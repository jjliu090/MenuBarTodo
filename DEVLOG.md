# MenuBarTodo Development Log

## Project Overview

**Application:** macOS Menu Bar TODO Application
**Architecture:** v2.0 — Ultra-Low Memory Revision
**Tech Stack:** Swift 5.9 + Pure AppKit + C SQLite3 API
**Memory Targets:** < 8 MB RSS idle, < 15 MB RSS active

---

## 2026-04-03 — Initial Project Setup & Full Implementation

### Phase 1: Project Skeleton & Core Infrastructure ✅

**Tasks completed:**
1. Created project structure with Swift Package Manager + Xcode project
2. Configured build settings:
   - Deployment target: macOS 13.0 (Ventura)
   - Release optimization: `-Osize` (optimize for binary size)
   - Thin LTO enabled
   - Dead code stripping enabled
   - Hardened Runtime enabled
   - App Sandbox (only `com.apple.security.app-sandbox`)
3. Linked system frameworks only: AppKit, CoreGraphics, Carbon, libsqlite3.tbd
4. Set `LSUIElement = true` (menu bar agent app, no Dock icon)

**Files created:**
- `MenuBarTodo/Sources/main.swift` — App entry point (no @main, no storyboard)
- `MenuBarTodo/Sources/AppDelegate.swift` — Permanent controller: NSStatusItem + NSPopover lifecycle
- `MenuBarTodo/Sources/StatusBarIcon.swift` — Core Graphics drawn 18×18pt template icon + badge
- `MenuBarTodo/Sources/TaskItem.swift` — Value-type struct (~120 bytes), UUID as 16-byte Data
- `MenuBarTodo/Sources/TaskStore.swift` — Singleton with transient sqlite3* handle, direct C API
- `MenuBarTodo/Info.plist` — Bundle configuration
- `MenuBarTodo/MenuBarTodo.entitlements` — Sandbox-only entitlements
- `Package.swift` — Swift Package Manager build configuration

**Key design decisions:**
- Used `main.swift` manual app setup instead of `@main` annotation for explicit control
- TaskItem is a `struct` (not class) for zero ARC overhead per instance
- UUID stored as 16-byte `Data` (BLOB) instead of 36-char String
- Dates stored as Unix timestamps (INTEGER) for storage efficiency
- All SQL as static strings — no dynamic query building

### Phase 1: TaskStore C SQLite3 Implementation ✅

**Database configuration (PRAGMA):**
- `journal_mode = WAL` — lower write amplification
- `cache_size = 64` — 256 KB cache (vs default 2 MB)
- `page_size = 4096` — matches macOS filesystem block size
- `auto_vacuum = INCREMENTAL` — prevents file bloat
- `synchronous = NORMAL` — safe with WAL, avoids per-write fsync
- `wal_autocheckpoint = 100` — automatic WAL checkpoint

**Schema:** Single `tasks` table with 10 columns, 3 indexes:
- `idx_tasks_active` (is_completed, sort_order)
- `idx_tasks_due` (due_date, is_completed)
- `idx_tasks_priority` (priority, is_completed)

**DB lifecycle:** Opened on popover show, closed on popover hide. Zero SQLite memory when idle.

### Phase 2: UI Layer — NSTableView + Cell Reuse ✅

**Files created:**
- `MenuBarTodo/Sources/TaskListController.swift` — Transient NSViewController (data source + delegate)
- `MenuBarTodo/Sources/TaskCellView.swift` — Reusable cell with exactly 4 subviews
- `MenuBarTodo/Sources/TaskEditPopover.swift` — Right-click edit panel (priority, due date, notes)

**UI Layout (320×480 popover):**
- Header: Quick-add NSTextField + gear menu button
- Filter: NSSegmentedControl (All / Active / Completed)
- List: NSScrollView > NSTableView with cell reuse (`makeView(withIdentifier:)`)
- Footer: Task count label + Clear Completed button

**Cell design (4 subviews per cell):**
1. NSButton (checkbox, 18×18pt)
2. NSTextField (title, truncates with ellipsis, inline editable)
3. NSView (priority color dot, 8×8pt, via layer.backgroundColor)
4. NSTextField (due date label, gray/red for overdue)

**Features:**
- Strikethrough on completed tasks via NSAttributedString
- Priority levels: None (hidden) / Low (blue) / Medium (orange) / High (red)
- Right-click context menu: Edit Task / Delete Task
- Edit popover: NSPopUpButton for priority, NSDatePicker for due date, NSTextField for note

### Phase 2: Global Hotkey + Dark Mode ✅

- Global hotkey: Cmd+Shift+T via Carbon `RegisterEventHotKey`
- Dark Mode: Automatic via NSAppearance (template images, system colors)
- Status bar icon: Pure Core Graphics drawing with badge count overlay

### Phase 3: Memory Lifecycle Management ✅

**ACTIVE → IDLE teardown sequence (critical path):**
1. `autoreleasepool` wrapping:
   - `popover.contentViewController = nil`
   - `taskListController = nil` (triggers full dealloc cascade)
2. Auto-backup (daily, 7-day retention)
3. `TaskStore.shared.close()`:
   - `sqlite3_close_v2()` — releases DB connection, page cache, WAL
   - `sqlite3_release_memory(INT_MAX)` — reclaims internal pools
4. Update badge with cached count

**Memory invariant:** RSS must return to < 8 MB within 500ms of popover close.

### Phase 3: Keyboard Navigation & Accessibility ✅

**Keyboard shortcuts:**
- `Cmd+Shift+T` — Global toggle popover
- `Return` — Create task from quick-add field
- `Escape` — Close popover / clear field
- `↑/↓` — Navigate task list
- `Space` — Toggle task completion
- `Cmd+Delete` — Delete selected task
- `Tab` — Move focus between fields

**VoiceOver support:**
- All cells: `setAccessibilityRole(.row)` with descriptive labels
- Labels include completion status, priority, due date
- Quick-add field: accessibility label + help text
- Checkbox: dynamic label ("Mark complete" / "Mark incomplete")

### Phase 4: Data Export/Import & Auto-Backup ✅

**File created:**
- `MenuBarTodo/Sources/DataExporter.swift`

**Features:**
- JSON export: All tasks → formatted JSON via NSSavePanel
- CSV export: All tasks → CSV with proper escaping
- JSON import: Validates structure, imports tasks via NSOpenPanel
- Auto-backup: Timestamped daily copy of tasks.db, 7-day retention, auto-cleanup

**Gear menu items:**
- Export as JSON...
- Export as CSV...
- Import from JSON...
- Quit MenuBarTodo

### Phase 4: Testing ✅

**Test files created:**
- `Tests/TaskStoreTests.swift` — Unit tests for all CRUD operations, data model, connection lifecycle
- `Tests/MemoryTests.swift` — Binary audit (no SwiftUI/Combine symbols), RSS logging

**Test coverage:**
- Insert, fetch, update, delete operations
- Toggle completion with completedAt timestamp
- Clear completed tasks
- Active count tracking
- TaskItem is value type verification
- UUID is 16 bytes verification
- Open/close lifecycle idempotency
- Priority and due date persistence
- No SwiftUI framework symbols loaded
- No Combine framework symbols loaded

---

## Architecture Compliance Checklist

| Requirement | Status | Notes |
|---|---|---|
| Pure AppKit (zero SwiftUI) | ✅ | No SwiftUI import in any file |
| C SQLite3 API (zero ORM) | ✅ | Direct sqlite3_* calls only |
| MVC architecture | ✅ | Delegation + manual control, no MVVM |
| No Combine | ✅ | No reactive bindings |
| TaskItem as struct | ✅ | Value type, ~120 bytes |
| UUID as BLOB(16) | ✅ | Data type, not String |
| Dates as INTEGER | ✅ | Unix timestamps |
| Core Graphics icons | ✅ | No image assets, no SF Symbols import |
| Zero dependencies | ✅ | Only system frameworks |
| App Sandbox | ✅ | Single entitlement |
| Hardened Runtime | ✅ | Enabled in build settings |
| macOS 13.0+ | ✅ | Deployment target set |
| DB lifecycle tied to popover | ✅ | Open on show, close on hide |
| Full teardown on close | ✅ | autoreleasepool + nil assignments |
| Cell reuse | ✅ | makeView(withIdentifier:) |
| LSUIElement (no Dock icon) | ✅ | Info.plist configured |

## File Structure

```
MenuBarTodo/
├── Package.swift                          # SPM build config
├── MenuBarTodo.xcodeproj/                 # Xcode project
├── MenuBarTodo/
│   ├── Info.plist                         # Bundle config (LSUIElement=true)
│   ├── MenuBarTodo.entitlements           # Sandbox only
│   └── Sources/
│       ├── main.swift                     # App entry point
│       ├── AppDelegate.swift              # Status item + popover lifecycle
│       ├── StatusBarIcon.swift            # Core Graphics icon rendering
│       ├── TaskItem.swift                 # Value-type data model
│       ├── TaskStore.swift                # C SQLite3 data layer
│       ├── TaskListController.swift       # Table view controller
│       ├── TaskCellView.swift             # Reusable table cell
│       ├── TaskEditPopover.swift          # Task edit panel
│       └── DataExporter.swift             # Export/import/backup
├── Tests/
│   ├── TaskStoreTests.swift              # CRUD + lifecycle tests
│   └── MemoryTests.swift                 # Memory regression tests
├── MenuBarTodo_Architecture_v2.docx       # Architecture document
└── DEVLOG.md                              # This file
```
