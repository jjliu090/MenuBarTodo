import AppKit

/// Reusable table cell with exactly 4 subviews: checkbox, title, priority dot, due date label.
/// Memory per visible cell: ~2-3 KB.
final class TaskCellView: NSTableCellView, NSTextFieldDelegate {

    // MARK: - Callbacks

    var onToggle: (() -> Void)?
    var onTitleEdit: ((String) -> Void)?

    // MARK: - Subviews (exactly 4)

    private let checkbox: NSButton
    private let titleField: NSTextField
    private let priorityDot: NSView
    private let dueDateLabel: NSTextField

    // MARK: - Init

    init(identifier: NSUserInterfaceItemIdentifier) {
        checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        titleField = NSTextField()
        priorityDot = NSView()
        dueDateLabel = NSTextField(labelWithString: "")

        super.init(frame: .zero)
        self.identifier = identifier
        setupSubviews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Not supported")
    }

    // MARK: - Setup

    private func setupSubviews() {
        // Checkbox
        checkbox.setButtonType(.switch)
        checkbox.title = ""
        checkbox.target = self
        checkbox.action = #selector(checkboxToggled(_:))
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        addSubview(checkbox)

        // Title (not directly editable — double-click toggles completion, right-click to edit)
        titleField.isBordered = false
        titleField.drawsBackground = false
        titleField.isEditable = false
        titleField.font = NSFont.systemFont(ofSize: 13)
        titleField.lineBreakMode = .byTruncatingTail
        titleField.cell?.truncatesLastVisibleLine = true
        titleField.delegate = self
        titleField.focusRingType = .none
        titleField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleField)

        // Priority dot (8×8pt)
        priorityDot.wantsLayer = true
        priorityDot.layer?.cornerRadius = 4
        priorityDot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(priorityDot)

        // Due date label
        dueDateLabel.font = NSFont.systemFont(ofSize: 10)
        dueDateLabel.textColor = .secondaryLabelColor
        dueDateLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dueDateLabel)

        // Layout
        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            checkbox.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkbox.widthAnchor.constraint(equalToConstant: 18),
            checkbox.heightAnchor.constraint(equalToConstant: 18),

            priorityDot.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 6),
            priorityDot.centerYAnchor.constraint(equalTo: centerYAnchor),
            priorityDot.widthAnchor.constraint(equalToConstant: 8),
            priorityDot.heightAnchor.constraint(equalToConstant: 8),

            titleField.leadingAnchor.constraint(equalTo: priorityDot.trailingAnchor, constant: 6),
            titleField.centerYAnchor.constraint(equalTo: checkbox.centerYAnchor),
            titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            dueDateLabel.leadingAnchor.constraint(equalTo: titleField.leadingAnchor),
            dueDateLabel.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 1),
        ])
    }

    // MARK: - Configuration

    func configure(with task: TaskItem) {
        checkbox.state = task.isCompleted ? .on : .off

        // Title with strikethrough for completed tasks
        if task.isCompleted {
            let attrs: [NSAttributedString.Key: Any] = [
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.systemFont(ofSize: 13)
            ]
            titleField.attributedStringValue = NSAttributedString(string: task.title, attributes: attrs)
        } else {
            titleField.stringValue = task.title
            titleField.textColor = .labelColor
            titleField.font = NSFont.systemFont(ofSize: 13)
        }

        // Priority dot color
        let dotColor: NSColor
        switch task.priority {
        case .none:   dotColor = .clear
        case .low:    dotColor = .systemBlue
        case .medium: dotColor = .systemOrange
        case .high:   dotColor = .systemRed
        }
        priorityDot.layer?.backgroundColor = dotColor.cgColor
        priorityDot.isHidden = task.priority == .none

        // Due date
        if let dueDate = task.dueDate {
            let formatter = TaskCellView.dateFormatter
            dueDateLabel.stringValue = formatter.string(from: dueDate)
            dueDateLabel.textColor = dueDate < Date() && !task.isCompleted ? .systemRed : .secondaryLabelColor
            dueDateLabel.isHidden = false
        } else {
            dueDateLabel.isHidden = true
        }

        // Accessibility
        updateAccessibility(task: task)
    }

    // MARK: - Accessibility

    private func updateAccessibility(task: TaskItem) {
        setAccessibilityElement(true)
        setAccessibilityRole(.row)

        var label = task.title
        if task.isCompleted {
            label = "Completed: \(label)"
        }
        if task.priority != .none {
            label += ", \(task.priority.displayName) priority"
        }
        if let dueDate = task.dueDate {
            let formatter = TaskCellView.dateFormatter
            let dateStr = formatter.string(from: dueDate)
            if dueDate < Date() && !task.isCompleted {
                label += ", overdue \(dateStr)"
            } else {
                label += ", due \(dateStr)"
            }
        }
        setAccessibilityLabel(label)

        checkbox.setAccessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")
        titleField.setAccessibilityLabel("Task title: \(task.title)")
    }

    // MARK: - Actions

    @objc private func checkboxToggled(_ sender: NSButton) {
        onToggle?()
    }

    // MARK: - NSTextFieldDelegate (inline title edit)

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        onTitleEdit?(fieldEditor.string)
        return true
    }

    // MARK: - Date Formatter (shared)

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        onToggle = nil
        onTitleEdit = nil
        titleField.stringValue = ""
        dueDateLabel.stringValue = ""
        dueDateLabel.isHidden = true
        priorityDot.isHidden = true
    }
}
