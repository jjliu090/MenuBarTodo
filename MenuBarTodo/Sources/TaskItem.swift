import Foundation

/// Task priority levels.
enum TaskPriority: UInt8 {
    case none   = 0
    case low    = 1
    case medium = 2
    case high   = 3

    var displayName: String {
        switch self {
        case .none:   return "None"
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }
}

/// Value-type task model (~120 bytes per instance).
/// Stored as struct for contiguous array layout and zero ARC overhead.
struct TaskItem {
    let id: Data               // 16-byte UUID as BLOB
    var title: String
    var note: String?
    var priority: TaskPriority
    var isCompleted: Bool
    var dueDate: Date?
    var sortOrder: Int32
    let createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    init(title: String,
         note: String? = nil,
         priority: TaskPriority = .none,
         dueDate: Date? = nil,
         sortOrder: Int32 = 0) {
        var uuid = UUID()
        self.id = withUnsafePointer(to: &uuid) {
            Data(bytes: $0, count: 16)
        }
        self.title = title
        self.note = note
        self.priority = priority
        self.isCompleted = false
        self.dueDate = dueDate
        self.sortOrder = sortOrder
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        self.completedAt = nil
    }

    /// Internal init for reading from database.
    init(id: Data, title: String, note: String?, priority: TaskPriority,
         isCompleted: Bool, dueDate: Date?, sortOrder: Int32,
         createdAt: Date, updatedAt: Date, completedAt: Date?) {
        self.id = id
        self.title = title
        self.note = note
        self.priority = priority
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
}
