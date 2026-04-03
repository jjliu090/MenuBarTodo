import AppKit
import Foundation

/// Handles data export (JSON/CSV) and import (JSON) via NSSavePanel/NSOpenPanel.
/// Also manages daily auto-backups with 7-day retention.
enum DataExporter {

    // MARK: - JSON Export

    static func exportJSON(tasks: [TaskItem], from window: NSWindow?) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "tasks_export.json"
        panel.title = "Export Tasks as JSON"

        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let jsonArray = tasks.map { taskToDict($0) }
                let data = try JSONSerialization.data(withJSONObject: jsonArray, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: url, options: .atomic)
            } catch {
                showError("Export failed: \(error.localizedDescription)", window: window)
            }
        }

        if let window = window {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(panel.runModal())
        }
    }

    // MARK: - CSV Export

    static func exportCSV(tasks: [TaskItem], from window: NSWindow?) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "tasks_export.csv"
        panel.title = "Export Tasks as CSV"

        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                var csv = "title,note,priority,is_completed,due_date,created_at,completed_at\n"
                for task in tasks {
                    let title = escapeCSV(task.title)
                    let note = escapeCSV(task.note ?? "")
                    let priority = task.priority.displayName
                    let completed = task.isCompleted ? "true" : "false"
                    let dueDate = task.dueDate.map { isoFormatter.string(from: $0) } ?? ""
                    let createdAt = isoFormatter.string(from: task.createdAt)
                    let completedAt = task.completedAt.map { isoFormatter.string(from: $0) } ?? ""
                    csv += "\(title),\(note),\(priority),\(completed),\(dueDate),\(createdAt),\(completedAt)\n"
                }
                try csv.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                showError("Export failed: \(error.localizedDescription)", window: window)
            }
        }

        if let window = window {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(panel.runModal())
        }
    }

    // MARK: - JSON Import

    static func importJSON(into store: TaskStore, from window: NSWindow?, completion: @escaping () -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = "Import Tasks from JSON"

        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    showError("Invalid JSON format: expected an array of task objects.", window: window)
                    return
                }

                var importCount = 0
                for dict in jsonArray {
                    guard let title = dict["title"] as? String, !title.isEmpty else { continue }
                    var task = TaskItem(title: title)

                    if let note = dict["note"] as? String, !note.isEmpty {
                        task.note = note
                    }
                    if let priorityRaw = dict["priority"] as? Int,
                       let priority = TaskPriority(rawValue: UInt8(priorityRaw)) {
                        task.priority = priority
                    }
                    if let dueDateStr = dict["due_date"] as? String,
                       let dueDate = isoFormatter.date(from: dueDateStr) {
                        task.dueDate = dueDate
                    }
                    if let isCompleted = dict["is_completed"] as? Bool {
                        task.isCompleted = isCompleted
                        if isCompleted { task.completedAt = Date() }
                    }

                    store.insertTask(task)
                    importCount += 1
                }

                completion()

                let alert = NSAlert()
                alert.messageText = "Import Complete"
                alert.informativeText = "Imported \(importCount) task(s)."
                alert.alertStyle = .informational
                if let window = window {
                    alert.beginSheetModal(for: window)
                } else {
                    alert.runModal()
                }
            } catch {
                showError("Import failed: \(error.localizedDescription)", window: window)
            }
        }

        if let window = window {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(panel.runModal())
        }
    }

    // MARK: - Auto Backup

    /// Creates a timestamped backup of the database. Called on popover close.
    /// Retains up to 7 daily backups.
    static func performDailyBackupIfNeeded() {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let dir = appSupport.appendingPathComponent("MenuBarTodo", isDirectory: true)
        let dbPath = dir.appendingPathComponent("tasks.db")

        guard fm.fileExists(atPath: dbPath.path) else { return }

        let backupDir = dir.appendingPathComponent("backups", isDirectory: true)
        try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)

        // Check if today's backup already exists
        let today = dayFormatter.string(from: Date())
        let backupName = "tasks_\(today).db"
        let backupPath = backupDir.appendingPathComponent(backupName)

        guard !fm.fileExists(atPath: backupPath.path) else { return }

        // Create backup
        try? fm.copyItem(at: dbPath, to: backupPath)

        // Clean old backups (keep last 7)
        cleanOldBackups(in: backupDir, keep: 7)
    }

    private static func cleanOldBackups(in dir: URL, keep: Int) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey])
            .filter({ $0.lastPathComponent.hasPrefix("tasks_") && $0.pathExtension == "db" })
            .sorted(by: { $0.lastPathComponent > $1.lastPathComponent })
        else { return }

        if files.count > keep {
            for file in files.dropFirst(keep) {
                try? fm.removeItem(at: file)
            }
        }
    }

    // MARK: - Helpers

    private static func taskToDict(_ task: TaskItem) -> [String: Any] {
        var dict: [String: Any] = [
            "title": task.title,
            "priority": Int(task.priority.rawValue),
            "is_completed": task.isCompleted,
            "created_at": isoFormatter.string(from: task.createdAt),
            "updated_at": isoFormatter.string(from: task.updatedAt),
        ]
        if let note = task.note { dict["note"] = note }
        if let dueDate = task.dueDate { dict["due_date"] = isoFormatter.string(from: dueDate) }
        if let completedAt = task.completedAt { dict["completed_at"] = isoFormatter.string(from: completedAt) }
        return dict
    }

    private static func escapeCSV(_ str: String) -> String {
        if str.contains(",") || str.contains("\"") || str.contains("\n") {
            return "\"" + str.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return str
    }

    private static func showError(_ message: String, window: NSWindow?) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        if let window = window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
