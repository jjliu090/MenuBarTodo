import AppKit

/// Filter modes for the task list.
enum TaskFilter: Int {
    case all       = 0
    case active    = 1
    case completed = 2
}

/// Transient controller — created when popover opens, fully deallocated on close.
/// Serves as NSTableViewDataSource and NSTableViewDelegate.
final class TaskListController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {

    // MARK: - Properties

    weak var appDelegate: AppDelegate?
    private var tasks: [TaskItem] = []
    private var currentFilter: TaskFilter = .active

    // MARK: - UI Elements

    private var scrollView: NSScrollView!
    private var tableView: NSTableView!
    private var quickAddField: NSTextField!
    private var filterControl: NSSegmentedControl!
    private var footerLabel: NSTextField!
    private var clearButton: NSButton!
    private var gearButton: NSButton!

    // MARK: - Constants

    private static let cellIdentifier = NSUserInterfaceItemIdentifier("TaskCell")
    private static let rowHeight: CGFloat = 44

    // MARK: - Lifecycle

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 480))
        self.view = container
        setupUI()
        loadTasks()
    }

    deinit {
        // Ensure all data is released
        tasks = []
    }

    // MARK: - UI Setup

    private func setupUI() {
        setupHeader()
        setupQuickAdd()
        setupFilterBar()
        setupTableView()
        setupFooter()
        layoutSubviews()
    }

    private func setupHeader() {
        // Gear button for settings/export/import
        gearButton = NSButton(frame: .zero)
        gearButton.bezelStyle = .inline
        gearButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
            ?? NSImage(named: NSImage.actionTemplateName)
        gearButton.imagePosition = .imageOnly
        gearButton.target = self
        gearButton.action = #selector(showGearMenu(_:))
        gearButton.translatesAutoresizingMaskIntoConstraints = false
        gearButton.setAccessibilityLabel("Settings menu")
        view.addSubview(gearButton)
    }

    private func setupQuickAdd() {
        quickAddField = NSTextField()
        quickAddField.placeholderString = "Add a new task... (⏎ to add)"
        quickAddField.font = NSFont.systemFont(ofSize: 13)
        quickAddField.delegate = self
        quickAddField.translatesAutoresizingMaskIntoConstraints = false
        quickAddField.focusRingType = .none
        quickAddField.bezelStyle = .roundedBezel
        quickAddField.setAccessibilityLabel("Quick add task")
        quickAddField.setAccessibilityHelp("Type a task title and press Return to add")
        view.addSubview(quickAddField)
    }

    private func setupFilterBar() {
        filterControl = NSSegmentedControl(labels: ["All", "Active", "Completed"], trackingMode: .selectOne, target: self, action: #selector(filterChanged(_:)))
        filterControl.selectedSegment = 1 // Default: Active
        filterControl.translatesAutoresizingMaskIntoConstraints = false
        filterControl.font = NSFont.systemFont(ofSize: 11)
        view.addSubview(filterControl)
    }

    private func setupTableView() {
        tableView = NSTableView()
        tableView.style = .plain
        tableView.headerView = nil
        tableView.rowHeight = TaskListController.rowHeight
        tableView.selectionHighlightStyle = .regular
        tableView.dataSource = self
        tableView.delegate = self
        tableView.doubleAction = #selector(doubleClickedRow(_:))
        tableView.target = self

        // Right-click context menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Edit Task...", action: #selector(editSelectedTask(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Delete Task", action: #selector(deleteMenuAction(_:)), keyEquivalent: ""))
        tableView.menu = menu

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("MainColumn"))
        column.width = 300
        tableView.addTableColumn(column)

        scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        view.addSubview(scrollView)
    }

    private func setupFooter() {
        footerLabel = NSTextField(labelWithString: "")
        footerLabel.font = NSFont.systemFont(ofSize: 11)
        footerLabel.textColor = .secondaryLabelColor
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(footerLabel)

        // Use a clickable label instead of NSButton to guarantee baseline alignment
        clearButton = NSButton(title: "Clear Completed", target: self, action: #selector(clearCompleted(_:)))
        clearButton.isBordered = false
        clearButton.font = NSFont.systemFont(ofSize: 11)
        clearButton.contentTintColor = .systemBlue
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(clearButton)
    }

    private func layoutSubviews() {
        let margin: CGFloat = 12
        NSLayoutConstraint.activate([
            // Gear button (top-right)
            gearButton.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            gearButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            gearButton.widthAnchor.constraint(equalToConstant: 24),
            gearButton.heightAnchor.constraint(equalToConstant: 24),

            // Quick Add
            quickAddField.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            quickAddField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            quickAddField.trailingAnchor.constraint(equalTo: gearButton.leadingAnchor, constant: -6),
            quickAddField.heightAnchor.constraint(equalToConstant: 28),

            // Filter Bar
            filterControl.topAnchor.constraint(equalTo: quickAddField.bottomAnchor, constant: 8),
            filterControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            filterControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),

            // Table View
            scrollView.topAnchor.constraint(equalTo: filterControl.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: clearButton.topAnchor, constant: -4),

            // Footer — both anchored to bottom
            footerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            footerLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),

            clearButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            clearButton.lastBaselineAnchor.constraint(equalTo: footerLabel.lastBaselineAnchor),
        ])
    }

    // MARK: - Data

    func loadTasks() {
        switch currentFilter {
        case .all:
            tasks = TaskStore.shared.fetchTasks(completed: nil)
        case .active:
            tasks = TaskStore.shared.fetchTasks(completed: false)
        case .completed:
            tasks = TaskStore.shared.fetchTasks(completed: true)
        }
        tableView.reloadData()
        updateFooter()
    }

    private func updateFooter() {
        let activeCount = TaskStore.shared.activeTaskCount()
        footerLabel.stringValue = "\(activeCount) task\(activeCount == 1 ? "" : "s") remaining"
    }

    // MARK: - Actions

    @objc private func filterChanged(_ sender: NSSegmentedControl) {
        currentFilter = TaskFilter(rawValue: sender.selectedSegment) ?? .active
        loadTasks()
    }

    @objc private func doubleClickedRow(_ sender: Any?) {
        let row = tableView.clickedRow
        guard row >= 0, row < tasks.count else { return }
        toggleTask(at: row)
    }

    @objc private func clearCompleted(_ sender: Any?) {
        TaskStore.shared.clearCompletedTasks()
        loadTasks()
        appDelegate?.updateBadge()
    }

    @objc private func showGearMenu(_ sender: NSButton) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Export as JSON...", action: #selector(exportJSON(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Export as CSV...", action: #selector(exportCSV(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Import from JSON...", action: #selector(importJSON(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit MenuBarTodo", action: #selector(quitApp(_:)), keyEquivalent: "q"))

        let point = NSPoint(x: sender.bounds.midX, y: sender.bounds.minY)
        menu.popUp(positioning: nil, at: point, in: sender)
    }

    @objc private func exportJSON(_ sender: Any?) {
        let allTasks = TaskStore.shared.fetchTasks(completed: nil)
        DataExporter.exportJSON(tasks: allTasks, from: view.window)
    }

    @objc private func exportCSV(_ sender: Any?) {
        let allTasks = TaskStore.shared.fetchTasks(completed: nil)
        DataExporter.exportCSV(tasks: allTasks, from: view.window)
    }

    @objc private func importJSON(_ sender: Any?) {
        DataExporter.importJSON(into: TaskStore.shared, from: view.window) { [weak self] in
            self?.loadTasks()
            self?.appDelegate?.updateBadge()
        }
    }

    @objc private func quitApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    @objc private func editSelectedTask(_ sender: Any?) {
        let row = tableView.clickedRow
        guard row >= 0, row < tasks.count else { return }
        showEditPopover(for: row)
    }

    @objc private func deleteMenuAction(_ sender: Any?) {
        let row = tableView.clickedRow
        guard row >= 0, row < tasks.count else { return }
        TaskStore.shared.deleteTask(id: tasks[row].id)
        loadTasks()
        appDelegate?.updateBadge()
    }

    private func showEditPopover(for row: Int) {
        let task = tasks[row]
        let editVC = TaskEditPopover(task: task) { [weak self] updatedTask in
            TaskStore.shared.updateTask(updatedTask)
            self?.loadTasks()
            self?.appDelegate?.updateBadge()
        }

        let editPopover = NSPopover()
        editPopover.contentViewController = editVC
        editPopover.contentSize = NSSize(width: 260, height: 200)
        editPopover.behavior = .transient

        let rowRect = tableView.rect(ofRow: row)
        editPopover.show(relativeTo: rowRect, of: tableView, preferredEdge: .maxX)
    }

    // MARK: - NSTextFieldDelegate (Quick Add)

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            let text = quickAddField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return true }

            let maxSortOrder = tasks.map(\.sortOrder).max() ?? 0
            let task = TaskItem(title: text, sortOrder: maxSortOrder + 1)
            TaskStore.shared.insertTask(task)

            quickAddField.stringValue = ""
            loadTasks()
            appDelegate?.updateBadge()
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            quickAddField.stringValue = ""
            return true
        }
        return false
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return tasks.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let task = tasks[row]

        var cellView = tableView.makeView(withIdentifier: TaskListController.cellIdentifier, owner: self) as? TaskCellView
        if cellView == nil {
            cellView = TaskCellView(identifier: TaskListController.cellIdentifier)
        }

        cellView?.configure(with: task)
        cellView?.onToggle = { [weak self] in
            self?.toggleTask(at: row)
        }
        cellView?.onTitleEdit = { [weak self] newTitle in
            self?.updateTaskTitle(at: row, newTitle: newTitle)
        }

        return cellView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return TaskListController.rowHeight
    }

    // MARK: - Task Mutations

    private func toggleTask(at row: Int) {
        guard row < tasks.count else { return }
        TaskStore.shared.toggleTaskCompletion(&tasks[row])
        loadTasks()
        appDelegate?.updateBadge()
    }

    private func updateTaskTitle(at row: Int, newTitle: String) {
        guard row < tasks.count else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        tasks[row].title = trimmed
        tasks[row].updatedAt = Date()
        TaskStore.shared.updateTask(tasks[row])
        tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 0))
    }

    func deleteSelectedTask() {
        let row = tableView.selectedRow
        guard row >= 0, row < tasks.count else { return }
        TaskStore.shared.deleteTask(id: tasks[row].id)
        loadTasks()
        appDelegate?.updateBadge()
    }

    // MARK: - Keyboard Handling

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.keyCode == 51 { // Cmd+Delete
            deleteSelectedTask()
        } else if event.keyCode == 49 { // Space
            let row = tableView.selectedRow
            if row >= 0 { toggleTask(at: row) }
        } else {
            super.keyDown(with: event)
        }
    }
}
