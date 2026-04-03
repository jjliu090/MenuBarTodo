import AppKit

/// Lightweight edit panel shown when right-clicking a task.
/// Allows editing priority, due date, and notes.
final class TaskEditPopover: NSViewController {

    // MARK: - Properties

    private var task: TaskItem
    private let onSave: (TaskItem) -> Void

    // MARK: - UI Elements

    private var priorityPopup: NSPopUpButton!
    private var dueDatePicker: NSDatePicker!
    private var dueDateCheckbox: NSButton!
    private var noteField: NSTextField!
    private var saveButton: NSButton!

    // MARK: - Init

    init(task: TaskItem, onSave: @escaping (TaskItem) -> Void) {
        self.task = task
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Not supported")
    }

    // MARK: - Lifecycle

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 200))
        self.view = container
        setupUI()
        populateFields()
    }

    // MARK: - UI Setup

    private func setupUI() {
        let margin: CGFloat = 12
        var y: CGFloat = 168

        // Priority
        let priorityLabel = makeLabel("Priority:", y: y)
        view.addSubview(priorityLabel)

        priorityPopup = NSPopUpButton(frame: NSRect(x: 100, y: y - 2, width: 148, height: 24))
        priorityPopup.addItems(withTitles: ["None", "Low", "Medium", "High"])
        view.addSubview(priorityPopup)

        // Due Date
        y -= 34

        dueDateCheckbox = NSButton(checkboxWithTitle: "Due date:", target: self, action: #selector(dueDateToggled(_:)))
        dueDateCheckbox.frame = NSRect(x: margin, y: y, width: 88, height: 20)
        dueDateCheckbox.font = NSFont.systemFont(ofSize: 12)
        view.addSubview(dueDateCheckbox)

        dueDatePicker = NSDatePicker(frame: NSRect(x: 100, y: y - 2, width: 148, height: 24))
        dueDatePicker.datePickerStyle = .textFieldAndStepper
        dueDatePicker.datePickerElements = [.yearMonthDay]
        dueDatePicker.dateValue = Date()
        view.addSubview(dueDatePicker)

        // Note
        y -= 34
        let noteLabel = makeLabel("Note:", y: y)
        view.addSubview(noteLabel)

        y -= 4
        noteField = NSTextField(frame: NSRect(x: margin, y: y - 56, width: 236, height: 56))
        noteField.placeholderString = "Optional note..."
        noteField.font = NSFont.systemFont(ofSize: 12)
        noteField.usesSingleLineMode = false
        noteField.cell?.wraps = true
        noteField.cell?.isScrollable = false
        view.addSubview(noteField)

        // Save button
        saveButton = NSButton(title: "Save", target: self, action: #selector(saveClicked(_:)))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.frame = NSRect(x: 260 - margin - 80, y: 8, width: 80, height: 28)
        view.addSubview(saveButton)
    }

    private func makeLabel(_ text: String, y: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.frame = NSRect(x: 12, y: y, width: 80, height: 20)
        label.font = NSFont.systemFont(ofSize: 12)
        return label
    }

    private func populateFields() {
        priorityPopup.selectItem(at: Int(task.priority.rawValue))

        if let dueDate = task.dueDate {
            dueDateCheckbox.state = .on
            dueDatePicker.dateValue = dueDate
            dueDatePicker.isEnabled = true
        } else {
            dueDateCheckbox.state = .off
            dueDatePicker.isEnabled = false
        }

        noteField.stringValue = task.note ?? ""
    }

    // MARK: - Actions

    @objc private func dueDateToggled(_ sender: NSButton) {
        dueDatePicker.isEnabled = sender.state == .on
    }

    @objc private func saveClicked(_ sender: Any?) {
        task.priority = TaskPriority(rawValue: UInt8(priorityPopup.indexOfSelectedItem)) ?? .none
        task.dueDate = dueDateCheckbox.state == .on ? dueDatePicker.dateValue : nil
        let noteText = noteField.stringValue.trimmingCharacters(in: .whitespaces)
        task.note = noteText.isEmpty ? nil : noteText
        task.updatedAt = Date()

        onSave(task)
        dismiss(nil)
    }
}
