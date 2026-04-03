import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {

    // MARK: - Permanent Objects (alive for entire app lifetime)
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    // MARK: - Transient Objects (alive only when popover is open)
    private var taskListController: TaskListController?

    // MARK: - Global Hotkey
    private var hotKeyRef: EventHotKeyRef?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        registerGlobalHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        unregisterGlobalHotKey()
        TaskStore.shared.close()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        button.image = StatusBarIcon.makeIcon()
        button.imagePosition = .imageLeading
        button.action = #selector(togglePopover(_:))
        button.target = self

        updateBadge()
    }

    func updateBadge() {
        guard let button = statusItem.button else { return }
        let needsClose = !TaskStore.shared.isOpen
        if needsClose { TaskStore.shared.open() }
        let count = TaskStore.shared.activeTaskCount()
        if needsClose { TaskStore.shared.close() }
        button.image = StatusBarIcon.makeIcon(badgeCount: count)
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 320, height: 480)
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }

        // IDLE → ACTIVE transition
        TaskStore.shared.open()

        let controller = TaskListController()
        controller.appDelegate = self
        taskListController = controller

        popover.contentViewController = controller
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        // ACTIVE → IDLE teardown (critical path)
        performTeardown()
    }

    private func performTeardown() {
        // ACTIVE → IDLE transition — must complete fully to return to < 8 MB RSS.
        // Each step is critical; the order matters for deterministic deallocation.

        autoreleasepool {
            // 1. Remove content view controller reference from popover
            popover.contentViewController = nil

            // 2. Release the task list controller and entire view tree
            //    This triggers deinit of TaskListController, which clears the [TaskItem] array.
            taskListController = nil
        }

        // 3. Perform daily backup before closing DB (if not done today)
        DataExporter.performDailyBackupIfNeeded()

        // 4. Close database connection, release SQLite memory
        //    sqlite3_close_v2 releases the page cache, WAL shared memory, and compiled statements.
        //    sqlite3_release_memory(INT_MAX) reclaims SQLite's internal allocator pools.
        TaskStore.shared.close()

        // 5. Update badge using cached count (DB is now closed)
        updateBadge()
    }

    // MARK: - Global Hotkey (Carbon API)

    private func registerGlobalHotKey() {
        // Cmd+Shift+T
        let hotKeyID = EventHotKeyID(signature: OSType(0x4D425444), // "MBTD"
                                      id: 1)
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        let keyCode: UInt32 = 17 // 'T' key

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                       eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                appDelegate.togglePopover(nil)
            }
            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, selfPtr, nil)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    private func unregisterGlobalHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}
